import assert from 'node:assert/strict';
import {readFileSync, existsSync, statSync} from 'node:fs';
const source = readFileSync('ios/PaceLabCompanion/PaceViewsProgramme.swift', 'utf8');
const guide = readFileSync('ios/PaceLabCompanion/PaceExerciseGuide.swift', 'utf8');
assert.ok(source.includes('.fullScreenCover(isPresented:'), 'Strength exercise must open as a full-screen workspace');
assert.ok(source.includes('private func navigateExercise('), 'Need next/previous exercise navigation');
assert.ok(source.includes('presentedExerciseID = exercises[index + direction].id'), 'Navigation must select the requested exercise');
assert.ok(source.includes('exerciseDetailTab = 0'), 'Exercise navigation resets the guidance tab');
assert.ok(source.includes('.id(ex.id + ":" + String(setNumber))'), 'Saved set inputs must not leak between exercises');
assert.ok(source.includes('.safeAreaInset(edge: .bottom'), 'Rest countdown must remain visible');
assert.ok(source.includes('restEnd = Date().addingTimeInterval('), 'Rest countdown should start when a set is validated');
assert.ok(source.includes('.accessibilityLabel("Exercice suivant")'), 'Next exercise should have an accessible label');
assert.ok(source.includes('.accessibilityLabel("Exercice précédent")'), 'Previous exercise should have an accessible label');
assert.ok(!source.includes('if false {'), 'Do not carry unreachable legacy exercise controls');
const figures = [...guide.matchAll(/figure:"([a-z]+)"/g)].map(match => match[1]);
const uniqueFigures = [...new Set(figures)].filter(name => name !== 'standing');
assert.equal(uniqueFigures.length, 14, 'Guide should map 14 distinct exercises');
for (const figure of uniqueFigures) {
  for (const pose of ['Start', 'End']) {
    const folder = `ios/PaceLabCompanion/Assets.xcassets/Movement_${figure}_${pose}.imageset`;
    assert.ok(existsSync(folder + '/pose.jpg'), `Missing ${figure} ${pose} image`);
    assert.ok(statSync(folder + '/pose.jpg').size > 1000, `Empty image for ${figure} ${pose}`);
    const metadata = JSON.parse(readFileSync(folder + '/Contents.json', 'utf8'));
    assert.ok(metadata.images.some(img => img.filename === 'pose.jpg'), `Unbound image asset ${figure} ${pose}`);
  }
}
console.log('V4.4 verified: 14 two-pose guides, full-screen exercise navigation, isolated set editing, pinned rest and removed dead UI.');
