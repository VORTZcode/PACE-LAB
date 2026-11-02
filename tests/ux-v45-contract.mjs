import assert from 'node:assert/strict';
import {readFileSync, existsSync, statSync} from 'node:fs';
const swift = name => readFileSync('ios/PaceLabCompanion/' + name, 'utf8');
const guide = swift('PaceExerciseGuide.swift');
const brief = swift('PaceLivingCoach.swift');
const app = swift('PaceLabCompanionApp.swift');
const coach = swift('PaceCoachEngine.swift');
const tracker = swift('PaceStrengthTracker.swift');
const home = swift('PaceViewsCore.swift');

for(const figure of ['squat','chair','row','press','bridge','sideplank','plank','calf',
                     'split','overhead','hinge','incline','deadbug','carry']) {
  for(const suffix of ['Start','End']) {
    const folder = `ios/PaceLabCompanion/Assets.xcassets/Movement_${figure}_${suffix}.imageset/`;
    assert.ok(existsSync(folder + 'pose.jpg'), `Missing ${figure}/${suffix}`);
    assert.ok(statSync(folder + 'pose.jpg').size > 10000, `Tiny ${figure}/${suffix}`);
    assert.ok(!existsSync(folder + 'illustration.svg'), 'SVG sources must not create Xcode asset warnings');
    assert.ok(existsSync(`assets/exercise-vectors/Movement_${figure}_${suffix}.svg`));
  }
}
assert.ok(guide.includes('.sheet(isPresented: $showingEnlargedPose)'));
assert.ok(guide.includes('.accessibilityLabel("Agrandir :'));
for(const token of ['7 * 86400','28 * 86400','previousTwentyOne.count >= 3',
                    'RPE et gêne sont auto-déclarés','pain >= 4','effort! >= 8',
                    'completedStrengthSets','@Published private(set) var brief']) {
  assert.ok(brief.includes(token), 'Missing living coach safeguard: ' + token);
}
assert.ok(home.includes('PaceLivingCoachCard { showCoach = true }'));
assert.ok(app.includes('.environmentObject(living)'));
assert.ok(app.includes('.onReceive(engine.$revision)'));
assert.ok(app.includes('.onReceive(strengthTracker.$records)'));
assert.ok(app.includes('.onReceive(journal.$notes)'));
assert.ok(tracker.includes('func completedSets(since date: Date'));
assert.ok(coach.includes('let sharedNotes = shareSessionNotes ?'));
assert.ok(coach.includes('PaceLivingCoachRules.calculate(runs:engine.runHistory,notes:sharedNotes)'));
assert.ok(coach.includes('automaticInFlightID'));
assert.ok(coach.includes('lastAutomaticAttempt'));
assert.ok(coach.includes('if automaticInFlightID == run.source_uuid'));
assert.ok(!coach.includes('autoRequestedID = uuid\n        UserDefaults.standard.set(uuid'), 'Do not mark a failed review successful');
console.log('V4.5: 28 original offline illustrations with zoom, local living brief, training+RPE+strength evidence, user consent and retryable AI.');
