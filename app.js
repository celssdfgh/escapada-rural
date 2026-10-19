(() => {
  'use strict';
  const cfg = window.APP_CONFIG;
  const $ = (id) => document.getElementById(id);
  const message = $('message');
  const showError = (msg) => { message.hidden = false; message.textContent = msg; };
  const clearError = () => { message.hidden = true; message.textContent = ''; };
  const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  if (!cfg || !/^https:\/\//.test(cfg.supabaseUrl) || cfg.supabasePublishableKey.includes('PON_AQUI')) {
    $('houses').innerHTML = '<p class="loading">La web está preparada. Configura las credenciales públicas en <strong>config.js</strong> y ejecuta <strong>supabase.sql</strong> para mostrar las casas.</p>';
    $('house-count').textContent = 'Pendiente de configurar';
    return;
  }
  if (!window.supabase?.createClient) { showError('No se pudo cargar Supabase. Comprueba tu conexión a Internet.'); return; }
  const sb = window.supabase.createClient(cfg.supabaseUrl, cfg.supabasePublishableKey);
  let houses = [], chosen = new Set(), saved = new Set(), hasVoted = false, busy = false;
  async function request(operation) { try { clearError(); return await operation(); } catch(e) { console.error(e); showError(e.message || 'Se ha producido un error. Prueba a actualizar.'); return null; } }
  const photoFallback = 'https://images.unsplash.com/photo-1449158743715-0a90ebb6d2d8?w=900&q=80';
  function renderHouses() {
    $('house-count').textContent = `${houses.length} CASAS`;
    $('houses').innerHTML = houses.map(h => {
      const selected = chosen.has(h.id);
      const tags = (h.amenities || []).slice(0,5).map(a => `<span>${escapeHtml(a)}</span>`).join('');
      const link = /^https:\/\//.test(h.link_url || '') ? `<a class="link-btn" href="${escapeHtml(h.link_url)}" target="_blank" rel="noopener noreferrer">Ver anuncio ↗</a>` : '';
      const image = /^https:\/\//.test(h.image_url || '') ? h.image_url : photoFallback;
      return `<article class="house-card ${selected?'selected':''}"><img class="house-photo" src="${escapeHtml(image)}" alt="Fotografía de ${escapeHtml(h.name)}" loading="lazy" referrerpolicy="no-referrer"><div class="house-inner"><div class="card-top"><div><h3 class="house-name">${escapeHtml(h.name)}</h3><p class="location">⌁ ${escapeHtml(h.location)} · ${Number(h.capacity)} personas</p></div><div class="price">${Number(h.price_per_night).toLocaleString('es-ES')} €<small>por noche</small></div></div><div class="amenities">${tags}</div><p class="description">${escapeHtml(h.description)}</p><div class="card-actions"><button type="button" class="pick-btn" data-house="${escapeHtml(h.id)}" aria-pressed="${selected}" ${busy?'disabled':''}>${selected?'✓ Seleccionada':'♡ Me gusta esta casa'}</button>${link}</div></div></article>`;
    }).join('');
    $('houses').querySelectorAll('[data-house]').forEach(btn => btn.addEventListener('click', () => {
      const id = btn.dataset.house;
      if (chosen.has(id)) chosen.delete(id); else chosen.add(id);
      renderHouses(); updateActions();
    }));
  }
  function updateActions() {
    const n = chosen.size;
    $('selection-count').textContent = `${n} ${n === 1 ? 'casa seleccionada' : 'casas seleccionadas'}`;
    $('save-votes').disabled = busy || n === 0 || (hasVoted && sameSets(chosen,saved));
    $('save-votes').innerHTML = `${busy?'Guardando…':hasVoted?'Actualizar mis votos':'Guardar mis votos'} <span>↗</span>`;
    $('edit-votes').hidden = !hasVoted;
  }
  function sameSets(a,b) { return a.size===b.size && [...a].every(id=>b.has(id)); }
  async function loadResults() {
    if (!hasVoted) return;
    const {data,error} = await sb.rpc('get_results');
    if (error) throw error;
    const counts = new Map((data || []).map(r => [r.house_id, Number(r.vote_count)]));
    const maximum = Math.max(1,...counts.values());
    $('results').innerHTML = [...houses].sort((a,b)=>(counts.get(b.id)||0)-(counts.get(a.id)||0)).map(h => {
      const count = counts.get(h.id) || 0;
      return `<div class="result-row"><div class="result-title"><span>${escapeHtml(h.name)}</span><span class="result-count">${count} ${count===1?'voto':'votos'}</span></div><div class="bar-track"><div class="bar-fill" style="width:${Math.round(count/maximum*100)}%"></div></div></div>`;
    }).join('');
    $('results-section').hidden = false;
  }
  async function init() {
    await request(async () => {
      let {data:{session},error:sessionError} = await sb.auth.getSession();
      if (sessionError) throw sessionError;
      if (!session) {
        const {data,error} = await sb.auth.signInAnonymously();
        if (error) throw new Error('No se pudo iniciar la sesión anónima. Activa Anonymous Sign-Ins en Supabase. Detalle: '+error.message);
        session = data.session;
      }
      const {data:houseData,error:houseError} = await sb.from('houses').select('*').eq('active',true).order('display_order');
      if (houseError) throw houseError;
      houses = houseData || [];
      const {data:mine,error:myError} = await sb.from('votes').select('house_id').eq('user_id',session.user.id);
      if (myError) throw myError;
      saved = new Set((mine || []).map(v=>v.house_id)); chosen = new Set(saved); hasVoted = saved.size>0;
      renderHouses();updateActions();
      if (!houses.length) showError('No hay casas activas. Añádelas desde Supabase → Table Editor → houses.');
      if (hasVoted) await loadResults();
    });
  }
  $('save-votes').addEventListener('click', () => request(async () => {
    if (busy || chosen.size===0) return;
    busy=true;updateActions();renderHouses();
    try {
      const {error} = await sb.rpc('save_votes',{p_house_ids:[...chosen]});
      if (error) throw error;
      saved = new Set(chosen);hasVoted=true;
      await loadResults();
      $('results-section').scrollIntoView({behavior:'smooth',block:'start'});
    } finally {busy=false;updateActions();renderHouses();}
  }));
  $('refresh-results').addEventListener('click',()=>request(loadResults));
  $('edit-votes').addEventListener('click',()=>document.querySelector('.content').scrollIntoView({behavior:'smooth'}));
  init();
})();
