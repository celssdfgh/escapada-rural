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
