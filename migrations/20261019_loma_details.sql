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
