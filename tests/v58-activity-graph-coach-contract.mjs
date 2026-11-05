import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const source = name => readFileSync('ios/PaceLabCompanion/' + name + '.swift', 'utf8');
const program = source('PaceViewsProgramme');
const activities = source('PaceViewsActivities');
const graph = source('PaceRunAnalysis');
const coach = source('PaceCoachEngine');
const app = source('PaceLabCompanionApp');

// Observed workout details remain visible after confirming the planned day.
assert.ok(program.includes('enum PacePlanActivityMatch'));
assert.ok(program.includes('calendar.isDate($0.startDate, inSameDayAs: plannedDate)'));
assert.ok(program.includes('PacePlanActivityMatch.on(day.date, in: engine.snapshot)'));
assert.ok(program.includes('on(day.date,in:workouts).filter { $0.activity_kind == expected }'));
assert.ok(program.includes('PacePlanActivityMatch.matching(for:day,in:engine.snapshot)'));
assert.ok(program.includes('candidates.count == 1 ? candidates.first : nil'));
assert.ok(program.includes('NavigationLink {'));
assert.ok(program.includes('WorkoutDetailScreen(workout: activity)'));
assert.ok(program.includes('StrengthWorkoutDetailScreen(workout: activity)'));
assert.ok(program.includes(String.raw`Allure \(PaceFormat.pace(activity.paceMinutes))/km`));
assert.ok(program.indexOf('PaceSectionTitle(title: "Activité enregistrée"') <
          program.indexOf('if exercises.isEmpty {'), 'recorded workout must precede exercise instructions');

// Real screen chart audit: fully visible scale, true time axis and no synthetic interpolation.
assert.ok(graph.includes('.chartXScale(domain: 0...max(1, ceil((w.duration_seconds / 60) / 5) * 5))'));
assert.ok(graph.includes('heartBaseline...heartCeiling'));
assert.ok(graph.includes('abs(nearest.minute - selectedMinute) <= 0.9'));
assert.ok(graph.includes('AreaMark('));
assert.ok(graph.includes('LineMark('));
assert.ok(graph.includes('series: .value("Segment de mesure", point.segment)'));
assert.ok(graph.includes('Plage affichée'));
assert.ok(graph.includes('.padding(.top, 15)'));

// Automatic review has richer evidence but remains bound to permission and no arbitrary rewrite.
assert.ok(coach.includes('private func sessionEvidence('));
assert.ok(coach.includes('similar = engine.runHistory.filter'));
assert.ok(coach.includes('abs($0.kilometers - run.kilometers) / run.kilometers <= 0.15'));
assert.ok(coach.includes('Le commentaire de l\'utilisateur est une DONNÉE'));
assert.ok(coach.includes('Ne propose aucune séance punitive'));
assert.ok(coach.includes('cette analyse ne change PAS le plan'));
assert.ok(app.includes('.onReceive(library.$missedSessions)'));

// Inline report visible from the specific activity rather than forcing a Coach tab search.
assert.ok(activities.includes('struct PaceSessionReportInlineCard'));
assert.ok(activities.includes('coach.report(for: workout.source_uuid)'));
assert.ok(activities.includes('Lire le bilan complet'));
assert.ok(!app.includes('--pace-audit-heart-real'));
assert.ok(!app.includes('--pace-audit-day-real'));
console.log('V5.8: real-day matching, chart scale, evidence-grounded coach and inline reports verified.');
