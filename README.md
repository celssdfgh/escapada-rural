# La Casa de las Carcasas

Votación de seis casas rurales para el 22–24 de enero de 2027. Web estática sin compilación; Supabase guarda los participantes y sus notas de 1 a 5 estrellas.

## Acceso por correo

1. Introduce tu correo y pulsa **Continuar**.
2. Si el correo es nuevo, aparece el campo de nombre. Al confirmarlo se crea el participante en Supabase, aunque todavía no haya puntuado.
3. Si ya existe, se recupera el nombre y se cargan sus puntuaciones guardadas. No vuelve a pedir nombre.
4. El mismo correo recupera el mismo participante desde cualquier navegador o dispositivo. No se envían correos ni se piden contraseñas.
5. **Cambiar usuario** limpia la selección de la pantalla y permite entrar con otro correo. Las notas anteriores siguen guardadas en su participante.

El correo es un identificador declarado, no una prueba de identidad: cualquiera que conozca un correo registrado puede entrar como esa persona y modificar sus notas. Esta es la modalidad solicitada para el grupo.

Se recuerda el último correo en este navegador (`carcasas.participant.v1`) para entrar automáticamente al volver. El nombre y las notas se consultan siempre en Supabase; no se confía en el nombre guardado localmente. Si se borran los datos del navegador, basta con volver a introducir el mismo correo.

## Actualizar una instalación existente

En **Supabase → SQL Editor → New query**, ejecuta las migraciones pendientes en este orden:

1. `migrations/20261019_voter_identity.sql`
2. `migrations/20261019_real_houses.sql`
3. `migrations/20261019_star_ratings.sql`
4. `migrations/20261019_email_login.sql`
5. `migrations/20261019_baza_details.sql` (foto, dirección y precio de la primera candidata).
6. `migrations/20261019_loma_details.sql` (precio, dirección y características de La Loma de Ana María II).
7. `migrations/20261019_iratxe_details.sql` (precio, dirección y características de Iratxe).
8. `migrations/20261019_nogueras_details.sql` (precio, dirección y características de Las Nogueras).
9. `migrations/20261019_estaquilla_details.sql` (precio, dirección y características de La Estaquilla).
10. `migrations/20261019_hometogo_details.sql` (precio, foto, ubicación y distribución de la casa de HomeToGo).

Ejecuta solo las migraciones que te falten. Después recarga la web. Mantén activos **Anonymous Sign-Ins**: se utilizan para la sesión técnica de cada navegador, mientras el participante permanente se identifica por correo en la tabla `participants`.

La nueva migración importa una sola vez los perfiles y las notas anteriores. Los correos se normalizan a minúsculas y sin espacios en los extremos. Si había varios perfiles con el mismo correo, se usa el nombre del perfil actualizado más recientemente y la última nota por casa. Un mismo correo cuenta como una sola participación, aunque entre desde varios dispositivos. Repetir la nueva migración no vuelve a importar notas ya retiradas.

## Instalación nueva

1. Crea un proyecto en Supabase.
2. Ejecuta `supabase.sql` completo en SQL Editor. Incluye esquema, permisos, funciones, catálogo y acceso por correo.
3. Activa **Authentication → Providers → Anonymous Sign-Ins**.
4. Rellena `config.js` con la URL y la clave pública publishable o anon. Nunca publiques service_role, contraseñas ni claves secretas.
5. Publica `index.html`, `styles.css`, `app.js`, `houses.js`, `config.js` y toda la carpeta `assets` en GitHub Pages u otro alojamiento estático.

Para verlo en local: `python3 -m http.server 8000 --bind 127.0.0.1` y abre http://localhost:8000.

## Puntuaciones y resultados

- Se pueden valorar una o varias casas de 1 a 5 estrellas. Una casa sin valorar no cuenta como un cero.
- El botón de guardar flota en la parte inferior en móvil y escritorio, tanto en Candidatas como en Resultados. Indica si hay cambios pendientes.
- Guardar reemplaza todas las notas anteriores de ese participante en una única transacción. Permite cambiar y retirar notas, incluso retirarlas todas.
- La pestaña **Resultados** muestra la media con dos decimales y el número de valoraciones. Ordena por media exacta descendente, después número de notas y nombre; las casas sin notas van al final.
- El ranking se consulta al abrir la pestaña, después de guardar y al pulsar **Actualizar**.
- Si dos dispositivos del mismo participante guardan a la vez, prevalece el último guardado completo.

## Consultar quién ha votado

En **Supabase → SQL Editor**:

```sql
select voter_name, voter_email, house_name, score, rated_at
from public.rating_details
order by voter_name, house_name;
```

Sale una fila por casa puntuada, con nombre, email y nota. Puedes exportar el resultado a CSV. `participants` contiene los usuarios, incluidos los que aún no han puntuado; `participant_ratings` contiene las notas y `participant_sessions` asocia las sesiones técnicas a los participantes.

