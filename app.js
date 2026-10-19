(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const cfg = window.APP_CONFIG;
  const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const announce = (text, success = false) => {
    $('message').hidden = !text;
    $('message').textContent = text;
    $('message').classList.toggle('success', success);
    $('vote-feedback').hidden = !text;
    $('vote-feedback').textContent = text;
  };
  const identityKey = 'carcasas.participant.v1';
  function readParticipant() {
    try {
      const value = JSON.parse(window.localStorage.getItem(identityKey));
      if (!value || value.version !== 1 || typeof value.name !== 'string' || typeof value.email !== 'string') return null;
      return value;
    } catch { return null; }
  }
  function rememberParticipant() {
    try { window.localStorage.setItem(identityKey, JSON.stringify({version:1, ...identity()})); }
    catch { /* La sesión sigue funcionando si el navegador bloquea el almacenamiento. */ }
  }
  const sameRatings = (a, b) => a.size === b.size && [...a].every(([id, score]) => b.get(id) === score);
  const identity = () => ({name: $('voter-name').value.trim(), email: $('voter-email').value.trim().toLowerCase()});
  const validEmail = () => identity().email.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(identity().email) && $('voter-email').validity.valid;
  const validIdentity = () => identity().name.length >= 2 && identity().name.length <= 100 && validEmail();
  const unchanged = () => sameRatings(chosen, saved) && identity().name === savedIdentity.name && identity().email === savedIdentity.email;
  let sb, houses = [], chosen = new Map(), saved = new Map(), savedIdentity = {name:'', email:''}, hasVoted = false, busy = false, ready = false, entered = false, started = false, entryBusy = false, entryEmail = '', currentProfile = null, sessionPromise = null;
  const photoFallback = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="600" height="350" viewBox="0 0 600 350"><rect width="600" height="350" fill="#e5eadf"/><path d="M0 350 160 170 290 300 440 130 600 350" fill="#7c977c"/><text x="300" y="65" text-anchor="middle" font-family="sans-serif" font-size="20" fill="#294a39">Una escapada por descubrir</text></svg>');
  async function timed(operation) {
    let timer;
    try {
      return await Promise.race([operation, new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('La conexión está tardando demasiado. Vuelve a intentarlo.')), 15000); })]);
    } finally { clearTimeout(timer); }
  }
  const trip = window.TRIP_CONFIG || {people:13, nights:2};
  const money = value => Number(value).toLocaleString('es-ES', {style:'currency', currency:'EUR', maximumFractionDigits:2});
  function housePrice(h) {
    const total = h.total_price != null ? Number(h.total_price) : h.price_per_night != null ? Number(h.price_per_night) * trip.nights : null;
    if (total == null || !Number.isFinite(total) || total <= 0) return '<div class="price">Consultar<small>precio en el anuncio</small></div>';
    return `<div class="price"><strong>${money(total)}</strong><small>total · ${trip.nights} noches</small><span class="per-person">${money(total / trip.people)} / persona</span><small>entre ${trip.people} personas</small></div>`;
  }
  function renderHouses() {
    const visible = houses;
    $('house-count').textContent = `${houses.length} ${houses.length === 1 ? 'casa' : 'casas'}`;
    $('houses').innerHTML = visible.length ? visible.map((h, index) => {
      const selected = chosen.has(h.id);
      const tags = (h.amenities || []).slice(0,5).map(a => `<span>${escapeHtml(a)}</span>`).join('');
      const link = /^https:\/\//i.test(h.link_url || '') ? `<a class="link-btn" href="${escapeHtml(h.link_url)}" target="_blank" rel="noopener noreferrer">Ver anuncio ↗</a>` : '';
      const image = /^(https:\/\/|assets\/)/i.test(h.image_url || '') ? h.image_url : photoFallback;
      const mapQuery = encodeURIComponent(h.maps_query || `${h.name}, ${h.location}`);
      const maps = `https://www.google.com/maps/search/?api=1&query=${mapQuery}`;
      const directions = `https://www.google.com/maps/dir/?api=1&origin=${encodeURIComponent('Plaza del Carmen, Granada, España')}&destination=${mapQuery}&travelmode=driving`;
      const location = h.travel_minutes ? `<a class="address-link" href="${maps}" target="_blank" rel="noopener noreferrer">⌁ ${escapeHtml(h.location)} ↗</a><a class="travel-link" href="${directions}" target="_blank" rel="noopener noreferrer" title="${escapeHtml(h.travel_note || 'Tiempo orientativo. Consulta la ruta y el tráfico en Google Maps.')}">↗ ≈ ${Number(h.travel_minutes)} min en coche desde Granada centro</a>` : `<span>⌁ ${escapeHtml(h.location)}</span>`;
      const guests = h.booking_guests ? `Opción para ${Number(h.booking_guests)} adultos` : h.capacity ? `Hasta ${Number(h.capacity)} personas` : 'Plazas por confirmar';
      const photo = `<img class="house-photo" src="${escapeHtml(image)}" alt="${escapeHtml(h.image_url ? 'Fotografía de ' + h.name : 'Foto pendiente de ' + h.name)}" width="600" height="353" loading="${index < 3 ? 'eager' : 'lazy'}" decoding="async" referrerpolicy="no-referrer">`;
      return `<article class="house-card ${selected ? 'selected' : ''}">${h.image_url ? `<button class="photo-preview" type="button" data-photo="${escapeHtml(h.id)}" aria-label="Ampliar foto de ${escapeHtml(h.name)}">${photo}<span>Ampliar foto ↗</span></button>` : photo}<div class="house-inner"><div class="card-top"><div><h3 class="house-name">${escapeHtml(h.name)}</h3><div class="location">${location}${h.location_note ? `<span class="location-note">${escapeHtml(h.location_note)}</span>` : ''}<span class="guest-count">${guests}</span></div></div>${housePrice(h)}</div><div class="amenities">${tags}</div><p class="description">${escapeHtml(h.description)}</p>${h.booking_conditions ? `<details class="booking-conditions"><summary>Precio y condiciones de la oferta</summary><p>${escapeHtml(h.booking_conditions)}</p></details>` : ''}<div class="card-actions"><fieldset class="star-rating" data-house="${escapeHtml(h.id)}"><legend>Tu nota para ${escapeHtml(h.name)}</legend><div class="star-options">${[1,2,3,4,5].map(score => `<label class="star-option ${score <= (chosen.get(h.id) || 0) ? 'filled' : ''}"><input type="radio" name="rating-${escapeHtml(h.id)}" data-rating-house="${escapeHtml(h.id)}" value="${score}" aria-label="${score} de 5 estrellas para ${escapeHtml(h.name)}" ${chosen.get(h.id) === score ? 'checked' : ''} ${busy || !ready ? 'disabled' : ''}><span aria-hidden="true">★</span></label>`).join('')}</div><span class="rating-label" data-rating-label>${selected ? `${chosen.get(h.id)} de 5` : 'Sin valorar'}</span><button type="button" class="clear-rating text-btn" data-clear="${escapeHtml(h.id)}" ${!selected || busy || !ready ? 'disabled' : ''}>Quitar nota</button></fieldset>${link}</div></div></article>`;
    }).join('') : '<div class="empty-state"><h3>Todavía no hay casas disponibles</h3><p>Vuelve más tarde para ver las opciones del grupo.</p></div>';
    $('houses').querySelectorAll('img').forEach(img => img.addEventListener('error', () => { img.src = photoFallback; }, {once:true}));
  }
  function updateActions() {
    const n = chosen.size;
    $('selection-count').textContent = `${n} ${n === 1 ? 'casa valorada' : 'casas valoradas'}`;
    $('save-state').textContent = !ready ? 'Conectando con tus puntuaciones…' : busy ? 'Guardando tus puntuaciones…' : !sameRatings(chosen, saved) ? 'Cambios sin guardar' : saved.size > 0 ? 'Tus puntuaciones están guardadas' : 'Elige las estrellas de cada casa';
    $('save-votes').disabled = !entered || !ready || busy || !validIdentity() || (n === 0 && saved.size === 0) || (hasVoted && unchanged());
    $('save-votes').innerHTML = `${busy ? 'Guardando…' : hasVoted ? 'Actualizar valoraciones' : 'Guardar valoraciones'} <span aria-hidden="true">↗</span>`;
    $('edit-votes').hidden = !hasVoted;
    $('refresh-results').disabled = !ready || resultsBusy;
    $('voter-name').disabled = busy || entryBusy;
    $('voter-email').disabled = busy || entryBusy;
    $('entry-submit').disabled = entryBusy;
    $('entry-submit').textContent = entryBusy ? 'Comprobando tu correo…' : $('name-field').hidden ? 'Continuar' : 'Crear usuario y entrar';
    $('houses').querySelectorAll('[data-rating-house]').forEach(input => { input.disabled = busy || !ready; });
    $('houses').querySelectorAll('[data-clear]').forEach(btn => { btn.disabled = busy || !ready || !chosen.has(btn.dataset.clear); });
  }
  let resultsBusy = false;
  const formatScore = score => Number(score).toLocaleString('es-ES', {minimumFractionDigits:2, maximumFractionDigits:2});
  async function loadResults() {
    if (!entered || !ready || resultsBusy) return;
    resultsBusy = true;
    $('refresh-results').disabled = true;
    $('results-status').textContent = 'Actualizando las notas del grupo…';
    try {
      const {data, error} = await timed(sb.rpc('get_rating_results'));
      if (error) throw error;
      const totals = new Map((data || []).map(r => [r.house_id, {count:Number(r.rating_count) || 0, average:r.average_rating == null ? null : Number(r.average_rating)}]));
      const ranked = houses.map(h => ({...h, ...(totals.get(h.id) || {count:0, average:null})})).sort((a,b) => (b.average ?? -1) - (a.average ?? -1) || b.count - a.count || a.name.localeCompare(b.name, 'es'));
      let previous = null, rank = 0;
      $('results').innerHTML = ranked.map((h, index) => {
        if (!previous || h.average !== previous.average || h.count !== previous.count) rank = index + 1;
        previous = h;
        return `<article class="result-row"><div class="result-title"><span><span class="rank-number">${h.count ? rank + '.' : '—'}</span> ${escapeHtml(h.name)}</span><span class="average-score">${h.count ? `★ ${formatScore(h.average)} <small>/ 5</small>` : 'Sin valorar'}</span></div><span class="result-count">${h.count} ${h.count === 1 ? 'valoración' : 'valoraciones'}</span><div class="bar-track" aria-hidden="true"><div class="bar-fill" style="width:${h.count ? h.average / 5 * 100 : 0}%"></div></div></article>`;
      }).join('');
      $('results-status').textContent = `Actualizado a las ${new Date().toLocaleTimeString('es-ES', {hour:'2-digit', minute:'2-digit'})}. Las casas sin valorar no cuentan como un cero.`;
    } catch (error) {
      console.error(error);
      $('results-status').textContent = 'No se han podido cargar los resultados. Pulsa Actualizar para reintentarlo.';
      throw error;
    } finally { resultsBusy = false; $('refresh-results').disabled = !ready; }
  }
  function showTab(tab) {
    const results = tab === 'results';
    $('houses-panel').hidden = results;
    $('results-section').hidden = !results;
    for (const [id, selected] of [['tab-houses', !results], ['tab-results', results]]) {
      $(id).setAttribute('aria-selected', String(selected));
      $(id).setAttribute('tabindex', selected ? '0' : '-1');
    }
    if (results) {
      if (ready) loadResults().catch(() => {});
      else $('results-status').textContent = 'Los resultados estarán disponibles cuando conectemos con la votación.';
    }
  }
  async function ensureSession() {
    if (!cfg || !/^https:\/\//.test(cfg.supabaseUrl || '') || !cfg.supabasePublishableKey || cfg.supabasePublishableKey.includes('PON_AQUI')) throw new Error('Falta configurar la conexión de la web.');
    if (!window.supabase?.createClient) throw new Error('No se pudo cargar la conexión. Recarga la página para intentarlo de nuevo.');
    sb ||= window.supabase.createClient(cfg.supabaseUrl, cfg.supabasePublishableKey);
    if (!sessionPromise) sessionPromise = (async () => {
      const {data, error} = await timed(sb.auth.getSession());
      if (error) throw error;
      if (data.session) return data.session;
      const response = await timed(sb.auth.signInAnonymously());
      if (response.error) throw response.error;
      return response.data.session;
    })();
    try { return await sessionPromise; } catch (error) { sessionPromise = null; throw error; }
  }
  async function init() {
    ready = false;
    $('retry').hidden = true;
    $('houses').setAttribute('aria-busy', 'true');
    if (window.HOUSE_CATALOG) { houses = window.HOUSE_CATALOG; renderHouses(); }
    else { $('houses').innerHTML = '<p class="loading">Preparando las casas…</p>'; $('house-count').textContent = 'Cargando…'; }
    announce('');
    updateActions();
    try {
      await ensureSession();
      const [houseResponse, voteResponse] = await timed(Promise.all([
        sb.from('houses').select('id,name,location,capacity,price_per_night,description,amenities,image_url,link_url').eq('active',true).order('display_order'),
        sb.rpc('get_my_ratings')
      ]));
      if (houseResponse.error) throw houseResponse.error;
      const remoteHouses = houseResponse.data || [];
      if (window.HOUSE_CATALOG) {
        const availableIds = new Set(remoteHouses.map(h => h.id));
        if (!window.HOUSE_CATALOG.every(h => availableIds.has(h.id))) {
          console.error('Ejecuta migrations/20261019_real_houses.sql en Supabase.');
          announce('Las casas ya están listas para comparar. La persona que organiza debe activar la nueva votación antes de guardar.');
          $('retry').hidden = false;
          return;
        }
        houses = window.HOUSE_CATALOG;
      } else houses = remoteHouses;
      if (voteResponse.error) { renderHouses(); console.error('Ejecuta migrations/20261019_star_ratings.sql en Supabase.', voteResponse.error); announce('Las valoraciones por estrellas todavía no están activadas. Contacta con la persona que organiza.'); $('retry').hidden = false; return; }
      const activeIds = new Set(houses.map(h => h.id));
      saved = new Map((voteResponse.data || []).filter(v => activeIds.has(v.house_id) && Number.isInteger(v.score) && v.score >= 1 && v.score <= 5).map(v => [v.house_id, v.score]));
      chosen = new Map(saved);
      savedIdentity = {name: currentProfile.name, email: currentProfile.email};
      hasVoted = saved.size > 0;
      ready = true;
      renderHouses();
      updateActions();
      if (!$('results-section').hidden) loadResults().catch(() => {});
    } catch (error) {
      console.error(error);
      if (!houses.length) {
        $('house-count').textContent = 'Sin conexión';
        $('houses').innerHTML = '<div class="empty-state"><h3>No hemos podido cargar las casas</h3><p>Comprueba tu conexión y vuelve a intentarlo.</p></div>';
      } else renderHouses();
      announce((/demasiado|migración/.test(error.message || '')) ? error.message : 'No se ha podido conectar con la votación. Inténtalo de nuevo en unos instantes.');
      $('retry').hidden = false;
    } finally { $('houses').setAttribute('aria-busy', 'false'); updateActions(); }
  }
  function updateRatingCard(group, id) {
    const score = chosen.get(id) || 0;
    group.querySelectorAll('.star-option').forEach(label => {
      const input = label.querySelector('input');
      input.checked = Number(input.value) === score;
      label.classList.toggle('filled', Number(input.value) <= score);
    });
    group.querySelector('[data-rating-label]').textContent = score ? `${score} de 5` : 'Sin valorar';
    group.closest('.house-card').classList.toggle('selected', score > 0);
    announce('');
    updateActions();
  }
  $('houses').addEventListener('change', event => {
    const input = event.target.closest('[data-rating-house]');
    if (!input || !entered || busy || !ready) return;
    const score = Number(input.value), id = input.dataset.ratingHouse;
    if (!houses.some(h => h.id === id) || !Number.isInteger(score) || score < 1 || score > 5) return;
    chosen.set(id, score);
    updateRatingCard(input.closest('fieldset'), id);
  });
  $('houses').addEventListener('click', event => {
    const preview = event.target.closest('[data-photo]');
    if (preview?.dataset.photo) {
      const house = houses.find(h => h.id === preview.dataset.photo);
      if (house && /^(https:\/\/|assets\/)/i.test(house.image_url || '')) {
        $('photo-dialog-image').src = house.image_url;
        $('photo-dialog-image').alt = `Fotografía de ${house.name}`;
        $('photo-dialog-title').textContent = house.name;
        $('photo-dialog').showModal();
      }
      return;
    }
    const btn = event.target.closest('[data-clear]');
    if (!btn || !entered || busy || !ready) return;
    chosen.delete(btn.dataset.clear);
    updateRatingCard(btn.closest('fieldset'), btn.dataset.clear);
  });
  $('close-photo').addEventListener('click', () => $('photo-dialog').close());
  $('photo-dialog').addEventListener('click', event => { if (event.target === $('photo-dialog')) $('photo-dialog').close(); });
  $('tab-houses').addEventListener('click', () => showTab('houses'));
  $('go-houses').addEventListener('click', () => showTab('houses'));
  $('hero-houses').addEventListener('click', () => showTab('houses'));
  $('tab-results').addEventListener('click', () => showTab('results'));
  for (const id of ['tab-houses', 'tab-results']) {
    $(id).addEventListener('keydown', event => {
      if (!['ArrowLeft','ArrowRight','Home','End'].includes(event.key)) return;
      event.preventDefault();
      const next = event.key === 'Home' ? 'houses' : event.key === 'End' ? 'results' : id === 'tab-houses' ? 'results' : 'houses';
      showTab(next); $(`tab-${next}`).focus();
    });
  }
  function showNameField(show) {
    $('name-field').hidden = !show;
    $('voter-name').required = show;
  }
  function entryError(text) {
    $('entry-error').textContent = text;
    $('entry-error').hidden = !text;
  }
  $('entry-form').addEventListener('input', () => {
    entryError('');
    if (identity().email !== entryEmail) { showNameField(false); $('voter-name').value = ''; }
    updateActions();
  });
  async function login() {
    if (entryBusy) return;
    entryError('');
    if (!validEmail()) { entryError('Introduce un correo válido.'); $('entry-form').reportValidity(); return; }
    const creating = !$('name-field').hidden && entryEmail === identity().email;
    if (creating && !validIdentity()) { entryError('Introduce tu nombre (entre 2 y 100 caracteres).'); $('entry-form').reportValidity(); return; }
    entryBusy = true; updateActions();
    try {
      await ensureSession();
      const {data, error} = await timed(sb.rpc('enter_participant', {p_email:identity().email, p_name:creating ? identity().name : null}));
      if (error) throw error;
      if (data?.needs_name) {
        entryEmail = identity().email;
        showNameField(true);
        $('entry-intro').textContent = 'Es tu primera vez. Dinos tu nombre para crear tu usuario y asociar tus puntuaciones.';
        $('voter-name').disabled = false;
        $('voter-name').focus();
        return;
      }
      if (!data || typeof data.name !== 'string' || typeof data.email !== 'string' || !data.participant_id) throw new Error('Respuesta de acceso no válida');
      currentProfile = data;
      $('voter-name').value = data.name;
      $('voter-email').value = data.email;
      if (!validIdentity()) throw new Error('Datos de usuario no válidos');
      rememberParticipant();
      entered = true;
      $('entry-screen').hidden = true;
      $('app-content').hidden = false;
      $('participant-name').textContent = `Votas como ${data.name} · ${data.email}`;
      $('change-identity').focus();
      if (!started) { started = true; await init(); }
    } catch (error) {
      console.error(error);
      entryError('No se ha podido iniciar sesión. Vuelve a intentarlo. Si sigue fallando, avisa a la persona que organiza.');
    } finally { entryBusy = false; updateActions(); }
  }
  $('entry-form').addEventListener('submit', async event => { event.preventDefault(); await login(); });
  $('change-identity').addEventListener('click', () => {
    if (busy || entryBusy || resultsBusy) return;
    entered = false; ready = false; started = false; hasVoted = false;
    currentProfile = null; entryEmail = '';
    chosen = new Map(); saved = new Map(); savedIdentity = {name:'', email:''};
    $('results').innerHTML = '';
    $('results-section').hidden = true;
    $('houses-panel').hidden = false;
    $('tab-houses').setAttribute('aria-selected', 'true'); $('tab-houses').setAttribute('tabindex', '0');
    $('tab-results').setAttribute('aria-selected', 'false'); $('tab-results').setAttribute('tabindex', '-1');
    $('entry-screen').hidden = false; $('app-content').hidden = true;
    $('voter-name').value = ''; $('voter-email').value = '';
    showNameField(false); entryError('');
    $('entry-intro').textContent = 'Introduce tu correo para entrar. Si es tu primera vez, te pediremos también el nombre.';
    try { window.localStorage.removeItem(identityKey); } catch { /* Almacenamiento opcional. */ }
    announce(''); updateActions(); $('voter-email').focus();
  });
  $('retry').addEventListener('click', init);
  $('voter-form').addEventListener('submit', async event => {
    event.preventDefault();
    if (!validIdentity()) { $('voter-form').reportValidity(); return; }
    if (!entered || !ready || busy || (chosen.size === 0 && saved.size === 0) || (hasVoted && unchanged())) return;
    busy = true; announce(''); updateActions();
    let voteSaved = false;
    try {
      const {error} = await timed(sb.rpc('save_ratings', {p_ratings:[...chosen].map(([house_id, score]) => ({house_id, score})), p_name:identity().name, p_email:identity().email}));
      if (error) throw error;
      saved = new Map(chosen); savedIdentity = identity(); rememberParticipant(); hasVoted = chosen.size > 0; voteSaved = true;
      announce('¡Listo! Tus valoraciones están guardadas. Puedes cambiar las estrellas cuando quieras.', true);
      showTab('results');
      $('tab-results').focus();
      $('results-section').scrollIntoView({behavior:'smooth', block:'start'});
    } catch (error) {
      console.error(error);
      if (voteSaved) announce('Tus valoraciones están guardadas. Pulsa Actualizar en Resultados para volver a cargar las notas.');
      else announce('No hemos podido confirmar el guardado. Tu selección sigue aquí; vuelve a guardar para confirmarla.');
    } finally { busy = false; updateActions(); }
  });
  $('refresh-results').addEventListener('click', async () => {
    const btn = $('refresh-results'); btn.disabled = true;
    try { await loadResults(); announce('Resultados actualizados.', true); }
    catch { announce('No se han podido actualizar los resultados. Vuelve a intentarlo.'); }
    finally { btn.disabled = false; }
  });
  $('edit-votes').addEventListener('click', () => { showTab('houses'); $('candidatas').scrollIntoView({behavior:'smooth'}); });
  showNameField(false);
  updateActions();
  const remembered = readParticipant();
  if (remembered) {
    $('voter-email').value = remembered.email;
    if (validEmail()) login();
  }
})();
