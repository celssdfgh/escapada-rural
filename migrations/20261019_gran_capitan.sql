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
