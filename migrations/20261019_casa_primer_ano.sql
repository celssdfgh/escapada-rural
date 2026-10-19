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
