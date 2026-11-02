import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const source=x=>readFileSync('ios/PaceLabCompanion/'+x,'utf8');
const plan=JSON.parse(source('AppData/pace-programme.json'));
const workout=source('PaceViewsProgramme.swift');
const guided=source('PaceGuidedWorkout.swift');
const guides=source('PaceExerciseGuide.swift');
assert.equal(plan.force.length,18);
assert.equal(plan.plan.length,7);
assert.ok(guided.includes('RPE signifie perception de l’effort'));
assert.ok(guided.includes('parler en phrases complètes'));
assert.ok(guided.includes('4 min de course et 1 min de marche'));
assert.ok(guided.includes('RIR 2–3'));
assert.ok(guided.includes('RPE 6–7'));
assert.ok(workout.includes('PaceEffortGuide(day: day)'));
assert.ok(workout.includes('PaceExerciseVisual(figure: guide.figure'));
assert.ok(workout.includes('PaceStrengthSetRow('));
assert.ok(workout.includes('strengthTracker.completedSets'));
for(const part of ['goblet squat','squat à la chaise','rowing','développé couché','pont fessier','planche latérale','planche avant','mollets','split squat','développé épaules','soulevé de terre roumain','pompes inclinées','dead bug','marche du fermier']) {
 assert.ok(guides.includes(part),'No movement guide: '+part);
}
assert.ok(guides.includes('Image("Movement_\\(figure)_\\(suffix)"') || guides.includes('Image("Movement_'));
assert.ok(guides.includes('Le mouvement, étape par étape'));
assert.ok(guides.includes('Erreurs') || guides.includes('guide.errors'));
assert.ok(workout.includes('exercise.isTimed'));
console.log('Guided v4.1 checks: complete plan, 14 movement variants, RPE/RIR, physical cues, pose visuals, existing set tracker.');
