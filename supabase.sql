-- EJECUTAR UNA SOLA VEZ en Supabase > SQL Editor.
-- Proyecto nuevo recomendado. Crea las tablas, las trece candidatas y las funciones de votación.
create extension if not exists pgcrypto;
create table if not exists public.houses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text not null default '',
  capacity integer not null default 1 check (capacity > 0),
  price_per_night numeric(10,2) not null default 0 check (price_per_night >= 0),
  description text not null default '',
  amenities text[] not null default '{}',
  image_url text not null default '',
  link_url text not null default '',
  display_order integer not null default 0,
  active boolean not null default true
);
create table if not exists public.votes (
  user_id uuid not null references auth.users(id) on delete cascade,
  house_id uuid not null references public.houses(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id,house_id)
);
create index if not exists votes_house_idx on public.votes(house_id);
alter table public.houses enable row level security;
alter table public.votes enable row level security;
-- Las casas se pueden consultar por cualquiera que acceda a la web.
drop policy if exists "read active houses" on public.houses;
create policy "read active houses" on public.houses for select to authenticated using (active = true);
-- Cada usuario anónimo autenticado solo puede consultar SUS votos.
drop policy if exists "read own votes" on public.votes;
create policy "read own votes" on public.votes for select to authenticated using ((select auth.uid()) = user_id);
-- No se conceden escrituras directas a votes: se hacen por función validada.
revoke all on public.houses from anon, authenticated;
revoke all on public.votes from anon, authenticated;
grant select on public.houses to authenticated;
grant select on public.votes to authenticated;
-- Solo revela totales si esa cuenta YA ha votado.
create or replace function public.get_results()
returns table(house_id uuid, vote_count bigint)
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.votes v where v.user_id = auth.uid()
  ) then
    raise exception 'Guarda tus votos para ver los resultados';
  end if;
  return query
  select h.id, count(v.house_id)::bigint
  from public.houses h
  left join public.votes v on v.house_id=h.id
  where h.active = true
  group by h.id;
end;
$$;
revoke all on function public.get_results() from public, anon, authenticated;
grant execute on function public.get_results() to authenticated;
-- Identificación obligatoria y consulta administrativa de votos.
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

