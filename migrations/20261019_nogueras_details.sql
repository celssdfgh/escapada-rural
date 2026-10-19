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
