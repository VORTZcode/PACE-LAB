import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(path, 'utf8');
const sql=read('supabase/schema/healthkit.sql');
const swift=read('ios/PaceLabCompanion/HealthSyncEngine.swift');
const transport=read('ios/PaceLabCompanion/SyncTransport.swift');
const ui=read('assets/cloud-sync.js');
assert(sql.includes('enable row level security'), 'RLS obligatoire');
assert(sql.includes('(select auth.uid()) = user_id'), 'Restriction propriétaire obligatoire');
assert(sql.includes('primary key (user_id, source_uuid)'), 'Déduplication par HealthKit UUID');
assert(!sql.includes('to anon\n  using (true)'), 'Accès anonyme interdit');
for (const k of ['recovery_hr_1min','recovery_hr_2min','recovery_hr_3min','recovery_hr_5min','recovery_state','heart_rate_series']) {
  assert(sql.includes(k), `Colonne ${k} absente`);
  assert(transport.includes(k), `Payload ${k} absent`);
}
assert(swift.includes('HKObserverQuery') && swift.includes('enableBackgroundDelivery'), 'Observation HealthKit absente');
assert(swift.includes('BGAppRefreshTaskRequest') && swift.includes('300'), 'Relance différée absente');
assert(swift.includes('nearest')===false || swift.includes('nearbyBPM'),'Politique échantillons');
assert(ui.includes('activity_kind') && ui.includes('source_uuid'), 'Lecture cloud non idempotente');
assert(!ui.includes('service_role'), 'Service role interdit dans la PWA');
console.log('Contrat HealthKit : permissions, RLS, séries cardiaques et déduplication validés');
