-- Añade la candidata de Airbnb en Guadix sin modificar las casas ni las notas existentes.
begin;
alter table public.houses alter column capacity drop not null;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists booking_conditions text not null default '';
alter table public.houses add column if not exists maps_query text not null default '';
alter table public.houses add column if not exists location_note text not null default '';
insert into public.houses (name,location,capacity,description,amenities,image_url,link_url,id,price_per_night,display_order,active,total_price,maps_query,location_note,booking_conditions) values (
  'Casa Rural del siglo XVI · Guadix',
  'Paulenca, Guadix (Granada)',
  null,
  'Casa rural del siglo XVI anunciada para más de 16 viajeros, con 8 dormitorios, 13 camas y 6 baños. Situada en Paulenca, a unos 2 km de Guadix, con vistas a Sierra Nevada. Cuenta con cocina, WiFi, aparcamiento dentro del recinto, dos patios, terraza, barbacoa y horno moruno. Piscina privada con zona de descanso en verano. Admite mascotas previo aviso.',
  array['8 dormitorios','13 camas','6 baños','WiFi','Parking gratis']::text[],
  'assets/guadix-airbnb.jpg',
  'https://www.airbnb.es/rooms/13075693?adults=12&check_in=2027-01-22&check_out=2027-01-24',
  '20270122-0000-4000-8000-000000000010',
  460,
  10,
  true,
  920,
  'Paulenca, Guadix, Granada',
  'Ubicación aproximada: Paulenca, Guadix. Dirección exacta pendiente. Capacidad anunciada: más de 16 viajeros.',
  'Precio aportado: 920 € por las dos noches, del 22 al 24 de enero de 2027; reparto entre 13 personas (70,77 € por persona). El enlace consulta 12 adultos: confirma el precio para 13. La piscina se describe para verano; su disponibilidad en enero está pendiente de confirmar. La leña se paga aparte y las mascotas requieren aviso previo. Cancelación y otros posibles suplementos pendientes de confirmar.'
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