-- Catálogo de las trece candidatas para enero de 2027.
-- Ejecuta después de 20261019_voter_identity.sql. Se puede repetir sin duplicar casas.
-- Conserva votos y casas anteriores, pero desactiva las candidatas que ya no participan.
begin;
alter table public.houses alter column capacity drop not null;
alter table public.houses alter column capacity drop default;
alter table public.houses alter column price_per_night drop not null;
alter table public.houses alter column price_per_night drop default;
insert into public.houses (id,name,location,capacity,price_per_night,description,amenities,image_url,link_url,display_order,active) values
('20270122-0000-4000-8000-000000000001','Casa Rural Baza','Carretera Comarcal, 334, Kl.6.200, Baza',null,450,'Casa entera de 450 m² con 7 dormitorios y baño en la habitación. Dispone de 2 piscinas (interior y exterior, con opción climatizada), cocina privada equipada, aire acondicionado, WiFi y parking privado gratis. Balcón, terraza y vistas al jardín.',array['7 dormitorios','450 m²','2 piscinas','WiFi gratis','Parking gratis']::text[],'assets/baza.jpg','https://www.booking.com/hotel/es/casa-rural-baza-baza.es.html?checkin=2027-01-22&checkout=2027-01-24&group_adults=13&group_children=0&no_rooms=1',1,true),
('20270122-0000-4000-8000-000000000002','La Loma de Ana María II','Pago La Loma, 18656 Chite, Granada, Andalucía',14,260,'Casa rural de alquiler íntegro para hasta 14 personas, con 5 dormitorios insonorizados y 5 baños. Salón comedor con chimenea, cocina equipada, suelo radiante y aire acondicionado. En el exterior, jardín con barbacoa y piscina. Según el alojamiento, a 30 minutos de la playa y 40 de Sierra Nevada.',array['5 dormitorios','5 baños','Piscina','Barbacoa','Chimenea']::text[],'assets/loma-ana-maria.jpg','https://www.tuscasasrurales.com/la-loma-de-ana-maria-ii-f18206.htm',2,true),
('20270122-0000-4000-8000-000000000003','Casa Rural Iratxe','Diseminado Extrarradio, 973, 18270 Montefrío, España',13,527,'Casa entera para el grupo de 13 adultos, con 8 dormitorios y 9 baños. Cuenta con 4 camas dobles y 10 individuales, cocina privada con lavavajillas y cafetera, aire acondicionado y WiFi gratis. Piscina privada, barbacoa, patio, balcón y terraza, con vistas al jardín, la piscina y la montaña. Ubicación valorada con 10/10 en Booking, basada en 1 comentario.',array['8 dormitorios','9 baños','Piscina privada','Barbacoa','WiFi gratis']::text[],'assets/iratxe.jpg','https://www.booking.com/hotel/es/casa-rural-iratxe-montefrio.es.html?checkin=2027-01-22&checkout=2027-01-24&group_adults=13&group_children=0&no_rooms=1',3,true),
('20270122-0000-4000-8000-000000000004','Cortijo Rural Las Nogueras','Carretera Huétor Tájar - Montefrío km 9, Montefrío (Granada)',14,336,'Cortijo rústico con 6 dormitorios y 3 baños, rodeado de jardines y a 200 metros de un río. Salón con chimenea y TV, cocina equipada con nevera, microondas y cafetera, y lavadora. Piscina exterior de temporada, barbacoa, sala de juegos con ping pong y aparcamiento gratuito.',array['6 dormitorios','3 baños','Piscina de temporada','Chimenea','Ping pong']::text[],'assets/las-nogueras.webp','https://www.escapadarural.com/casa-rural/granada/cortijo-la-noguera?dateIn=22-01-2027&dateOut=24-01-2027&capacity=13',4,true),
('20270122-0000-4000-8000-000000000005','La Estaquilla','Parcelas Las Estaquillas, s/n, Compl. Dom. Barriada Marchena, 18650 Dúrcal (Granada)',14,350,'Casa para 14 personas, distribuida en una sola planta y adaptada a personas con movilidad reducida. Tiene 5 dormitorios y 3 baños con ducha (2 compartidos y 1 privado), cocina comedor equipada y salón con chimenea de leña. Calefacción y aire acondicionado frío/calor en las habitaciones. Exterior amueblado, piscina vallada y huerto. Admite mascotas.',array['5 dormitorios','3 baños','Piscina vallada','Una planta','Admite mascotas']::text[],'assets/la-estaquilla.webp','https://www.escapadarural.com/casa-rural/granada/la-estaquilla?dateIn=22-01-2027&dateOut=24-01-2027&capacity=14',5,true),
('20270122-0000-4000-8000-000000000006','Casa en El Padul · HomeToGo','El Padul, Granada',null,308,'Casa con 5 dormitorios: 5 camas dobles (una grande) y 2 individuales. Dispone de salón con sofá, cocina y 2 baños con ducha, bidé, lavabo y agua fría y caliente. La distribución de camas suma 12 plazas; falta confirmar cómo se alojaría la persona número 13.',array['5 dormitorios','2 baños','Cocina','Salón con sofá','13.ª plaza por confirmar']::text[],'assets/home.jpg','https://www.hometogo.es/rental/31baaf3b1247bebe?duration=2&location=5460aecddf2bb&arrival=2027-01-22&persons=12&adults=12&id=31baaf3b1247bebe&pricetype=totalPrice',6,true)
on conflict (id) do update set name=excluded.name, location=excluded.location, capacity=excluded.capacity, price_per_night=excluded.price_per_night, description=excluded.description, amenities=excluded.amenities, image_url=excluded.image_url, link_url=excluded.link_url, display_order=excluded.display_order, active=excluded.active;
update public.houses set active = false where id not in ('20270122-0000-4000-8000-000000000001','20270122-0000-4000-8000-000000000002','20270122-0000-4000-8000-000000000003','20270122-0000-4000-8000-000000000004','20270122-0000-4000-8000-000000000005','20270122-0000-4000-8000-000000000006');
commit;

-- Valoraciones de 1 a 5 estrellas.
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

-- Inicio de sesión por correo declarado.
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

