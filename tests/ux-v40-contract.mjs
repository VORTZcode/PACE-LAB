import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read = f => readFileSync('ios/PaceLabCompanion/'+f,'utf8');
const home=read('PaceViewsCore.swift');
const plan=read('PaceViewsProgramme.swift');
const acts=read('PaceViewsActivities.swift');
const progress=read('PaceViewsProgress.swift');
for(const token of ['enum PaceDesign','struct PaceEyebrow','accessibilityAddTraits(.isHeader)','PaceDesign.sectionSpacing','PaceDesign.screenInset','trainingNavigationPath.append(day.date)','Ouvrir ma séance','Dernière activité','StrengthWorkoutDetailScreen(workout: latest)','7 derniers jours','Votre coach','PaceInsightScreen(kind: .month)']) {
 assert.ok(home.includes(token), 'Missing home / design: '+token);
}
assert.ok(home.indexOf('Ouvrir ma séance')<home.indexOf('Dernière activité'),'Hero should precede activity recap');
assert.ok(home.indexOf('Dernière activité')<home.indexOf('7 derniers jours'),'History before secondary metrics');
assert.ok(!home.includes('Dernière course'),'Old runner-only hero still visible');
for(const token of ['PaceEyebrow(title: "Votre parcours")','Les prochains jours','isCurrent','AUJ.','En cours · Séance guidée','Consignes de la séance','strengthTracker.completedSets','PaceStrengthSetRow']) assert.ok(plan.includes(token),token);
for(const token of ['Text("Muscu").tag(1)','Text("Tout").tag(3)','workout.activity_kind == "strength"']) assert.ok(acts.includes(token),token);
assert.ok(!progress.includes('Analyse en construction'));
console.log('PACE LAB V4.0 experience foundations: design tokens, action-first dashboard, today highlight, preserved muscle set flow and dedicated strength filter.');
