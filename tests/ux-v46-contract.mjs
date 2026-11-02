import assert from 'node:assert/strict';
import {readFileSync, existsSync, statSync} from 'node:fs';
const swift = name => readFileSync('ios/PaceLabCompanion/' + name,'utf8');
const guide=swift('PaceExerciseGuide.swift');
const screen=swift('PaceViewsProgramme.swift');
const original=readFileSync('scripts/make_original_exercise_art.py','utf8');
const premium=readFileSync('scripts/make_premium_exercise_art.py','utf8');
const figures=['squat','chair','row','press','bridge','sideplank','plank','calf','split','overhead','hinge','incline','deadbug','carry'];
assert.ok(original.includes('dumbbell=(445,313)'), 'Goblet squat needs dumbbell in initial position');
assert.ok(premium.includes('TARGETS={'));
assert.ok(premium.includes('linearGradient id="skin"'));
assert.ok(premium.includes('def silhouette('));
assert.ok(guide.includes('GeometryReader { geometry in'));
assert.ok(guide.includes('Image("Movement_\\(figure)_\\(selectedPose)")'));
assert.ok(guide.includes('poseButton("01 · Départ"'));
assert.ok(guide.includes('poseButton("02 · Arrivée"'));
assert.ok(guide.includes('.sheet(isPresented: $showingEnlargedPose)'));
assert.ok(guide.includes('Agrandir la position initiale'));
assert.ok(screen.includes('PaceExerciseVisual(figure: guide.figure, imageHeight: artworkHeight - 45)'));
assert.ok(screen.includes('.id(ex.id)'), 'Exercise switches must reset the pose choice');
for(const figure of figures){
  for(const suffix of ['Start','End']) {
    const name='Movement_'+figure+'_'+suffix;
    const dir='ios/PaceLabCompanion/Assets.xcassets/'+name+'.imageset/';
    assert.ok(existsSync(dir+'pose.jpg'),name);
    assert.ok(statSync(dir+'pose.jpg').size>14000,'Image too small: '+name);
    const svg=readFileSync('assets/exercise-vectors/'+name+'.svg','utf8');
    for(const marker of ['url(#bg)','MUSCLES &amp; OBJECTIF','POSITION','linearGradient id="skin"']){
      assert.ok(svg.includes(marker),'Missing studio token '+marker+' for '+name);
    }
  }
}
console.log('V4.6: 28 studio artworks and fullwidth position switch verified.');