-- Datos de la casa de Baza aportados por el organizador.
-- Detalles de la primera candidata. Conserva su ID y sus puntuaciones.
begin;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists booking_guests integer check (booking_guests > 0);
alter table public.houses add column if not exists travel_minutes integer check (travel_minutes > 0);
alter table public.houses add column if not exists travel_source_url text not null default '';
alter table public.houses add column if not exists booking_conditions text not null default '';
update public.houses set
  location = 'Carretera Comarcal, 334, Kl.6.200, Baza',
  image_url = 'assets/baza.jpg',
  price_per_night = 450,
  total_price = 900,
  booking_guests = 13,
  travel_minutes = 80,
  travel_source_url = 'https://www.bazaturismo.com/como-llegar/',
  description = 'Casa entera de 450 m² con 7 dormitorios y baño en la habitación. Dispone de 2 piscinas (interior y exterior, con opción climatizada), cocina privada equipada, aire acondicionado, WiFi y parking privado gratis. Balcón, terraza y vistas al jardín.',
  amenities = array['7 dormitorios','450 m²','2 piscinas','WiFi gratis','Parking gratis']::text[],
  booking_conditions = 'Según la oferta de la captura: impuestos y cargos incluidos; cancelación gratis antes del 21 de enero de 2027 y sin pago hasta el 19 de enero de 2027. Confirma las condiciones al reservar.'
where id = '20270122-0000-4000-8000-000000000001';
commit;

-- Datos de La Loma de Ana María II aportados por el organizador.
-- Detalles de La Loma de Ana María II. Conserva su ID y sus puntuaciones.
begin;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists travel_minutes integer check (travel_minutes > 0);
alter table public.houses add column if not exists travel_source_url text not null default '';
update public.houses set
  location = 'Pago La Loma, 18656 Chite, Granada, Andalucía',
  capacity = 14,
  image_url = 'assets/loma-ana-maria.jpg',
  price_per_night = 260,
  total_price = 520,
  travel_minutes = 20,
  travel_source_url = 'https://www.tuscasasrurales.com/la-loma-de-ana-maria-ii-f18206.htm',
  description = 'Casa rural de alquiler íntegro para hasta 14 personas, con 5 dormitorios insonorizados y 5 baños. Salón comedor con chimenea, cocina equipada, suelo radiante y aire acondicionado. En el exterior, jardín con barbacoa y piscina. Según el alojamiento, a 30 minutos de la playa y 40 de Sierra Nevada.',
  amenities = array['5 dormitorios','5 baños','Piscina','Barbacoa','Chimenea']::text[]
where id = '20270122-0000-4000-8000-000000000002';
commit;

-- Datos de Casa Rural Iratxe aportados por el organizador.
-- Detalles de Casa Rural Iratxe. Conserva su ID y sus puntuaciones.
begin;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists booking_guests integer check (booking_guests > 0);
alter table public.houses add column if not exists travel_minutes integer check (travel_minutes > 0);
alter table public.houses add column if not exists travel_source_url text not null default '';
alter table public.houses add column if not exists booking_conditions text not null default '';
update public.houses set
  location = 'Diseminado Extrarradio, 973, 18270 Montefrío, España',
  image_url = 'assets/iratxe.jpg',
  capacity = 13,
  booking_guests = 13,
  price_per_night = 527,
  total_price = 1054,
  travel_minutes = 60,
  travel_source_url = 'https://www.turismomontefrio.org/conoce-montefrio/situacion/',
  description = 'Casa entera para el grupo de 13 adultos, con 8 dormitorios y 9 baños. Cuenta con 4 camas dobles y 10 individuales, cocina privada con lavavajillas y cafetera, aire acondicionado y WiFi gratis. Piscina privada, barbacoa, patio, balcón y terraza, con vistas al jardín, la piscina y la montaña. Ubicación valorada con 10/10 en Booking, basada en 1 comentario.',
  amenities = array['8 dormitorios','9 baños','Piscina privada','Barbacoa','WiFi gratis']::text[],
  booking_conditions = 'Opción de 1.054 € por las 2 noches para 13 adultos, con impuestos y cargos incluidos según la captura. Cancelación gratis antes del 21 de enero de 2027 y sin pago hasta el 19 de enero de 2027. La reserva requiere solicitud al anfitrión: no hay confirmación inmediata y responderá en un plazo de 24 horas. Confirma estas condiciones al reservar.'
