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
