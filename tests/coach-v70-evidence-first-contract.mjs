import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const read = name => readFileSync('ios/PaceLabCompanion/' + name + '.swift','utf8');
const evidence = read('PaceProgressEvidence');
const progress = read('PaceViewsProgress');
const activities = read('PaceViewsActivities');
const coach = read('PaceCoachEngine');
const coachUI = read('PaceCoachScreen');
const project = readFileSync('ios/PaceLabCompanion.xcodeproj/project.pbxproj','utf8');

// Measurement logic must not rely on an LLM-generated conclusion or external service.
assert.match(evidence,/enum PaceProgressEvidence/);
assert.match(evidence,/validRuns\(_ workouts: \[WorkoutPayload\]/);
assert.match(evidence,/unique\[workout.source_uuid\]/);
assert.match(evidence,/date <= now/);
assert.match(evidence,/pace = workout.duration_seconds \/ km/);
assert.match(evidence,/\.day, value: -28/);
assert.match(evidence,/\.day, value: -56/);
assert.match(evidence,/distanceRatio <= 0.10/);
assert.match(evidence,/elapsed >= 7 \* 86400/);
assert.match(evidence,/abs\(\$0\) <= 8/);
assert.match(evidence,/Ces deux volumes décrivent une charge enregistrée/);
assert.ok(!evidence.includes('client.answer('));
assert.ok(!evidence.includes('requestAuthorization('));

// UX: the latest outdoor session has a single real HealthKit route read.
// No background GPS load is launched for every cell in the history.
assert.match(activities,/private var featuredRun: WorkoutPayload\?/);
assert.match(activities,/PaceFeaturedRunCard\(workout: featuredRun\)/);
assert.match(activities,/ForEach\(Array\(remaining.prefix\(shown\)\)\)/);
assert.match(activities,/private struct PaceFeaturedRunCard: View/);
assert.match(activities,/@StateObject private var route = PaceWorkoutRouteReader\(\)/);
assert.match(activities,/await route.load\(workoutID: workout.source_uuid\)/);
assert.match(activities,/PaceRouteMap\(track: track\)/);
assert.match(activities,/\.allowsHitTesting\(false\)/);
assert.match(activities,/private var remaining: \[WorkoutPayload\]/);

// UX: progress is framed as evidence, with missing-data state and athlete goal.
assert.match(progress,/PaceProgressEvidence\.snapshot\(engine.runHistory\)/);
assert.match(progress,/PaceProgressEvidencePanel\(snapshot: evidence/);
assert.match(progress,/athleteProfile.profile\?\.runningGoal/);
assert.match(progress,/Pas encore assez de séances/);
assert.match(progress,/Pas encore de course suffisamment comparable/);
assert.match(progress,/Il s'agit du volume réalisé, pas d'une mesure directe de forme/);

// Coach: calculations flow through existing user opt-in, with explicit status.
assert.match(coach,/if shareRunSummaries \{/);
assert.match(coach,/PaceProgressEvidence\.snapshot\(engine.runHistory\)\.coachEvidenceContext/);
assert.match(coachUI,/Dernier bilan local · analyse ChatGPT non aboutie/);
assert.match(coachUI,/Dernier bilan ChatGPT confirmé/);
assert.match(coachUI,/État technique et données/);
assert.match(coachUI,/iOS ne garantit pas leur achèvement en arrière-plan/);

// Xcode must link new model before an actual iOS compilation.
assert.match(project,/PaceProgressEvidence.swift in Sources/);
console.log('V7 static contracts: evidence validity, real-route hero, unbiased progress UX, consent-gated Coach, honest status.');