where id = '20270122-0000-4000-8000-000000000003';
commit;

-- Datos de Cortijo Rural Las Nogueras aportados por el organizador.
-- Detalles de Cortijo Rural Las Nogueras. Conserva su ID y sus puntuaciones.
begin;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists travel_minutes integer check (travel_minutes > 0);
alter table public.houses add column if not exists travel_source_url text not null default '';
update public.houses set
  location = 'Carretera Huétor Tájar - Montefrío km 9, Montefrío (Granada)',
  capacity = 14,
  image_url = 'assets/las-nogueras.webp',
  price_per_night = 336,
  total_price = 672,
  travel_minutes = 45,
  travel_source_url = 'https://www.escapadarural.com/casa-rural/granada/cortijo-la-noguera',
  description = 'Cortijo rústico con 6 dormitorios y 3 baños, rodeado de jardines y a 200 metros de un río. Salón con chimenea y TV, cocina equipada con nevera, microondas y cafetera, y lavadora. Piscina exterior de temporada, barbacoa, sala de juegos con ping pong y aparcamiento gratuito.',
  amenities = array['6 dormitorios','3 baños','Piscina de temporada','Chimenea','Ping pong']::text[]
where id = '20270122-0000-4000-8000-000000000004';
commit;

-- Datos de La Estaquilla aportados por el organizador.
-- Detalles de La Estaquilla. Conserva su ID y sus puntuaciones.
begin;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists travel_minutes integer check (travel_minutes > 0);
alter table public.houses add column if not exists travel_source_url text not null default '';
alter table public.houses add column if not exists booking_conditions text not null default '';
update public.houses set
  location = 'Parcelas Las Estaquillas, s/n, Compl. Dom. Barriada Marchena, 18650 Dúrcal (Granada)',
  capacity = 14,
  image_url = 'assets/la-estaquilla.webp',
  price_per_night = 350,
  total_price = 700,
  travel_minutes = 30,
  travel_source_url = 'https://www.mejorruta.com/distancia/2517117-2518774/Granada/Durcal/',
  description = 'Casa para 14 personas, distribuida en una sola planta y adaptada a personas con movilidad reducida. Tiene 5 dormitorios y 3 baños con ducha (2 compartidos y 1 privado), cocina comedor equipada y salón con chimenea de leña. Calefacción y aire acondicionado frío/calor en las habitaciones. Exterior amueblado, piscina vallada y huerto. Admite mascotas.',
  amenities = array['5 dormitorios','3 baños','Piscina vallada','Una planta','Admite mascotas']::text[],
  booking_conditions = 'Precio de 700 € por las dos noches aportado por el organizador. Según la descripción, la leña se cobra aparte y hay una cama supletoria con coste adicional. Confirma los suplementos al reservar.'
where id = '20270122-0000-4000-8000-000000000005';
commit;

-- Datos de la candidata de HomeToGo aportados por el organizador.
-- Detalles de la candidata de HomeToGo en Padul. Conserva su ID y sus puntuaciones.
begin;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists travel_minutes integer check (travel_minutes > 0);
alter table public.houses add column if not exists travel_source_url text not null default '';
alter table public.houses add column if not exists booking_conditions text not null default '';
alter table public.houses add column if not exists maps_query text not null default '';
alter table public.houses add column if not exists location_note text not null default '';
update public.houses set
  name = 'Casa en El Padul · HomeToGo',
  location = 'El Padul, Granada',
  image_url = 'assets/home.jpg',
  price_per_night = 308,
  total_price = 616,
  travel_minutes = 25,
  travel_source_url = 'https://www.distanciasentreciudades.com/distancia-granada-a-padul',
  maps_query = 'Padul, Granada, España',
  location_note = 'Ubicación aproximada: municipio de Padul. Dirección exacta pendiente.',
  description = 'Casa con 5 dormitorios: 5 camas dobles (una grande) y 2 individuales. Dispone de salón con sofá, cocina y 2 baños con ducha, bidé, lavabo y agua fría y caliente. La distribución de camas suma 12 plazas; falta confirmar cómo se alojaría la persona número 13.',
  amenities = array['5 dormitorios','2 baños','Cocina','Salón con sofá','13.ª plaza por confirmar']::text[],
  booking_conditions = 'Precio aportado: 616 € por las dos noches. El reparto mostrado se calcula entre las 13 personas del grupo. El enlace de HomeToGo consulta 12 adultos y la captura muestra 12 plazas en camas; el sofá no se describe como sofá cama. Confirma la posibilidad de alojar a 13 adultos y cualquier suplemento antes de reservar.'
