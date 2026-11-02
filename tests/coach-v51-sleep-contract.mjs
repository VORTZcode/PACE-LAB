import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const swift=f=>readFileSync('ios/PaceLabCompanion/'+f+'.swift','utf8');
const bridge=swift('PaceSleepHealthKit');
const analysis=swift('PaceSleepRules');
const engine=swift('PaceCoachEngine');
const screen=swift('PaceCoachScreen');
const app=swift('PaceLabCompanionApp');
const home=swift('PaceLivingCoach');
const pbx=readFileSync('ios/PaceLabCompanion.xcodeproj/project.pbxproj','utf8');
const profile=swift('PaceAthleteProfile');
for(const s of ['.sleepAnalysis','requestAuthorization(toShare:[],read:[type])','HKSampleQuery',
                'monitoringEnabled','HKHealthStore.isHealthDataAvailable','self.summary=PaceSleepRules.summarize']) {
  assert.ok(bridge.includes(s),'missing permission or retrieval logic '+s);
}
for(const s of ['[1,3,4,5]','mergeDuration','bySource','coverage7','coverage14',
               'mostRecent7AverageMinutes','previous7AverageMinutes','promptContext']) {
  assert.ok(analysis.includes(s),'missing validated aggregation logic '+s);
}
assert.ok(!analysis.includes('readinessScore'));
assert.ok(engine.includes('pace.coach.share-sleep'));
assert.ok(engine.includes('if shareSleep {'));
assert.ok(engine.includes('sleep.summary.promptContext'));
assert.ok(engine.includes('notes:sharedNotes'));
assert.ok(engine.includes('sleep:PaceSleepHealthKit? = nil'));
assert.ok(engine.includes('sleep:sleep)'));
assert.ok(engine.includes('training a 7 entrées, meals en a exactement 14'));
assert.ok(engine.includes('Si les données de sommeil sont partagées'));
assert.ok(screen.includes('Toggle(isOn:$coach.shareSleep)'));
assert.ok(screen.includes('.disabled(!sleep.monitoringEnabled)'));
assert.ok(screen.includes('sleep.requestAccess()'));
assert.ok(screen.includes('sleepSnapshot'));
assert.ok(screen.includes('sleep:sleep)'));
assert.ok(home.includes('Sommeil observé'));
assert.ok(app.includes('.environmentObject(sleep)'));
assert.ok(app.includes('sleep.refresh()'));
assert.ok(profile.includes('preferredRunsPerWeek: 3'));
assert.ok(profile.includes('preferredStrengthPerWeek: 2'));
for(const name of ['PaceSleepHealthKit.swift','PaceSleepRules.swift']) assert.ok(pbx.includes(name+' in Sources'));
console.log('V5.1: HealthKit sleep opt-in, quality-aware 14-day aggregates, separate OpenAI sharing, 7 training days + 14 meals.');
