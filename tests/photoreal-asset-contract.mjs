import assert from 'node:assert/strict';
import {readFileSync,statSync} from 'node:fs';
const manifest=JSON.parse(readFileSync('assets/photo-sources.json','utf8'));
const generated=['squat','chair','row','press','bridge','sideplank','calf','hinge','carry'];
const licensed=['plank','split','overhead','incline','deadbug'];
for(const name of [...generated,...licensed]) {
  const m=manifest[name];
  assert.ok(m,'missing source: '+name);
  if(name==='hinge') assert.equal(m.equipment_verified,false);
  else assert.equal(m.equipment_verified ?? true,true);
  for(const phase of ['Start','End']) {
    const path='ios/PaceLabCompanion/Assets.xcassets/Movement_'+name+'_'+phase+'.imageset/pose.jpg';
    assert.ok(statSync(path).size>(['calf','hinge','carry'].includes(name)?30000:45000), 'photo missing or tiny: '+name+' '+phase);
    const bytes=readFileSync(path);
    assert.equal(bytes[0],0xff);
    assert.equal(bytes[1],0xd8);
  }
}
for(const name of licensed) {
  assert.equal(manifest[name].license,'CC BY-SA 4.0');
  assert.ok(manifest[name].license_url);
}
assert.equal(manifest._pending,undefined);
assert.deepEqual(Object.keys(manifest._technicalReview).sort(),['calf','carry','hinge']);
const view=readFileSync('ios/PaceLabCompanion/PaceExerciseGuide.swift','utf8');
assert.ok(view.includes('Photos : Everkinetic · CC BY-SA 4.0'));
assert.ok(view.includes('Visuel généré par IA'));
assert.ok(view.includes('Visuel IA provisoire'));
console.log('V4.8 verified: 14 human photo pairs installed; provenance and three technical review warnings declared.');
