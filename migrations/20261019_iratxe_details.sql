-- Detalles de Casa Rural Iratxe. Conserva su ID y sus puntuaciones.
begin;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists booking_guests integer check (booking_guests > 0);
alter table public.houses add column if not exists travel_minutes integer check (travel_minutes > 0);
alter table public.houses add column if not exists travel_source_url text not null default '';
alter table public.houses add column if not exists booking_conditions text not null default '';
update public.houses set
  location = 'Diseminado Extrarradio, 973, 18270 Montefrío, España',
  image_url = 'assets/iratxe.jpg',
  capacity = 13,
  booking_guests = 13,
  price_per_night = 527,
  total_price = 1054,
  travel_minutes = 60,
  travel_source_url = 'https://www.turismomontefrio.org/conoce-montefrio/situacion/',
  description = 'Casa entera para el grupo de 13 adultos, con 8 dormitorios y 9 baños. Cuenta con 4 camas dobles y 10 individuales, cocina privada con lavavajillas y cafetera, aire acondicionado y WiFi gratis. Piscina privada, barbacoa, patio, balcón y terraza, con vistas al jardín, la piscina y la montaña. Ubicación valorada con 10/10 en Booking, basada en 1 comentario.',
  amenities = array['8 dormitorios','9 baños','Piscina privada','Barbacoa','WiFi gratis']::text[],
  booking_conditions = 'Opción de 1.054 € por las 2 noches para 13 adultos, con impuestos y cargos incluidos según la captura. Cancelación gratis antes del 21 de enero de 2027 y sin pago hasta el 19 de enero de 2027. La reserva requiere solicitud al anfitrión: no hay confirmación inmediata y responderá en un plazo de 24 horas. Confirma estas condiciones al reservar.'
where id = '20270122-0000-4000-8000-000000000003';
commit;
