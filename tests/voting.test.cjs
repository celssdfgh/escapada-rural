const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../app.js'), 'utf8');
const flush = () => new Promise(resolve => setImmediate(resolve));
async function setup({autoEnter = true, participants = new Map(), scores = new Map(), storage = new Map(), storageBlocked = false, catalog = null} = {}) {
  const nodes = new Map(), calls = [];
  const state = {saveError:null, resultsError:null, entryError:null, ratingError:null, authCalls:0, resultsData:[{house_id:'a',rating_count:2,average_rating:4.5}]};
  let linkedEmail = null;
  const get = id => {
    if (!nodes.has(id)) nodes.set(id, {value:'',hidden:false,disabled:false,textContent:'',innerHTML:'',validity:{valid:true},events:{},classList:{toggle(){}},setAttribute(){},querySelectorAll(){return [];},scrollIntoView(){},focus(){},reportValidity(){},addEventListener(type,fn){this.events[type]=fn;}});
    return nodes.get(id);
  };
  const houses = [{id:'a',name:'Casa A',capacity:8,price_per_night:200}, {id:'b',name:'Casa B',capacity:12,price_per_night:300}];
  const sb = {
    auth:{getSession:async()=>{state.authCalls++;return {data:{session:{user:{id:'browser-session'}}}};}},
    from(){return {select(){return this;},eq(){return this;},order(){return this;},then(resolve){resolve({data:houses});}};},
    async rpc(name,args){
      calls.push({name,args});
      if (name === 'enter_participant') {
        if (state.entryError) return {error:state.entryError};
        const email = args.p_email;
        if (!participants.has(email) && !args.p_name) return {data:{needs_name:true}};
        if (!participants.has(email)) participants.set(email,{participant_id:`id-${email}`,name:args.p_name,email});
        linkedEmail = email;
        return {data:{needs_name:false,...participants.get(email)}};
      }
      if (name === 'get_my_ratings') return {data:scores.get(linkedEmail) || [],error:state.ratingError};
      if (name === 'save_ratings') {
        if (state.saveError) return {error:state.saveError};
        scores.set(linkedEmail, JSON.parse(JSON.stringify(args.p_ratings)).map(r=>({house_id:r.house_id,score:r.score})));
        return {error:null};
      }
      return {data:state.resultsData,error:state.resultsError};
    }
  };
  get('results-section').hidden = true; get('app-content').hidden = true;
  vm.runInNewContext(source, {window:{localStorage:{getItem(key){if(storageBlocked)throw Error('blocked');return storage.get(key) ?? null;},setItem(key,value){if(storageBlocked)throw Error('blocked');storage.set(key,value);},removeItem(key){storage.delete(key);}},HOUSE_CATALOG:catalog,APP_CONFIG:{supabaseUrl:'https://example.com',supabasePublishableKey:'public'},supabase:{createClient:()=>sb}},document:{getElementById:get},setTimeout,clearTimeout,console:{error(){}}});
  const setEmail = email => {get('voter-email').value=email;get('entry-form').events.input();};
  const setName = name => {get('voter-name').value=name;get('entry-form').events.input();};
  const group = {querySelectorAll(){return [];},querySelector(){return {textContent:''};},closest(){return {classList:{toggle(){}}};}};
  const choose = (score = 5, house = 'a') => get('houses').events.change({target:{closest:()=>({dataset:{ratingHouse:house},value:String(score),closest:()=>group})}});
  const clear = (house = 'a') => get('houses').events.click({target:{closest:()=>({dataset:{clear:house},closest:()=>group})}});
  const submit = async () => { await get('voter-form').events.submit({preventDefault(){}}); await flush(); };
  const enter = () => get('entry-form').events.submit({preventDefault(){}});
  const loginAs = async (email, name) => { setEmail(email); await enter(); if (!get('name-field').hidden && name) {setName(name);await enter();} };
  await flush();
  if (autoEnter && get('app-content').hidden) await loginAs('ana@example.com','Ana');
  await flush();
  return {get,calls,state,setEmail,setName,choose,clear,submit,enter,loginAs,participants,scores};
}
test('primero pide solo correo; un correo nuevo requiere nombre y se registra antes de votar', async()=>{
  const app=await setup({autoEnter:false});
  assert.equal(app.get('name-field').hidden,true);assert.equal(app.state.authCalls,0);
  app.setEmail('incorrecto');await app.enter();assert.equal(app.calls.length,0);
  app.setEmail('ANA@example.com');await app.enter();assert.equal(app.get('name-field').hidden,false);assert.equal(app.get('app-content').hidden,true);
  await app.enter();assert.equal(app.participants.size,0);
  app.setName(' Ana ');await app.enter();assert.equal(app.participants.get('ana@example.com').name,'Ana');assert.equal(app.get('app-content').hidden,false);
  assert.equal(app.scores.size,0);assert.equal(app.calls.some(c=>c.name.includes('Otp')),false);
});
test('el usuario conocido entra solo con correo y recupera nombre y notas desde otro navegador',async()=>{
  const participants=new Map(),scores=new Map();
  const first=await setup({participants,scores});first.choose(4);await first.submit();
  const next=await setup({autoEnter:false,participants,scores});
  await next.loginAs('ANA@example.com');
  assert.equal(next.get('name-field').hidden,true);assert.equal(next.get('app-content').hidden,false);
  assert.match(next.get('participant-name').textContent,/Ana/);assert.match(next.get('houses').innerHTML,/4 de 5/);
  assert.equal(next.get('save-votes').disabled,true);assert.equal(participants.size,1);
});
test('al cambiar de correo se limpia el nombre y no mezcla puntuaciones de usuarios',async()=>{
  const app=await setup();app.choose(5);await app.submit();
  app.get('change-identity').events.click();assert.equal(app.get('app-content').hidden,true);
  await app.loginAs('jose@example.com','José');assert.equal(app.get('selection-count').textContent,'0 casas valoradas');
  app.choose(2);await app.submit();
  app.get('change-identity').events.click();await app.loginAs('ana@example.com');
  assert.match(app.get('houses').innerHTML,/5 de 5/);assert.equal(app.participants.size,2);
});
test('si se cambia el correo durante el registro, vuelve a comprobarlo',async()=>{
 const app=await setup({autoEnter:false});app.setEmail('nuevo@example.com');await app.enter();app.setName('Nombre');
 app.setEmail('otro@example.com');assert.equal(app.get('name-field').hidden,true);assert.equal(app.get('voter-name').value,'');
 await app.enter();assert.equal(app.get('name-field').hidden,false);assert.equal(app.participants.size,0);
});
test('un fallo de acceso mantiene la entrada cerrada y permite reintentar',async()=>{
 const app=await setup({autoEnter:false});app.state.entryError=Error('missing migration');await app.loginAs('ana@example.com');
 assert.equal(app.get('app-content').hidden,true);assert.equal(app.get('entry-submit').disabled,false);assert.match(app.get('entry-error').textContent,/No se ha podido/);
 app.state.entryError=null;await app.loginAs('ana@example.com','Ana');assert.equal(app.get('app-content').hidden,false);
});
test('se recuerdan el correo, el usuario y sus notas al volver',async()=>{
 const storage=new Map(),participants=new Map(),scores=new Map();
 const first=await setup({storage,participants,scores});first.choose(4);await first.submit();
 const next=await setup({autoEnter:false,storage,participants,scores});
 assert.equal(next.get('entry-screen').hidden,true);assert.match(next.get('houses').innerHTML,/4 de 5/);
 assert.equal(next.get('name-field').hidden,true);
});
test('sin almacenamiento local se puede iniciar sesión y guardar',async()=>{
 const app=await setup({storageBlocked:true});app.choose(3);await app.submit();
 assert.equal(app.scores.get('ana@example.com')[0].score,3);
});
test('ignora identidades locales manipuladas y no usa nombres locales como fuente de verdad',async()=>{
 const app=await setup({autoEnter:false,storage:new Map([['carcasas.participant.v1',JSON.stringify({version:1,name:'Falso',email:'ana@example.com'})]]),participants:new Map([['ana@example.com',{participant_id:'real',email:'ana@example.com',name:'Ana'}]])});
 assert.match(app.get('participant-name').textContent,/Ana/);assert.doesNotMatch(app.get('participant-name').textContent,/Falso/);
});
test('guardar cambia y retira las notas, incluida la última, sin duplicarlas',async()=>{
 const app=await setup();app.choose(2);app.choose(4);await app.submit();
 assert.equal(app.scores.get('ana@example.com')[0].score,4);assert.equal(app.get('save-votes').disabled,true);
 app.clear();assert.equal(app.get('save-votes').disabled,false);await app.submit();assert.equal(app.scores.get('ana@example.com').length,0);
});
test('un fallo de guardado conserva los cambios; un fallo del ranking no pierde las notas',async()=>{
 const app=await setup();app.choose(5);app.state.saveError=Error('offline');await app.submit();
 assert.equal(app.get('save-votes').disabled,false);assert.match(app.get('vote-feedback').textContent,/No hemos podido confirmar/);
 app.state.saveError=null;app.state.resultsError=Error('offline');await app.submit();
 assert.match(app.get('vote-feedback').textContent,/Tus valoraciones están guardadas/);assert.match(app.get('results-status').textContent,/No se han podido cargar/);
 app.state.resultsError=null;await app.get('refresh-results').events.click();assert.match(app.get('results').innerHTML,/2 valoraciones/);
});
test('ranking por media numérica, después número de notas, y casas sin nota al final',async()=>{
 const app=await setup();app.state.resultsData=[{house_id:'a',rating_count:8,average_rating:'3.9'},{house_id:'b',rating_count:2,average_rating:'4.5'}];
 app.get('tab-results').events.click();await flush();assert.ok(app.get('results').innerHTML.indexOf('Casa B')<app.get('results').innerHTML.indexOf('Casa A'));
 app.state.resultsData=[{house_id:'a',rating_count:8,average_rating:'4.5'},{house_id:'b',rating_count:2,average_rating:'4.5'}];await app.get('refresh-results').events.click();
 assert.ok(app.get('results').innerHTML.indexOf('Casa A')<app.get('results').innerHTML.indexOf('Casa B'));
});
test('no se guardan notas inválidas ni casas ajenas al catálogo',async()=>{
 const app=await setup();for(const n of [0,6,NaN,1.5])app.choose(n);app.choose(4,'unknown');await app.submit();
 assert.equal(app.calls.some(c=>c.name==='save_ratings'),false);
});
test('la barra mantiene los cambios pendientes al cambiar de pestaña',async()=>{
 const app=await setup();app.choose(3);app.get('tab-results').events.click();await flush();
 assert.equal(app.get('save-votes').disabled,false);assert.match(app.get('save-state').textContent,/Cambios sin guardar/);
});

test('Baza muestra el precio de estancia y el reparto entre 13, con dirección y foto correctas',async()=>{
 const context={window:{}};vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../houses.js'),'utf8'),context);
 const app=await setup({catalog:context.window.HOUSE_CATALOG});
 const html=app.get('houses').innerHTML.replace(/\u00a0/g,' ');
 assert.match(html,/900,00 €/);assert.match(html,/69,23 € \/ persona/);assert.match(html,/total · 2 noches/);
 assert.doesNotMatch(html,/450,00 €/);assert.match(html,/assets\/baza.jpg/);assert.match(html,/data-photo=/);
 assert.match(html,/google.com\/maps\/search/);assert.match(decodeURIComponent(html),/Carretera Comarcal, 334, Kl.6.200, Baza/);
 assert.match(html,/≈ 80 min en coche desde Granada centro/);assert.match(html,/450 m²/);assert.match(html,/7 dormitorios/);
});