where id = '20270122-0000-4000-8000-000000000006';
commit;

-- Añade la séptima candidata sin modificar las casas ni las notas existentes.
begin;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists booking_conditions text not null default '';
alter table public.houses add column if not exists maps_query text not null default '';
insert into public.houses (name,location,capacity,description,amenities,image_url,link_url,id,price_per_night,display_order,active,total_price,booking_conditions,maps_query) values (
  'Chalet Venta del Aire · Cortijo Terrón',
  'Camino Barranco Juan Bueno s/n, Lanjarón (Granada)',
  15,
  'Casa de alquiler íntegro con piscina privada, terraza con barbacoa, jardín, salón comedor con chimenea y cocina equipada. Distribución de la captura: dormitorio 1 con una cama doble; dormitorio 2 con una cuna, una individual y una doble; dormitorio 3 con una individual y una cama de plaza y media; comedor con un sofá cama; dormitorio 4 con tres literas.',
  array['4 dormitorios según distribución','Piscina privada','Barbacoa','Chimenea','Admite mascotas']::text[],
  'assets/venta-del-aire.webp',
  'https://www.escapadarural.com/casa-rural/granada/chalet-venta-del-aire-cortijo-terron?dateIn=22-01-2027&dateOut=24-01-2027&capacity=12',
  '20270122-0000-4000-8000-000000000007',
  300,
  7,
  true,
  600,
  'Precio aportado: 600 € por las dos noches, del 22 al 24 de enero de 2027; reparto entre 13 personas. El anuncio indica hasta 15 plazas, pero el enlace consulta 12 personas: confirma el precio para 13 adultos. La distribución detallada muestra 4 dormitorios y un comedor con sofá cama, aunque la cabecera del anuncio indica 5 dormitorios. Cancelación y posibles suplementos pendientes de confirmar.',
  'Camino Barranco Juan Bueno s/n, Lanjarón, Granada'
)
on conflict (id) do update set
  name = excluded.name,
  location = excluded.location,
  capacity = excluded.capacity,
  description = excluded.description,
  amenities = excluded.amenities,
  image_url = excluded.image_url,
  link_url = excluded.link_url,
  price_per_night = excluded.price_per_night,
  display_order = excluded.display_order,
  active = excluded.active,
  total_price = excluded.total_price,
  booking_conditions = excluded.booking_conditions,
  maps_query = excluded.maps_query;
commit;

