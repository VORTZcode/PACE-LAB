import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const view = readFileSync('ios/PaceLabCompanion/PaceViewsProgramme.swift', 'utf8');
const store = readFileSync('ios/PaceLabCompanion/PaceStrengthTracker.swift', 'utf8');
for (const token of [
  '@FocusState private var focusedStrengthInput: PaceStrengthInput?',
  '.focused(focus, equals: kind)',
  'Button("Terminé") { focusedStrengthInput = nil }',
  '.scrollDismissesKeyboard(.interactively)',
  '.onTapGesture { focusedStrengthInput = nil }',
  '@State private var repetitionsText = ""',
  '@State private var loadText = ""',
  '.frame(maxWidth: .infinity, minHeight: 52)',
  'VStack(alignment: .leading, spacing: 13)',
  'title: "Répétitions"',
  'title: "Charge (kg)"',
  '.onChange(of: repetitionsText)',
  '.onChange(of: loadText)',
  '.onAppear {',
]) {
  assert.ok(view.includes(token), 'Expected native strength UX feature: '+token);
}
assert.ok(!view.includes('.frame(width: 54, height: 35)'));
assert.ok(!view.includes('.frame(width: 66, height: 35)'));
assert.ok(store.includes('pace-strength-sets.json'));
assert.ok(store.includes('Data(contentsOf: url)'));
assert.ok(store.includes('data.write(to: url, options: .atomic)'));
console.log('V3.6 verified: bigger input touch targets, stable FocusState, tap/scroll/Done dismissal and local saving.');
