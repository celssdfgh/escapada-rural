-- Ejecutar después de las migraciones de identidad y catálogo.
-- Conserva los votos antiguos como histórico; no los convierte en notas inventadas.
begin;
create table if not exists public.ratings (
  user_id uuid not null references auth.users(id) on delete cascade,
  house_id uuid not null references public.houses(id) on delete cascade,
  score integer not null check (score between 1 and 5),
  created_at timestamptz not null default now(),
  primary key (user_id, house_id)
);
create index if not exists ratings_house_idx on public.ratings(house_id);
alter table public.ratings enable row level security;
drop policy if exists "read own ratings" on public.ratings;
create policy "read own ratings" on public.ratings for select to authenticated
  using ((select auth.uid()) = user_id);
revoke all on public.ratings from public, anon, authenticated;
grant select on public.ratings to authenticated;
grant all on public.ratings to service_role;
create or replace function public.save_ratings(p_ratings jsonb, p_name text, p_email text)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_name text := btrim(p_name);
  v_email text := lower(btrim(p_email));
  v_count integer;
begin
  if v_user is null then raise exception 'Debes iniciar sesión'; end if;
  if v_name is null or char_length(v_name) not between 2 and 100 then raise exception 'Introduce tu nombre'; end if;
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
  perform 1 from auth.users where id = v_user for update;
  insert into public.voter_profiles(user_id, name, email) values (v_user, v_name, v_email)
    on conflict (user_id) do update set name = excluded.name, email = excluded.email, updated_at = now();
  delete from public.ratings where user_id = v_user;
  insert into public.ratings(user_id, house_id, score)
    select v_user, (item->>'house_id')::uuid, (item->>'score')::integer
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
    from public.houses h left join public.ratings r on r.house_id = h.id
    where h.active
    group by h.id, h.name
    order by avg(r.score) desc nulls last, count(r.score) desc, h.name asc, h.id asc;
end;
$$;
revoke all on function public.save_ratings(jsonb, text, text) from public, anon, authenticated;
revoke all on function public.get_rating_results() from public, anon, authenticated;
grant execute on function public.save_ratings(jsonb, text, text) to authenticated;
grant execute on function public.get_rating_results() to authenticated;
-- Impide que versiones antiguas sigan añadiendo votos al sistema anterior.
drop function if exists public.save_votes(uuid[]);
drop function if exists public.save_votes(uuid[], text, text);
create or replace view public.rating_details as
select r.user_id, p.name as voter_name, p.email as voter_email,
       h.name as house_name, r.house_id, r.score, r.created_at as rated_at
from public.ratings r left join public.voter_profiles p on p.user_id = r.user_id
join public.houses h on h.id = r.house_id;
revoke all on public.rating_details from public, anon, authenticated;
grant select on public.rating_details to service_role;
commit;