-- Añade Cortijo Gran Capitán sin modificar las casas ni las notas existentes.
begin;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists booking_conditions text not null default '';
alter table public.houses add column if not exists maps_query text not null default '';
insert into public.houses (name,location,capacity,description,amenities,image_url,link_url,id,price_per_night,display_order,active,total_price,maps_query,booking_conditions) values (
  'Cortijo Gran Capitán',
  'Camino de la Virgen s/n, Íllora (Granada)',
  12,
  'Casa rural restaurada en Íllora, en los Montes Orientales de Granada. Tiene 5 dormitorios (2 de matrimonio, 2 triples y 1 doble) y 2 baños, además de comedor, cocina equipada y salón. En el exterior dispone de piscina y pérgola. Capacidad máxima anunciada: 12 personas; falta confirmar alojamiento para la persona número 13.',
  array['5 dormitorios','2 baños','Piscina','Pérgola','13.ª plaza por confirmar']::text[],
  'assets/gran-capitan.webp',
  'https://www.escapadarural.com/casa-rural/granada/cortijo-gran-capitan?dateIn=22-01-2027&dateOut=24-01-2027&capacity=12',
  '20270122-0000-4000-8000-000000000008',
  325,
  8,
  true,
  650,
  'Camino de la Virgen s/n, Íllora, Granada',
  'Precio aportado: 650 € por las dos noches, del 22 al 24 de enero de 2027. El reparto mostrado es entre las 13 personas del grupo (50 € por persona), pero el anuncio admite un máximo de 12 y el enlace consulta 12 personas. Confirma con el alojamiento si puede admitir a 13 adultos y el precio correspondiente. Cancelación y posibles suplementos pendientes de confirmar.'
)
on conflict (id) do update set
  name = excluded.name,
  location = excluded.location,
  capacity = excluded.capacity,
  description = excluded.description,
  amenities = excluded.amenities,
  image_url = excluded.image_url,
  link_url = excluded.link_url,
  price_per_night = excluded.price_per_night,
  display_order = excluded.display_order,
  active = excluded.active,
  total_price = excluded.total_price,
  maps_query = excluded.maps_query,
  booking_conditions = excluded.booking_conditions;
commit;

-- Añade Casa El Tío Patricio sin modificar las casas ni las notas existentes.
begin;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists booking_conditions text not null default '';
alter table public.houses add column if not exists maps_query text not null default '';
insert into public.houses (name,location,capacity,description,amenities,image_url,link_url,id,price_per_night,display_order,active,total_price,maps_query,booking_conditions) values (
  'Casa El Tío Patricio',
  'Cortijo El Hachazo, s/n, Montillana (Granada)',
  15,
  'Vivienda del Cortijo El Hachazo, entre Montillana y Trujillos. Salón cocina equipado de 54 m² y WiFi. Tiene 6 dormitorios: 4 en planta baja y 2 en la primera; 4 con cama de matrimonio, uno con 3 camas de 105 cm y el sexto con una cama de matrimonio y 2 de 90 cm. Cinco dormitorios tienen baño completo y hay un aseo adicional. Calefacción en todos los dormitorios y aire acondicionado en 3.',
  array['6 dormitorios','5 baños y 1 aseo','Salón cocina de 54 m²','WiFi','Calefacción']::text[],
  'assets/tio-patricio.webp',
  'https://www.escapadarural.com/casa-rural/granada/casa-el-tio-patricio?dateIn=22-01-2027&dateOut=24-01-2027&capacity=12',
  '20270122-0000-4000-8000-000000000009',
  400,
  9,
  true,
  800,
  'Cortijo El Hachazo, Montillana, Granada',
  'Precio aportado: 800 € por las dos noches, del 22 al 24 de enero de 2027; reparto entre las 13 personas del grupo (61,54 € por persona). El anuncio indica hasta 15 plazas, pero el enlace consulta 12 personas: confirma el precio para 13 adultos. Cancelación y posibles suplementos pendientes de confirmar.'
)
on conflict (id) do update set
  name = excluded.name,
  location = excluded.location,
  capacity = excluded.capacity,
  description = excluded.description,
  amenities = excluded.amenities,
  image_url = excluded.image_url,
  link_url = excluded.link_url,
  price_per_night = excluded.price_per_night,
  display_order = excluded.display_order,
  active = excluded.active,
  total_price = excluded.total_price,
  maps_query = excluded.maps_query,
  booking_conditions = excluded.booking_conditions;
commit;

