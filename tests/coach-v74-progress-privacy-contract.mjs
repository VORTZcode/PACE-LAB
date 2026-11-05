import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const read = name => readFileSync('ios/PaceLabCompanion/' + name + '.swift','utf8');
const app = read('PaceLabCompanionApp');
const models = read('PaceModels');
const nutrition = read('PaceViewsNutrition');
const coach = read('PaceCoachEngine');
const coachUI = read('PaceCoachScreen');
const activity = read('PaceViewsActivities');
const programme = read('PaceViewsProgramme');
const progress = read('PaceViewsProgress');
const evidence = read('PaceProgressEvidence');
const health = read('PaceHealthSignals');
const settings = read('PaceViewsSettings');
const training = read('PaceTrainingAdherence');
const runLinks = read('PaceRunWorkoutLinks');
const pbx = readFileSync('ios/PaceLabCompanion.xcodeproj/project.pbxproj','utf8');

// AI must never receive private HealthKit trends solely from granting iOS access.
assert.match(health,/healthStore\.requestAuthorization\(toShare: \[\], read: types\)/);
assert.match(health,/guard accessRequested, !isLoading/);
assert.match(health,/Ne pas en déduire à elle seule un état de santé/);
assert.match(coach,/shareHealthTrends && PaceHealthSignals\.shared\.accessRequested/);
assert.match(coach,/PaceHealthSignals\.shared\.consentedCoachContext/);
assert.match(coachUI,/shareHealthTrends/);
assert.match(settings,/Mesures cardiovasculaires et corporelles/);
assert.match(app,/environmentObject\(healthSignals\)/);

// No date-only "completed" inference and no arbitrary choice between two runs.
assert.match(training,/case confirmedWorkout, manuallyCompleted, missed, candidate, ambiguous/);
assert.match(training,/if candidates\.count > 1/);
assert.match(runLinks,/func confirm\(date: String, workout: WorkoutPayload\)/);
assert.match(programme,/runLinks\.confirm\(date: day\.date, workout: found\)/);
assert.match(programme,/PaceTrainingAdherenceAdapter\.snapshot/);
assert.match(app,/environmentObject\(runLinks\)/);
assert.match(coach,/PaceTrainingAdherenceAdapter\.snapshot/);

// Self-reported meals are stored by precise day/meal/recipe and not treated as kcal measurements.
assert.match(models,/struct PaceMealDeclaration: Codable/);
assert.match(models,/date \+ "\|" \+ recipe\.meal \+ "\|" \+ recipe\.name/);
assert.match(models,/pace-dated-meal-declarations\.json/);
assert.match(nutrition,/toggleMealDeclaration\(recipe, on: planDate\)/);
assert.ok(!nutrition.includes('toggleMeal(recipe.id)'));
assert.match(coach,/ne jamais les présenter comme des apports réellement consommés/i);

// Measured strength evidence and honest performance milestones.
assert.match(progress,/PaceStrengthProgressSection\(\)/);
assert.match(progress,/Repères par distance/);
assert.match(evidence,/\[3, 5, 10\]\.compactMap/);
assert.match(evidence,/abs\(\$0\.km - Double\(target\)\) \/ Double\(target\) <= 0\.03/);
assert.match(evidence,/not a split|Not a split/i);

// Session cards are fully tappable and distinguish report success from failed analysis.
assert.match(activity,/Button\(action: onRead\)/);
assert.match(activity,/reviewState\(for: workout\.source_uuid/);
assert.match(coach,/enum PaceSessionReviewState/);
assert.match(coach,/case \.verified: return "Bilan ChatGPT confirmé"/);

for (const file of [
  'PaceHealthSignals', 'PaceTrainingAdherence', 'PaceTrainingAdherenceAdapter',
  'PaceRunWorkoutLinks', 'PaceStrengthEvidence', 'PaceStrengthProgressSection'
]) {
    assert.ok(pbx.includes(file + '.swift in Sources'), 'Missing Xcode source: ' + file);
}
console.log('PASS: V7 HealthKit consent, training provenance, dated meal diary, strength, milestones, honest analysis states.');
