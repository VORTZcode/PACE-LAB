import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const src = name => readFileSync('ios/PaceLabCompanion/' + name + '.swift', 'utf8');
const model = src('PaceModels');
const program = src('PaceViewsProgramme');
const engine = src('PaceCoachEngine');
const report = src('PaceCoachReport');
const app = src('PaceLabCompanionApp');
const chart = src('PaceRunAnalysis');
for (const value of ['PaceMissedSession', 'markDayMissed', 'clearMissed', 'missedCount', 'pace-missed-sessions.json', 'completed.remove(date)']) {
    assert.ok(model.includes(value), 'missing session state ' + value);
}
for (const value of ['Séance non réalisée', 'Je n’ai pas pu faire cette séance', 'Modifier le motif', 'Remettre en attente', 'PaceMissedSessionEditor']) {
    assert.ok(program.includes(value), 'missing missed-day UI ' + value);
}
assert.ok(engine.includes('sessionReports: [PaceCoachSessionReport]'));
assert.ok(engine.includes('pace-coach-reports.json'));
assert.ok(engine.includes('saveReport(.localFallback(for: run))'));
assert.ok(report.includes('origin == "local"'));
assert.ok(report.includes('Aucune adaptation automatique'));
assert.ok(engine.includes('report(for workoutID: String)'));
assert.ok(engine.includes('activity_kind == "strength" && shareStrengthSets'));
assert.ok(engine.includes('newWorkoutAwaitingReview = isRecent && isSettled && !alreadyReviewed'));
assert.ok(app.includes('launchAutomaticSessionReview()'));
assert.ok(chart.includes('AreaMark(') && chart.includes('Color.red.opacity'));
assert.ok(chart.includes('series: .value("Segment de mesure", point.segment)'));
console.log('PACE-LAB V5.7: missed sessions, local fallback, report history, automatic trigger and heart chart contracts passed.');
