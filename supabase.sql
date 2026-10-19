-- EJECUTAR UNA SOLA VEZ en Supabase > SQL Editor.
-- Proyecto nuevo recomendado. Crea las tablas, ejemplos y funciones de votación.
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
-- Función transaccional: reemplaza todas las elecciones de quien llama.
create or replace function public.save_votes(p_house_ids uuid[])
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_count integer;
begin
  if v_user is null then raise exception 'Debes iniciar sesión'; end if;
  if p_house_ids is null or array_length(p_house_ids,1) is null then
    raise exception 'Elige al menos una casa';
  end if;
  v_count := array_length(p_house_ids,1);
  if v_count > 30 then raise exception 'Demasiadas casas seleccionadas'; end if;
  if (select count(distinct x) from unnest(p_house_ids) as x) <> v_count then
    raise exception 'Hay casas duplicadas';
  end if;
  if (select count(*) from public.houses where id = any(p_house_ids) and active = true) <> v_count then
    raise exception 'Una de las casas no está disponible';
  end if;
  -- Bloquea las actualizaciones simultáneas de la misma cuenta.
  perform 1 from auth.users where id = v_user for update;
  delete from public.votes where user_id = v_user;
  insert into public.votes(user_id,house_id)
  select v_user, unnest(p_house_ids);
end;
$$;
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
revoke all on function public.save_votes(uuid[]) from public, anon, authenticated;
revoke all on function public.get_results() from public, anon, authenticated;
grant execute on function public.save_votes(uuid[]) to authenticated;
grant execute on function public.get_results() to authenticated;
-- CASAS DE DEMOSTRACIÓN: sustituye sus datos en Table Editor > houses.
insert into public.houses(name,location,capacity,price_per_night,description,amenities,image_url,link_url,display_order)
select x.name,x.location,x.capacity,x.price_per_night,x.description,x.amenities,x.image_url,x.link_url,x.display_order
from (values
('Cortijo El Mirador','Sierra de Granada',10,320.00,'Una escapada entre montaña y naturaleza.',array['Piscina','Barbacoa','Chimenea'],'https://images.unsplash.com/photo-1449158743715-0a90ebb6d2d8?w=900&q=80','',1),
('La Casa del Bosque','Sierra de Cazorla',12,280.00,'Para perderse entre árboles y desconectar.',array['Terraza','Jardín','Montaña'],'https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=900&q=80','',2),
('Villa Los Olivos','Serranía de Ronda',8,250.00,'Rincones tranquilos y tardes al sol.',array['Piscina','Vistas','WiFi'],'https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?w=900&q=80','',3)
) as x(name,location,capacity,price_per_night,description,amenities,image_url,link_url,display_order)
where not exists (select 1 from public.houses);
