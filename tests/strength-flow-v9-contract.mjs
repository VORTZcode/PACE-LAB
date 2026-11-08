import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const source = readFileSync('ios/PaceLabCompanion/PaceViewsProgramme.swift', 'utf8');
const body = source.split('private struct PaceStrengthFlowScreen: View {')[1]?.split('/// Records an absence honestly;')[0];
assert.ok(body, 'Dedicated strength flow screen must exist');
for (const token of ['Série \\(activeSet) sur \\(numberOfSets)', 'Valider la série',
  'Récupération', 'advanceAfterRest()', 'chooseFirstUnfinished()', 'loadSet(activeSet)',
  'setRepetitions(reps', 'setWeight(kilograms', 'setCompleted(true',
  'if current.completed', 'if activeSet < numberOfSets', 'Button("Passer")',
  'pausedSeconds', 'Button("Revoir les séries")']) {
  assert.ok(body.includes(token), `Missing flow feature: ${token}`);
}
assert.ok(!body.includes('PaceStrengthSetRow'), 'Legacy dense set rows should not appear in new flow');
assert.match(source, /PaceStrengthFlowScreen\(/);
console.log('PACE-LAB V9 strength flow source contracts passed.');
