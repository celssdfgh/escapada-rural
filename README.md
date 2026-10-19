# La Escapada — web de votación de casas rurales

Web responsive sin servidor propio, sin compilación y sin cuentas para los participantes. Permite seleccionar varias casas, cambiar la selección y ver resultados solo después de votar.

## Publicación (15 minutos de configuración, según experiencia)

### 1. Crear Supabase
1. Abre https://supabase.com/dashboard y crea un proyecto.
2. En **SQL Editor → New query**, pega TODO el contenido del archivo `supabase.sql` y pulsa **Run**. Recomendado en un proyecto nuevo: el script crea las tablas, permisos, funciones y tres casas ficticias de ejemplo.
3. En **Authentication → Providers → Anonymous Sign-Ins** (o Anonymous), **activa los inicios de sesión anónimos** y guarda. La ubicación del menú puede variar.
4. En **Project Settings → API** o **Connect**, copia **Project URL** y la **publishable key** (`sb_publishable_...`, o la antigua `anon` key). Nunca copies `service_role`, secret keys ni una contraseña.
5. Abre `config.js` y sustituye `PON_AQUI_TU_PROJECT_URL` y `PON_AQUI_TU_PUBLISHABLE_KEY` entre las comillas.

### 2. Añadir casas reales
1. En **Supabase → Table Editor → houses**, edita las tres filas de ejemplo o bórralas y crea otras.
2. Campos principales: `name` (nombre), `location` (ubicación), `capacity` (personas), `price_per_night` (precio por noche), `description`, `amenities` (lista de características), `image_url` (URL de una foto pública HTTPS), `link_url` (URL de Booking, Airbnb o web del alojamiento), `display_order` (orden) y `active` (mostrar/ocultar).
3. Para las imágenes, usa enlaces directos a imágenes públicas que permitan ser mostradas desde otra web. Las imágenes de algunas plataformas de reservas bloquean ese uso; en ese caso utiliza una imagen propia o con permiso, subida a tu repositorio y una URL absoluta de GitHub Pages.
4. El precio se muestra **por noche**, no por persona. Si quieres otra unidad habría que cambiar la etiqueta del diseño.

### 3. Publicar en GitHub Pages
1. En https://github.com/new crea un repositorio **Public** llamado `escapada-rural` (GitHub Free publica Pages desde repositorios públicos).
2. Selecciona **Add file → Upload files** y sube `index.html`, `styles.css`, `app.js`, `config.js`. No hace falta subir `supabase.sql`, aunque no contiene credenciales privadas.
3. Haz clic en **Commit changes**.
4. En el repositorio: **Settings → Pages → Build and deployment → Source: Deploy from a branch → Branch: main → /(root) → Save**.
5. Abre la dirección que GitHub muestre en Pages, normalmente `https://TUUSUARIO.github.io/escapada-rural/`.
6. Comparte el enlace por WhatsApp.

## Cómo funciona la votación
- La web crea automáticamente un usuario anónimo de Supabase **por navegador**.
- Una persona marca **tantas casas como quiera** y hace clic en **Guardar mis votos**.
- El guardado reemplaza su selección anterior en una sola operación de base de datos.
- Los resultados solo se desbloquean cuando ese usuario ha guardado **al menos una casa**.
- Puede volver a marcar/desmarcar opciones y pulsar **Actualizar mis votos**.
- No es una votación verificable por persona: otro navegador, modo incógnito, borrar almacenamiento o utilizar otro dispositivo puede generar otro usuario y permitir votos extra.
- No se recogen nombres ni emails. Los resultados se actualizan con el botón **Actualizar** (no en tiempo real automáticamente).
- No existe cierre automático de votación ni prevención robusta de abuso. Para grupos de amigos normalmente basta, pero para elecciones auditables haría falta autenticación o invitaciones únicas.

## Seguridad y costes
- GitHub Pages aloja HTML/CSS/JS; Supabase guarda los votos y gestiona la autenticación anónima.
- La `publishable key` es pública por diseño; **nunca** publiques la `service_role` o secret key.
- El SQL activa RLS, limita la lectura de votos propios y expone totales mediante una función que comprueba el voto del solicitante.
- Las funciones usan `security definer`; están limitadas a `authenticated`, verifican `auth.uid()` y usan `search_path` vacío y tablas totalmente cualificadas.
- Usuarios malintencionados pueden crear muchas identidades anónimas y votos; no es un sistema antifraude. Considera configurar CAPTCHA y límites de Supabase si compartes la URL públicamente.
- El plan gratuito de Supabase está sujeto a límites, cambios y posible pausa por inactividad. Comprueba las condiciones actuales de los servicios.

## Probar antes de compartir
1. Abre la web: deben salir tres casas de ejemplo.
2. Marca dos y guarda; deberían aparecer resultados.
3. Desmarca una y guarda de nuevo; debería quedar un solo voto de esa sesión.
4. Recarga la página: la selección debe mantenerse.
5. Desde otro navegador se debe ocultar el resultado hasta haber votado.
6. Prueba el enlace a cada alojamiento y cómo se ve la web en móvil.

## Modificar colores y textos
- `index.html`: encabezados y mensajes.
- `styles.css`: diseño y colores (`:root`).
- `supabase.sql`: estructura, seguridad y ejemplos de casas.
- `app.js`: funcionamiento de la interfaz y votos.
- `config.js`: URL y clave pública del proyecto Supabase.
