/* PACE LAB — private opt-in sync, no credentials or health data shipped in this repository.
 * Supabase URL + public publishable key are configured by each user in settings.
 * Authentication and RLS remain mandatory. No service-role credentials in clients.
 */
(() => {
  'use strict';
  const CONFIG_KEY = 'pace_cloud_config_v1';
  const SESSION_KEY = 'pace_cloud_session_v1';
  const $ = id => document.getElementById(id);
  const clean = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const load = key => {try{return JSON.parse(localStorage.getItem(key))}catch{return null}};
  let config = load(CONFIG_KEY) || null;
  let session = load(SESSION_KEY) || null;
  let loading = false;
  const goodURL = text => { const u = new URL(text); if(u.protocol !== 'https:' || !/^[-a-z0-9]+\.supabase\.co$/i.test(u.hostname) || u.pathname !== '/') throw Error('Utilise une URL de projet *.supabase.co sécurisée.'); return u.origin; };
  const base = () => { if(!config?.url || !config?.key) throw Error('Configure ton projet privé Supabase.'); return goodURL(config.url); };
  const api = async (path, options={}, authorized=true) => {
    const host = base();
    if(authorized) await ensureToken();
    const resp = await fetch(`${host}/${path}`, {
      ...options,
      headers:{'apikey':config.key,'Content-Type':'application/json', ...(authorized&&session?.access_token? {'Authorization':`Bearer ${session.access_token}`} : {}), ...(options.headers||{})}
    });
    const body=await resp.text();
    let data; try{data=body?JSON.parse(body):null}catch{data=null}
    if(!resp.ok) throw Error(data?.msg||data?.message||`Erreur HTTP ${resp.status}`);
    return data;
  };
  async function ensureToken(){
    if(!session?.refresh_token)throw Error('Connecte-toi au compte privé PACE LAB.');
    if(Date.now()/1000 < Number(session.expires_at||0)-60)return;
    const data=await api('auth/v1/token?grant_type=refresh_token', {method:'POST',body:JSON.stringify({refresh_token:session.refresh_token})},false);
    session={access_token:data.access_token,refresh_token:data.refresh_token,expires_at:Math.floor(Date.now()/1000)+Number(data.expires_in)};
    localStorage.setItem(SESSION_KEY,JSON.stringify(session));
  }
  async function signIn(email,password,mode){
    if(mode==='signup'){
      await api('auth/v1/signup',{method:'POST',body:JSON.stringify({email,password})},false);
      return 'Compte créé. Valide ton e-mail si demandé, puis connecte-toi.';
    }
    const data=await api('auth/v1/token?grant_type=password',{method:'POST',body:JSON.stringify({email,password})},false);
    if(!data?.access_token||!data?.refresh_token)throw Error('Session non reçue. Vérifie ton e-mail.');
    session={access_token:data.access_token,refresh_token:data.refresh_token,expires_at:Math.floor(Date.now()/1000)+Number(data.expires_in)};
    localStorage.setItem(SESSION_KEY,JSON.stringify(session));
    await pull();
    return 'Compte connecté. Les séances disponibles ont été chargées.';
  }
  const isMatch = (old,r) => old.source_uuid === r.source_uuid || (old.origin!=='manual' && old.date===r.date && Math.abs((old.distance||0)-(r.distance||0))<0.015 && Math.abs((old.minutes||0)-(r.minutes||0))<0.6);
  async function pull(){
    if(loading || !config?.key || !session?.refresh_token)return;
    loading=true;
    try {
      const rows = await api('rest/v1/health_workouts?select=source_uuid,activity_kind,started_at,ended_at,duration_seconds,distance_meters,hr_average_bpm,hr_max_bpm,hr_at_end_bpm,recovery_hr_1min,recovery_hr_2min,recovery_hr_3min,recovery_hr_5min,recovery_state,recorded_at&order=started_at.desc&limit=500');
      // The running list displays only running workouts. Other activity types remain in private storage.
      const running=rows.filter(x=>x.activity_kind==='running' && x.distance_meters>0 && x.duration_seconds>0)
        .map(x=>({source_uuid:x.source_uuid,date:x.started_at.slice(0,10),minutes:x.duration_seconds/60,distance:x.distance_meters/1000,
          pace:x.duration_seconds/60/(x.distance_meters/1000),hr:x.hr_average_bpm,hrMax:x.hr_max_bpm,
          origin:'healthkit-cloud',recovery:{end:x.hr_at_end_bpm,one:x.recovery_hr_1min,two:x.recovery_hr_2min,three:x.recovery_hr_3min,five:x.recovery_hr_5min,status:x.recovery_state}}));
      // Idempotent reimport; never overwrite manually recorded notes or RPE.
      for(const r of running){
        const old=state.runs.find(z=>isMatch(z,r));
        if(old){if(old.origin==='manual')continue;state.runs=state.runs.filter(x=>x!==old);state.runs.push({...old,...r,rpe:old.rpe??null,pain:old.pain??null,note:old.note||''});}
        else state.runs.push(r);
      }
      persist(); render();
      return {retrieved:rows.length, running:running.length};
    } finally {loading=false;}
  }
  function mount(){
    const slot=$('cloudHealthBox'); if(!slot)return;
    slot.innerHTML = `<h4>Apple Santé · Synchronisation privée</h4>
    <p>Connexion facultative à un espace Supabase privé. La PWA ne lit pas elle-même HealthKit : le compagnon iPhone doit envoyer les séances. Ton historique n'est jamais publié sur GitHub.</p>
    <form id="paceCloudForm" class="formCard" autocomplete="on">
      <div class="inputGroup"><label>URL du projet Supabase</label><input name="url" type="url" value="${clean(config?.url || '')}" placeholder="https://xxxx.supabase.co" required/></div>
      <div class="inputGroup"><label>Clé publique (publishable)</label><input name="key" type="text" value="${clean(config?.key || '')}" required/></div>
      <div class="inputGroup"><label>E-mail du compte</label><input name="email" type="email" autocomplete="username" required/></div>
      <div class="inputGroup"><label>Mot de passe</label><input name="password" type="password" autocomplete="current-password" required/></div>
      <div class="formActions"><button type="submit" class="btn acid" data-mode="login">Se connecter</button>
        <button type="submit" class="btn ghost" data-mode="signup">Créer mon compte</button></div>
    </form>
    <div class="formActions" style="margin-top:10px"><button id="pacePull" class="btn ghost" type="button">Actualiser depuis Santé</button>
      <button id="paceDisconnect" class="btn ghost" type="button">Se déconnecter</button></div>
    <p id="paceCloudStatus" role="status">${session ? 'Une session est enregistrée sur cet appareil.' : 'Aucun compte connecté.'}</p>
    <p class="hint">Le jeton de connexion reste sur cet appareil. Ne te connecte pas sur un navigateur partagé.</p>`;
  }
  document.addEventListener('click', async e=>{
    if(e.target.closest('#pacePull')){
      try{const r=await pull();const el=$('paceCloudStatus');if(el)el.textContent=r?`${r.running} course(s) synchronisée(s), ${r.retrieved} activités disponibles.`:'Connecte-toi pour actualiser.';}catch(err){const el=$('paceCloudStatus');if(el)el.textContent=err.message;}
    }
    if(e.target.closest('#paceDisconnect')){session=null;localStorage.removeItem(SESSION_KEY);mount();}
  });
  let action='login';
  document.addEventListener('click',e=>{const b=e.target.closest('#paceCloudForm button[type=submit]');if(b)action=b.dataset.mode||'login';},true);
  document.addEventListener('submit',async e=>{
    if(e.target.id!=='paceCloudForm')return;
    e.preventDefault();const el=$('paceCloudStatus');const d=Object.fromEntries(new FormData(e.target));
    try{
      config={url:goodURL(d.url),key:String(d.key).trim()}; localStorage.setItem(CONFIG_KEY,JSON.stringify(config));
      if(el)el.textContent='Connexion en cours…';
      const msg=await signIn(d.email,d.password,action);
      if(el)el.textContent=msg;
      e.target.elements.password.value='';
    }catch(err){if(el)el.textContent='Impossible de synchroniser : '+err.message;}
  });
  window.PaceLabHealthCloud={mount,pull};
  if(session?.refresh_token && config?.key)pull().catch(()=>{});
  document.addEventListener('visibilitychange',()=>{if(!document.hidden && session?.refresh_token)pull().catch(()=>{});});
})();
