import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const file = p => readFileSync('ios/PaceLabCompanion/'+p,'utf8');
const coach = file('PaceCoachEngine.swift');
const report = file('PaceCoachReport.swift');
const telemetry = file('PaceCoachTelemetry.swift');
const screen = file('PaceCoachScreen.swift');
const app = file('PaceLabCompanionApp.swift');
const auth = file('PaceChatGPTConnection.swift');
const activity = file('PaceViewsActivities.swift');
for (const property of ['shareHeartProfile','shareDynamics','shareSessionNotes']) {
  assert.ok(coach.includes(property), 'Missing consent '+property);
  assert.ok(screen.includes(property), 'Missing UI consent '+property);
}
for (const name of ['recentTrends','detailedMetrics','heartMinuteProfile','noteContext']) {
  assert.ok(telemetry.includes(name), 'Missing context builder '+name);
}
assert.match(telemetry,/limit:Int = 120/);
assert.match(telemetry,/sans mesures GPS/);
assert.match(telemetry,/commentaire: /);
assert.match(coach,/else if shareHeartProfile \{/);
assert.match(coach,/if shareDynamics \{ pieces\.append\(PaceCoachTelemetry\.detailedMetrics\(run\)\) \}/);
assert.match(coach,/if shareSessionNotes,let journal \{/);
assert.match(coach,/report = try PaceCoachSessionReport\.extract\(response,workoutID:run\.source_uuid\)/);
assert.match(coach,/reportURL/);
assert.match(coach,/\(autoReview \|\| autonomousMode\) && shareRunSummaries && newWorkoutAwaitingReview/);
assert.match(app,/coach\.analyzeSession/);
assert.doesNotMatch(app,/coach\.generate\(client:chatGPT/);
assert.match(screen,/Analyser cette sortie/);
assert.match(screen,/Ce qu’on ne peut pas conclure/);
assert.match(screen,/Séance sélectionnée/);
assert.match(screen,/Voir le résumé sportif partagé/);
assert.match(screen,/analysées par OpenAI/);
assert.match(report,/let uncertainties:\[String\]/);
assert.match(report,/uncertainties\.count/);
assert.match(auth,/UserDefaults\.standard\.string\(forKey:"pace\.coach\.model"\)/);
assert.match(auth,/gpt-6\.1-sol/);
assert.match(auth,/store":false,"stream":true/);
assert.match(activity,/coach\.focusWorkoutID = workout\.source_uuid/);
console.log('Coach V3.1 privacy + detailed telemetry + report + local history + chosen model contracts passed.');
