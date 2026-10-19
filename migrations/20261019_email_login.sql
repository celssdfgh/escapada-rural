-- Acceso por correo declarado, sin verificación ni contraseña.
-- Ejecutar después de las migraciones de identidad, catálogo y estrellas.
begin;
create table if not exists public.participants (
  id uuid primary key default gen_random_uuid(),
  email text not null unique check (email = lower(btrim(email)) and char_length(email) <= 254 and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  name text not null check (char_length(btrim(name)) between 2 and 100),
  created_at timestamptz not null default now()
);
create table if not exists public.participant_sessions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  participant_id uuid not null references public.participants(id) on delete cascade
);
create table if not exists public.participant_ratings (
  participant_id uuid not null references public.participants(id) on delete cascade,
  house_id uuid not null references public.houses(id) on delete cascade,
  score integer not null check (score between 1 and 5),
  created_at timestamptz not null default now(),
  primary key(participant_id, house_id)
);
create index if not exists participant_ratings_house_idx on public.participant_ratings(house_id);
create table if not exists public.participant_migrations (id text primary key);
alter table public.participants enable row level security;
alter table public.participant_sessions enable row level security;
alter table public.participant_ratings enable row level security;
alter table public.participant_migrations enable row level security;
revoke all on public.participants, public.participant_sessions, public.participant_ratings, public.participant_migrations from public, anon, authenticated;
grant all on public.participants, public.participant_sessions, public.participant_ratings, public.participant_migrations to service_role;
-- Importa una sola vez. No resucita notas retiradas si se repite el script.
do $$
begin
  if not exists (select 1 from public.participant_migrations where id = 'email_login_v1') then
    insert into public.participants(email, name)
      select distinct on (lower(btrim(p.email))) lower(btrim(p.email)), btrim(p.name)
      from public.voter_profiles p
      order by lower(btrim(p.email)), p.updated_at desc, p.user_id
      on conflict (email) do nothing;
    insert into public.participant_ratings(participant_id, house_id, score, created_at)
      select distinct on (p.id, r.house_id) p.id, r.house_id, r.score, r.created_at
      from public.ratings r join public.voter_profiles old on old.user_id = r.user_id
      join public.participants p on p.email = lower(btrim(old.email))
      order by p.id, r.house_id, r.created_at desc, r.user_id
      on conflict (participant_id, house_id) do nothing;
    insert into public.participant_migrations(id) values ('email_login_v1');
  end if;
end $$;
create or replace function public.enter_participant(p_email text, p_name text default null)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_email text := lower(btrim(p_email));
  v_name text := btrim(p_name);
  v_profile public.participants%rowtype;
begin
  if v_user is null then raise exception 'No hay sesión disponible'; end if;
  if v_email is null or char_length(v_email) > 254 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Introduce un correo válido'; end if;
  select * into v_profile from public.participants where email = v_email;
  if not found then
    if v_name is null then return jsonb_build_object('needs_name', true); end if;
    if char_length(v_name) not between 2 and 100 then raise exception 'Introduce tu nombre (entre 2 y 100 caracteres)'; end if;
    insert into public.participants(email, name) values (v_email, v_name) on conflict (email) do nothing;
    select * into strict v_profile from public.participants where email = v_email;
  end if;
  insert into public.participant_sessions(user_id, participant_id) values (v_user, v_profile.id)
    on conflict (user_id) do update set participant_id = excluded.participant_id;
  return jsonb_build_object('needs_name', false, 'participant_id', v_profile.id, 'name', v_profile.name, 'email', v_profile.email);
end $$;
create or replace function public.get_my_ratings()
returns table(house_id uuid, score integer)
language plpgsql security definer set search_path = ''
as $$
declare v_participant uuid;
begin
  select s.participant_id into v_participant from public.participant_sessions s where s.user_id = auth.uid();
  if v_participant is null then raise exception 'Introduce tu correo para entrar'; end if;
  return query select r.house_id, r.score from public.participant_ratings r join public.houses h on h.id = r.house_id where r.participant_id = v_participant and h.active;
end $$;
create or replace function public.save_ratings(p_ratings jsonb, p_name text, p_email text)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_name text;
  v_email text;
  v_participant uuid;
  v_count integer;
begin
  if v_user is null then raise exception 'Debes iniciar sesión'; end if;
  select p.id, p.name, p.email into v_participant, v_name, v_email from public.participant_sessions s join public.participants p on p.id = s.participant_id where s.user_id = v_user;
  if v_participant is null or lower(btrim(p_email)) is distinct from v_email then raise exception 'Vuelve a entrar con tu correo'; end if;
  if v_email is null or char_length(v_email) > 254 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Introduce un email válido'; end if;
  if p_ratings is null or jsonb_typeof(p_ratings) <> 'array' then raise exception 'Valoraciones no válidas'; end if;
  v_count := jsonb_array_length(p_ratings);
  if v_count > 30 then raise exception 'Demasiadas casas'; end if;
  if exists (
    select 1 from jsonb_array_elements(p_ratings) as items(item)
    where jsonb_typeof(item) <> 'object'
       or coalesce(jsonb_typeof(item->'house_id'), '') <> 'string'
       or coalesce(item->>'house_id', '') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or coalesce(jsonb_typeof(item->'score'), '') <> 'number'
       or coalesce(item->>'score', '') !~ '^[1-5]$'
  ) then raise exception 'Cada nota debe ser un entero de 1 a 5'; end if;
  if (select count(distinct (item->>'house_id')::uuid) from jsonb_array_elements(p_ratings) as items(item)) <> v_count then raise exception 'Hay casas duplicadas'; end if;
  if (select count(*) from public.houses h where h.active and h.id in (
    select (item->>'house_id')::uuid from jsonb_array_elements(p_ratings) as items(item)
  )) <> v_count then raise exception 'Una casa ya no está disponible'; end if;
  perform 1 from public.participants where id = v_participant for update;
  delete from public.participant_ratings where participant_id = v_participant;
  insert into public.participant_ratings(participant_id, house_id, score)
    select v_participant, (item->>'house_id')::uuid, (item->>'score')::integer
    from jsonb_array_elements(p_ratings) as items(item);
end;
$$;
create or replace function public.get_rating_results()
returns table (house_id uuid, rating_count bigint, average_rating numeric)
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  return query
    select h.id, count(r.score), avg(r.score)
    from public.houses h left join public.participant_ratings r on r.house_id = h.id
    where h.active
    group by h.id, h.name
    order by avg(r.score) desc nulls last, count(r.score) desc, h.name asc, h.id asc;
end;
$$;
revoke all on function public.save_ratings(jsonb, text, text) from public, anon, authenticated;
revoke all on function public.get_rating_results() from public, anon, authenticated;
grant execute on function public.save_ratings(jsonb, text, text) to authenticated;
grant execute on function public.get_rating_results() to authenticated;
revoke all on function public.enter_participant(text, text) from public, anon, authenticated;
revoke all on function public.get_my_ratings() from public, anon, authenticated;
grant execute on function public.enter_participant(text, text) to authenticated;
grant execute on function public.get_my_ratings() to authenticated;
-- Mantiene el nombre de la consulta administrativa y añade el ID permanente.
create or replace view public.rating_details as
select p.id as user_id, p.name as voter_name, p.email as voter_email,
       h.name as house_name, r.house_id, r.score, r.created_at as rated_at,
       p.id as participant_id
from public.participant_ratings r join public.participants p on p.id = r.participant_id
join public.houses h on h.id = r.house_id;
revoke all on public.rating_details from public, anon, authenticated;
grant select on public.rating_details to service_role;
commit;
