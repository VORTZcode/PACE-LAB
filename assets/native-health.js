// PACE LAB: native-only HealthKit bridge. This code never contacts a server.
(function () {
  const root = document.getElementById('view');
  function dateLocal(iso) {
    const d = new Date(iso);
    if (!Number.isFinite(d.valueOf())) return null;
    const y = d.getFullYear(),m=String(d.getMonth()+1).padStart(2,'0'),day=String(d.getDate()).padStart(2,'0');
    return `${y}-${m}-${day}`;
  }
  function ingest(items) {
    if (!Array.isArray(items)) return 0;
    let updates = 0;
    for (const x of items) {
      if (!x || x.activity_kind !== 'running' || typeof x.source_uuid !== 'string') continue;
      const date = dateLocal(x.started_at), minutes = Number(x.duration_seconds)/60,
        distance = Number(x.distance_meters)/1000;
      if (!date || !Number.isFinite(minutes) || !Number.isFinite(distance) || minutes <= 0 || distance <= 0 || distance > 150) continue;
      const next = {
        uuid: x.source_uuid, date, minutes, distance, pace: minutes/distance,
        hr: x.hr_average_bpm ?? null, maxHR: x.hr_max_bpm ?? null,
        origin: 'healthkit-local',
        recovery: {
          end: x.hr_at_end_bpm ?? null,
          one: x.recovery_hr_1min ?? null, two: x.recovery_hr_2min ?? null,
          three: x.recovery_hr_3min ?? null, five: x.recovery_hr_5min ?? null,
          status: x.recovery_state || 'partial'
        }
      };
      const idx = state.runs.findIndex(r => r.uuid === x.source_uuid && r.origin === 'healthkit-local');
      if (idx >= 0) state.runs[idx] = {...state.runs[idx], ...next};
      else state.runs.push(next);
      updates++;
    }
    if (updates) {persist(); render();}
    return updates;
  }
  function mount(){
    const slot=document.getElementById('cloudHealthBox');if(!slot)return;
    slot.innerHTML = !!window.__PACE_LAB_NATIVE
      ? '<h4>Apple Santé intégré</h4><p>Les courses HealthKit sont récupérées en local, sans compte ni serveur. Les mesures de récupération restent absentes si Apple Watch ne les enregistre pas.</p>'
      : '<h4>Apple Santé</h4><p>La lecture automatique d’Apple Santé nécessite la version iOS native de PACE LAB. Le site web ne peut pas accéder à HealthKit. Tu peux toujours importer tes données en JSON.</p>';
  }
  window.PaceNativeHealth={ingest,mount};
})();