-- Añade la candidata de Airbnb en Guadix sin modificar las casas ni las notas existentes.
begin;
alter table public.houses alter column capacity drop not null;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists booking_conditions text not null default '';
alter table public.houses add column if not exists maps_query text not null default '';
alter table public.houses add column if not exists location_note text not null default '';
insert into public.houses (name,location,capacity,description,amenities,image_url,link_url,id,price_per_night,display_order,active,total_price,maps_query,location_note,booking_conditions) values (
  'Casa Rural del siglo XVI · Guadix',
  'Paulenca, Guadix (Granada)',
  null,
  'Casa rural del siglo XVI anunciada para más de 16 viajeros, con 8 dormitorios, 13 camas y 6 baños. Situada en Paulenca, a unos 2 km de Guadix, con vistas a Sierra Nevada. Cuenta con cocina, WiFi, aparcamiento dentro del recinto, dos patios, terraza, barbacoa y horno moruno. Piscina privada con zona de descanso en verano. Admite mascotas previo aviso.',
  array['8 dormitorios','13 camas','6 baños','WiFi','Parking gratis']::text[],
  'assets/guadix-airbnb.jpg',
  'https://www.airbnb.es/rooms/13075693?adults=12&check_in=2027-01-22&check_out=2027-01-24',
  '20270122-0000-4000-8000-000000000010',
  460,
  10,
  true,
  920,
  'Paulenca, Guadix, Granada',
  'Ubicación aproximada: Paulenca, Guadix. Dirección exacta pendiente. Capacidad anunciada: más de 16 viajeros.',
  'Precio aportado: 920 € por las dos noches, del 22 al 24 de enero de 2027; reparto entre 13 personas (70,77 € por persona). El enlace consulta 12 adultos: confirma el precio para 13. La piscina se describe para verano; su disponibilidad en enero está pendiente de confirmar. La leña se paga aparte y las mascotas requieren aviso previo. Cancelación y otros posibles suplementos pendientes de confirmar.'
)
on conflict (id) do update set
  name = excluded.name,
  location = excluded.location,
  capacity = excluded.capacity,
  description = excluded.description,
  amenities = excluded.amenities,
  image_url = excluded.image_url,
  link_url = excluded.link_url,
  price_per_night = excluded.price_per_night,
  display_order = excluded.display_order,
  active = excluded.active,
  total_price = excluded.total_price,
  maps_query = excluded.maps_query,
  location_note = excluded.location_note,
  booking_conditions = excluded.booking_conditions;
commit;

-- Añade Cortijo el Contarin sin modificar las casas ni las notas existentes.
begin;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists booking_conditions text not null default '';
alter table public.houses add column if not exists maps_query text not null default '';
alter table public.houses add column if not exists location_note text not null default '';
insert into public.houses (name,location,capacity,description,amenities,image_url,link_url,id,price_per_night,display_order,active,total_price,maps_query,location_note,booking_conditions) values (
  'Cortijo el Contarin · Salinas',
  'Entorno de Salinas, Archidona (Málaga)',
  13,
  'Casa de dos plantas en una finca de 18 hectáreas rodeada de encinas, a 5 minutos de Salinas según el anuncio. Tiene 5 dormitorios y 4 baños. En la primera planta: un dormitorio con cama de matrimonio e individual, otro con 4 individuales y dos con 2 individuales cada uno; 3 baños con bañera, 2 en suite. En la planta baja: dormitorio con 2 individuales, baño con ducha, salón comedor con chimenea y cocina equipada. Piscina privada, barbacoa y porche.',
  array['5 dormitorios','4 baños','Piscina privada','Barbacoa','Chimenea']::text[],
  'assets/contarin.jpg',
  'https://www.airbnb.es/rooms/1264970794514746776?adults=13&check_in=2027-01-22&check_out=2027-01-24',
  '20270122-0000-4000-8000-000000000011',
  406,
  11,
  true,
  812,
  'Salinas, Archidona, Málaga',
  'Ubicación aproximada: entorno de Salinas, Archidona (Málaga). Dirección exacta pendiente.',
  'Precio aportado: 812 € por las dos noches, del 22 al 24 de enero de 2027, para el grupo de 13 personas (62,46 € por persona). El anuncio y el enlace indican 13 viajeros. Cancelación, posibles suplementos y disponibilidad de la piscina en enero pendientes de confirmar.'
)
on conflict (id) do update set
  name = excluded.name,
  location = excluded.location,
  capacity = excluded.capacity,
  description = excluded.description,
  amenities = excluded.amenities,
  image_url = excluded.image_url,
  link_url = excluded.link_url,
  price_per_night = excluded.price_per_night,
  display_order = excluded.display_order,
  active = excluded.active,
  total_price = excluded.total_price,
  maps_query = excluded.maps_query,
  location_note = excluded.location_note,
  booking_conditions = excluded.booking_conditions;
commit;

