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
