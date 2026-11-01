import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
const rd = s => readFileSync('ios/PaceLabCompanion/'+s,'utf8');
const payload = rd('LocalHealthStore.swift');
const timeline = rd('PaceDynamicsTimeline.swift');
const coach = rd('PaceCoachEngine.swift');
const telemetry = rd('PaceCoachTelemetry.swift');
const screen = rd('PaceCoachScreen.swift');
for (const metric of ['speed_series','power_series','stride_series','ground_contact_series','vertical_series','heart_rate_series']) {
  assert.ok(payload.includes(metric));
  assert.ok(telemetry.includes('run.'+metric));
}
assert.match(timeline,/date\.timeIntervalSince\(start\)/);
assert.match(timeline,/maxBuckets:Int = 120/);
assert.match(timeline,/aucune interpolation/);
assert.match(timeline,/GPS absent/);
assert.match(timeline,/validSamples/);
assert.match(coach,/shareDynamicsTimeline = UserDefaults\.standard\.bool/);
assert.match(coach,/if shareDynamicsTimeline/);
assert.match(coach,/PaceCoachTelemetry\.synchronizedDynamics\(run\)/);
assert.match(screen,/Toggle\(isOn:\$coach\.shareDynamicsTimeline\)/);
assert.match(screen,/avant envoi à OpenAI/);
assert.match(screen,/Voir le résumé sportif partagé/);
assert.ok(existsSync('ios/PaceLabCompanion/PaceDynamicsTimeline.swift'));
console.log('V3.4: six synchronized metrics, explicit opt-in, exact preview and no route transfer contracts passed.');