-- Añade Villa en la naturaleza en Lecrín sin modificar las casas ni las notas existentes.
begin;
alter table public.houses alter column capacity drop not null;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists booking_conditions text not null default '';
alter table public.houses add column if not exists maps_query text not null default '';
alter table public.houses add column if not exists location_note text not null default '';
insert into public.houses (name,location,capacity,description,amenities,image_url,link_url,id,price_per_night,display_order,active,total_price,maps_query,location_note,booking_conditions) values (
  'Villa en la naturaleza · Lecrín',
  'Lecrín, Granada',
  null,
  'Villa rural en el entorno de Sierra Nevada, anunciada para más de 16 viajeros. Tiene 9 dormitorios con baño privado, 15 camas y 9 baños. Cuenta con cocina, WiFi, aparcamiento gratuito, patio central, piscina, barbacoa y horno de pizzas. El alquiler incluye el uso exclusivo de la planta baja y sus espacios exteriores; el apartamento superior queda vacío y se alquila aparte si se solicita.',
  array['9 dormitorios','9 baños privados','15 camas','Piscina','Barbacoa']::text[],
  'assets/lecrin-villa.jpg',
  'https://www.airbnb.es/rooms/1426672715481377050?adults=13&check_in=2027-01-22&check_out=2027-01-24',
  '20270122-0000-4000-8000-000000000012',
  675,
  12,
  true,
  1350,
  'Lecrín, Granada, España',
  'Ubicación aproximada: municipio de Lecrín. Dirección exacta pendiente. Capacidad anunciada: más de 16 viajeros.',
  'Precio aportado: 1.350 € por las dos noches, del 22 al 24 de enero de 2027, para 13 adultos (103,85 € por persona). Electricidad principalmente solar y con baterías, de disponibilidad limitada y con sistema de apoyo. Los últimos 2,5 km de acceso son de grava; el anfitrión indica que no hace falta todoterreno, pero puede no ser adecuado para coches muy bajos. Comercios a unos 15 minutos en coche. El apartamento superior no está incluido. Cancelación, posibles suplementos y disponibilidad de la piscina en enero pendientes de confirmar.'
)
on conflict (id) do update set
  name = excluded.name,
  location = excluded.location,
  capacity = excluded.capacity,
  description = excluded.description,
  amenities = excluded.amenities,
  image_url = excluded.image_url,
  link_url = excluded.link_url,
  price_per_night = excluded.price_per_night,
  display_order = excluded.display_order,
  active = excluded.active,
  total_price = excluded.total_price,
  maps_query = excluded.maps_query,
  location_note = excluded.location_note,
  booking_conditions = excluded.booking_conditions;
commit;

-- Añade CASA PRIMER AÑO sin modificar las casas ni las notas existentes.
begin;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists booking_conditions text not null default '';
alter table public.houses add column if not exists capacity_warning text not null default '';
insert into public.houses (name,location,capacity,description,amenities,image_url,link_url,id,price_per_night,display_order,active,total_price,capacity_warning,booking_conditions) values (
  'CASA PRIMER AÑO',
  'Íllora, Granada',
  10,
  'Casa del primer año en Íllora. Tiene capacidad para 10 personas; el grupo es de 13, por lo que faltan 3 plazas.',
  array['10 plazas','Faltan 3 plazas para el grupo']::text[],
  '',
  '',
  '20270122-0000-4000-8000-000000000013',
  250,
  13,
  true,
  500,
  'Solo 10 personas · Faltan 3 plazas para el grupo',
  'Precio aportado: 500 € por las dos noches, del 22 al 24 de enero de 2027. El reparto mostrado se calcula entre las 13 personas del grupo (38,46 € por persona), pero la casa solo dispone de 10 plazas.'
)
on conflict (id) do update set
  name = excluded.name,
  location = excluded.location,
  capacity = excluded.capacity,
  description = excluded.description,
  amenities = excluded.amenities,
  image_url = excluded.image_url,
  link_url = excluded.link_url,
  price_per_night = excluded.price_per_night,
  display_order = excluded.display_order,
  active = excluded.active,
  total_price = excluded.total_price,
  capacity_warning = excluded.capacity_warning,
  booking_conditions = excluded.booking_conditions;
commit;
