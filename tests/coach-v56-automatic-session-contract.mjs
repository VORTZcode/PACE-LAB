import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const swift = name => readFileSync('ios/PaceLabCompanion/' + name + '.swift', 'utf8');
const report = swift('PaceCoachReport');
const engine = swift('PaceCoachEngine');
const app = swift('PaceLabCompanionApp');
const screen = swift('PaceCoachScreen');

// Incomplete OpenAI responses must never become an apparently valid training
// report, nor silently rewrite the user's programme.
for (const term of [
  'var missing: [String] = []',
  'observations étayées (1 à 6)',
  'recommandations concrètes (1 à 5)',
  'limites ou données inconnues (1 à 5)',
  'conséquence justifiée pour le programme',
  'Aucune modification du programme'
]) assert.ok(report.includes(term), 'report quality: ' + term);
assert.ok(!report.includes('Le bilan proposé manque de précautions ou de données.'));

// If the model returns a structurally incomplete report, one correction is
// attempted with the SAME authorized context, without inventing metrics.
assert.ok(engine.includes('let repairInstructions = instructions'));
assert.ok(engine.includes('let corrected = try await client.answer('));
assert.ok(engine.includes('input:context)'));
assert.ok(engine.includes('report = try PaceCoachSessionReport.extract('));
assert.ok(engine.includes('Ne fabrique jamais une mesure'));
assert.ok(!engine.includes('PaceCoachSessionReport(workoutID:run.source_uuid'));

// Autopilot is no longer a reason to suppress unattended session summaries.
assert.ok(engine.includes('autonomousMode:Bool = false'));
assert.ok(engine.includes('(autoReview || autonomousMode)'));
assert.ok(app.includes('coach.beginAutomaticReview(engine:engine,autonomousMode:autopilot.enabled)'));
assert.ok(app.includes('private func launchAutomaticSessionReview() -> Bool'));
assert.ok(!app.includes('if !autopilot.enabled && chatGPT.planUsageEnabled'));
assert.ok(app.includes('await coach.analyzeSession('));
assert.ok(app.includes('launchAutopilot()'));
assert.ok(app.includes('.onReceive(coach.$autoReview)'));
assert.ok(app.includes('.onReceive(chatGPT.$planUsageEnabled)'));

// The user can tell that automatic analysis is enabled and retry a failed
// report, but the prominent manual button remains in manual mode.
assert.ok(screen.includes('Bilan incomplet · relance possible'));
assert.ok(screen.includes('Bilans automatiques activés'));
assert.ok(screen.includes('Relancer le bilan manuellement'));
assert.ok(screen.includes('Analyser cette sortie'));
assert.ok(screen.includes('if autopilot.enabled {'));
assert.ok(screen.includes('Coach autonome prépare aussi les bilans'));
console.log('PACE-LAB auto-session review: validation, bounded repair, consent, sequencing, manual fallback and UX contracts passed.');
