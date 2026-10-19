-- Añade Villa en la naturaleza en Lecrín sin modificar las casas ni las notas existentes.
begin;
alter table public.houses alter column capacity drop not null;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists booking_conditions text not null default '';
alter table public.houses add column if not exists maps_query text not null default '';
alter table public.houses add column if not exists location_note text not null default '';
insert into public.houses (name,location,capacity,description,amenities,image_url,link_url,id,price_per_night,display_order,active,total_price,maps_query,location_note,booking_conditions) values (
  'Villa en la naturaleza · Lecrín',
  'Lecrín, Granada',
  null,
  'Villa rural en el entorno de Sierra Nevada, anunciada para más de 16 viajeros. Tiene 9 dormitorios con baño privado, 15 camas y 9 baños. Cuenta con cocina, WiFi, aparcamiento gratuito, patio central, piscina, barbacoa y horno de pizzas. El alquiler incluye el uso exclusivo de la planta baja y sus espacios exteriores; el apartamento superior queda vacío y se alquila aparte si se solicita.',
  array['9 dormitorios','9 baños privados','15 camas','Piscina','Barbacoa']::text[],
  'assets/lecrin-villa.jpg',
  'https://www.airbnb.es/rooms/1426672715481377050?adults=13&check_in=2027-01-22&check_out=2027-01-24',
  '20270122-0000-4000-8000-000000000012',
  675,
  12,
  true,
  1350,
  'Lecrín, Granada, España',
  'Ubicación aproximada: municipio de Lecrín. Dirección exacta pendiente. Capacidad anunciada: más de 16 viajeros.',
  'Precio aportado: 1.350 € por las dos noches, del 22 al 24 de enero de 2027, para 13 adultos (103,85 € por persona). Electricidad principalmente solar y con baterías, de disponibilidad limitada y con sistema de apoyo. Los últimos 2,5 km de acceso son de grava; el anfitrión indica que no hace falta todoterreno, pero puede no ser adecuado para coches muy bajos. Comercios a unos 15 minutos en coche. El apartamento superior no está incluido. Cancelación, posibles suplementos y disponibilidad de la piscina en enero pendientes de confirmar.'
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
