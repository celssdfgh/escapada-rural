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
