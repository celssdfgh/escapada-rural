-- Detalles de La Estaquilla. Conserva su ID y sus puntuaciones.
begin;
alter table public.houses add column if not exists total_price numeric(10,2) check (total_price >= 0);
alter table public.houses add column if not exists travel_minutes integer check (travel_minutes > 0);
alter table public.houses add column if not exists travel_source_url text not null default '';
alter table public.houses add column if not exists booking_conditions text not null default '';
update public.houses set
  location = 'Parcelas Las Estaquillas, s/n, Compl. Dom. Barriada Marchena, 18650 Dúrcal (Granada)',
  capacity = 14,
  image_url = 'assets/la-estaquilla.webp',
  price_per_night = 350,
  total_price = 700,
  travel_minutes = 30,
  travel_source_url = 'https://www.mejorruta.com/distancia/2517117-2518774/Granada/Durcal/',
  description = 'Casa para 14 personas, distribuida en una sola planta y adaptada a personas con movilidad reducida. Tiene 5 dormitorios y 3 baños con ducha (2 compartidos y 1 privado), cocina comedor equipada y salón con chimenea de leña. Calefacción y aire acondicionado frío/calor en las habitaciones. Exterior amueblado, piscina vallada y huerto. Admite mascotas.',
  amenities = array['5 dormitorios','3 baños','Piscina vallada','Una planta','Admite mascotas']::text[],
  booking_conditions = 'Precio de 700 € por las dos noches aportado por el organizador. Según la descripción, la leña se cobra aparte y hay una cama supletoria con coste adicional. Confirma los suplementos al reservar.'
where id = '20270122-0000-4000-8000-000000000005';
commit;