Los antiguos `voter_profiles`, `votes` y `ratings` se conservan como histórico. `vote_details` consulta los votos anteriores sin estrellas. La web usa las funciones de acceso y guardado; las tablas nuevas y `rating_details` no permiten lectura directa al navegador.

## Casas y fotos

Las seis candidatas están en `houses.js` y en `migrations/20261019_real_houses.sql`; sus IDs y datos deben coincidir. Para cambiar el catálogo, edita ambos y aplica la migración. La foto del inicio es `assets/inicio.jpg`.

Casa Rural Baza: 900 € por las dos noches para el grupo, impuestos y cargos incluidos según la captura del organizador; 900 / 13 = 69,23 € por persona, redondeado a céntimos. El reparto es común para todas las casas: `window.TRIP_CONFIG` fija 13 personas y 2 noches. Las tarjetas muestran `total_price` o, si solo hay tarifa nocturna, `price_per_night × 2`. El resto de precios están pendientes: aparece «Consultar». El enlace de HomeToGo consulta 12 adultos: confirma si admite a todo el grupo.

Fuentes consultadas el 19/10/2026:

- La Loma de Ana María II: https://www.tuscasasrurales.com/la-loma-de-ana-maria-ii-f18206.htm
- Iratxe: https://casaruraliratxe.blogspot.com/
- Las Nogueras: https://www.escapadarural.com/casa-rural/granada/cortijo-la-noguera
- La Estaquilla: https://www.escapadarural.com/casa-rural/granada/la-estaquilla
- Baza y HomeToGo: enlaces aportados por el organizador; sus fichas no permitieron comprobar más datos.

Las tres fotos de tarjetas proceden de los anuncios. Baza usa `assets/baza.jpg` aportada por el organizador; se puede ampliar en la web. Las otras dos sin foto muestran una ilustración de foto pendiente. No se cargan fuentes externas.

## Pruebas

`node --test tests/voting.test.cjs` comprueba registro, acceso con correo conocido, recuperación desde otro navegador, cambio de usuario, guardado de estrellas y ranking con un servidor simulado.

`tests/email-login.sql` comprueba el flujo en PostgreSQL con el esquema y catálogo ya instalados. Debe ejecutarse solo en una base de pruebas; usa ROLLBACK para revertir sus datos. `tests/ratings.sql` corresponde al sistema anterior por navegador y debe ejecutarse antes de la migración de acceso por correo.

Antes de compartir: entra con un correo nuevo, registra un nombre, puntúa y guarda; desde otro navegador introduce ese mismo correo y comprueba que recupera las notas; entra con otro correo y comprueba que empieza sin puntuaciones.

## Primera candidata: Baza
Dirección aportada: Carretera Comarcal, 334, Kl.6.200, Baza. La dirección abre Google Maps; el tiempo orientativo abre indicaciones desde Plaza del Carmen, Granada. Se estiman unos 80 minutos, tomando como referencia los 75 minutos entre Granada capital y Baza publicados por https://www.bazaturismo.com/como-llegar/ y añadiendo margen para el acceso local. No es una medición en vivo. La ruta de Google Maps permite comprobar el tiempo real.

Resumen y condiciones de reserva proceden de la captura aportada: casa entera de 450 m², 7 dormitorios, baños en habitación, 2 piscinas con opción climatizada, cocina equipada, aire acondicionado, WiFi, aparcamiento, balcón, terraza y jardín. La oferta indica cancelación gratis antes del 21/01/2027 y pago a partir del 19/01/2027; confirmar al reservar.

Para sincronizar estos campos del catálogo con Supabase, ejecuta `migrations/20261019_baza_details.sql`. El ID permanece igual, por lo que se conservan las notas. Las tarjetas usan el catálogo local, de modo que los cambios visuales se ven al recargar.

## Segunda candidata: La Loma de Ana María II
Precio aportado por el organizador: 520 € por las dos noches, es decir, 40 € por persona entre 13. Dirección: Pago La Loma, 18656 Chite, Granada, Andalucía. Se mantiene la foto existente `assets/loma-ana-maria.jpg`.

La captura indica 14 plazas, 5 dormitorios insonorizados, 5 baños, salón comedor con chimenea, cocina equipada, suelo radiante, aire acondicionado, jardín con barbacoa y piscina. Los tiempos de 20 minutos a Granada, 30 a la playa y 40 a Sierra Nevada proceden de la descripción del alojamiento y son orientativos. La tarjeta permite abrir Google Maps para comprobar el trayecto desde Granada centro. No se han inferido condiciones de cancelación ni suplementos.

Los datos visibles se actualizan al recargar; `migrations/20261019_loma_details.sql` permite sincronizarlos con Supabase conservando las puntuaciones.

