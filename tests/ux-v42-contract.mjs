import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=f=>readFileSync('ios/PaceLabCompanion/'+f,'utf8');
const running=read('PaceGuidedWorkout.swift'), figures=read('PaceExerciseGuide.swift');
for(const text of ['135–150','bpm','8’35–9’15','min/km','test','RPE','parler en phrases complètes']) {
 assert.ok(running.toLowerCase().includes(text.toLowerCase()),'Missing running reference '+text);
}
assert.ok(running.includes('estimati'),'Heart/pace must say not measured thresholds');
assert.ok(running.includes('Si la FC dépasse durablement'));
for(const text of ['Movement_','supported.contains(figure)','poseButton("01 · Départ"','poseButton("02 · Arrivée"','PaceExerciseCoaching','guide.steps']) {
 assert.ok(figures.includes(text),'Missing upgraded guide '+text);
}
assert.ok(figures.includes('Le mouvement, étape par étape'));
assert.ok(figures.includes('guide.errors'));
console.log('V4.2: conversational pacing, indicative HR and pace, visual muscles and exercise guides present.');
