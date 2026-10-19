-- Ejecutar en Supabase > SQL Editor. Conserva las casas y los votos existentes.
begin;
create table if not exists public.voter_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 2 and 100),
  email text not null check (char_length(email) <= 254 and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  updated_at timestamptz not null default now()
);
alter table public.voter_profiles enable row level security;
drop policy if exists "read own profile" on public.voter_profiles;
create policy "read own profile" on public.voter_profiles for select to authenticated
  using ((select auth.uid()) = user_id);
revoke all on public.voter_profiles from public, anon, authenticated;
grant select on public.voter_profiles to authenticated;
grant all on public.voter_profiles to service_role;
-- Elimina la firma antigua para impedir votos sin nombre y email.
drop function if exists public.save_votes(uuid[]);
create or replace function public.save_votes(p_house_ids uuid[], p_name text, p_email text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_name text := btrim(p_name);
  v_email text := lower(btrim(p_email));
  v_count integer;
begin
  if v_user is null then raise exception 'Debes iniciar sesión'; end if;
  if v_name is null or char_length(v_name) not between 2 and 100 then
    raise exception 'Introduce tu nombre (entre 2 y 100 caracteres)';
  end if;
  if v_email is null or char_length(v_email) > 254 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Introduce un email válido';
  end if;
  v_count := cardinality(p_house_ids);
  if v_count is null or v_count = 0 then raise exception 'Elige al menos una casa'; end if;
  if v_count > 30 then raise exception 'Demasiadas casas seleccionadas'; end if;
  if (select count(distinct x) from unnest(p_house_ids) as x) <> v_count then
    raise exception 'Hay casas duplicadas';
  end if;
  if (select count(*) from public.houses where id = any(p_house_ids) and active = true) <> v_count then
    raise exception 'Una de las casas no está disponible';
  end if;
  perform 1 from auth.users where id = v_user for update;
  insert into public.voter_profiles(user_id, name, email) values (v_user, v_name, v_email)
    on conflict (user_id) do update set name = excluded.name, email = excluded.email, updated_at = now();
  delete from public.votes where user_id = v_user;
  insert into public.votes(user_id,house_id) select v_user, unnest(p_house_ids);
end;
$$;
revoke all on function public.save_votes(uuid[], text, text) from public, anon, authenticated;
grant execute on function public.save_votes(uuid[], text, text) to authenticated;
-- Consulta administrativa: visible en el dashboard, nunca en la web pública.
create or replace view public.vote_details as
select v.user_id, p.name as voter_name, p.email as voter_email,
       h.name as house_name, v.house_id, v.created_at as voted_at
from public.votes v
left join public.voter_profiles p on p.user_id = v.user_id
join public.houses h on h.id = v.house_id;
revoke all on public.vote_details from public, anon, authenticated;
grant select on public.vote_details to service_role;
commit;