## Tercera candidata: Casa Rural Iratxe
Precio seleccionado por el organizador: 1.054 € por 2 noches para 13 adultos (81,08 € por persona redondeado a céntimos). Se usa la tarifa con cancelación gratuita antes del 21/01/2027 y pago a partir del 19/01/2027, no la alternativa no reembolsable de 949 €. La captura indica impuestos y cargos incluidos y solicitud con respuesta del anfitrión en 24 horas.

Dirección: Diseminado Extrarradio, 973, 18270 Montefrío, España. Resumen de la captura: 8 dormitorios, 9 baños, 4 camas dobles y 10 individuales, piscina privada, cocina con lavavajillas y cafetera, aire acondicionado, WiFi, barbacoa, patio, balcón y terraza con vistas. La nota 10/10 corresponde a la ubicación en Booking y procede de 1 comentario; no es la puntuación del grupo. La foto principal es `assets/iratxe.jpg`, aportada por el organizador y ampliable desde la tarjeta.

Se muestran unos 60 minutos orientativos desde Granada centro; Turismo de Montefrío indica menos de una hora entre la localidad y Granada: https://www.turismomontefrio.org/conoce-montefrio/situacion/. Es una estimación con margen de acceso local, no una medición de tráfico. El enlace abre la ruta de Google Maps hasta la dirección indicada. Para sincronizar los datos con Supabase, ejecuta `migrations/20261019_iratxe_details.sql`.

## Cuarta candidata: Cortijo Rural Las Nogueras
Precio aportado: 672 € por dos noches, es decir, 51,69 € por persona entre 13, redondeado a céntimos. Dirección: Carretera Huétor Tájar - Montefrío km 9, Montefrío (Granada). Se mantiene la foto `assets/las-nogueras.webp`.

La captura indica 6 dormitorios, 3 baños (uno en la planta baja y dos en la primera), chimenea, cocina equipada, lavadora, jardines, barbacoa, piscina exterior de temporada, sala de juegos con ping pong y aparcamiento gratuito. Hay un río a 200 metros. El tiempo orientativo de 45 minutos desde Granada procede de la descripción del alojamiento, no de una consulta de tráfico. La tarjeta abre Google Maps tanto para ver la ubicación como para consultar la ruta. No se han añadido condiciones de cancelación ni impuestos no confirmados.

`migrations/20261019_nogueras_details.sql` permite sincronizar los datos con Supabase sin cambiar el ID ni las puntuaciones.

## Quinta candidata: La Estaquilla
Precio aportado: 700 € por las dos noches, 53,85 € por persona entre 13, redondeado a céntimos. Dirección: Parcelas Las Estaquillas, s/n, Compl. Dom. Barriada Marchena, 18650 Dúrcal (Granada). Se mantiene `assets/la-estaquilla.webp`.

La captura indica 14 plazas, una sola planta adaptada a personas con movilidad reducida, 5 dormitorios y 3 baños con ducha (dos compartidos y uno privado), cocina comedor, salón con chimenea, calefacción y aire acondicionado frío/calor en habitaciones. Exterior amueblado, piscina vallada y huerto. Se admiten mascotas. La leña y la cama supletoria se cobran aparte; la tarjeta lo recoge en las condiciones.

Tiempo orientativo: 30 minutos desde Granada centro, estimado a partir del trayecto Granada–Dúrcal (unos 24–28 minutos según las referencias de rutas) y el acceso local, sin datos de tráfico en vivo. Referencia: https://www.mejorruta.com/distancia/2517117-2518774/Granada/Durcal/. Google Maps abre la dirección completa y la ruta desde Granada. `migrations/20261019_estaquilla_details.sql` sincroniza los campos con Supabase conservando las notas.

## Sexta candidata: Casa en El Padul · HomeToGo
Precio aportado: 616 € por dos noches, 47,38 € por persona al repartir entre 13, redondeado a céntimos. Foto `assets/home.jpg`, ampliable en la web. Solo se conoce el municipio, El Padul: Maps apunta al municipio y la tarjeta deja pendiente la dirección exacta.

La captura muestra 5 dormitorios: dos con una cama doble cada uno, uno con dos camas individuales, uno con dos dobles y uno con una doble grande. Total: cinco camas dobles y dos individuales (12 plazas en camas). Además, salón con sofá, cocina y dos baños con ducha, bidé, lavabo y agua fría y caliente. No se considera el sofá una plaza extra porque no se indica que sea sofá cama. El enlace está configurado para 12 adultos: falta confirmar la persona número 13 y cualquier suplemento. No se atribuyen servicios que no aparecen en la captura.

Tiempo orientativo hasta el municipio: 25 minutos desde Granada centro, a partir de referencias de rutas de unos 23 minutos (https://www.distanciasentreciudades.com/distancia-granada-a-padul). No es un tiempo medido hasta la casa. Para sincronizar estos datos con Supabase conservando sus notas, ejecuta `migrations/20261019_hometogo_details.sql`.
