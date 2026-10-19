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
