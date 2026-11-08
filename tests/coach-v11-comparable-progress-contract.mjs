import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const coach=readFileSync('ios/PaceLabCompanion/PaceCoachEngine.swift','utf8');
const screen=readFileSync('ios/PaceLabCompanion/PaceCoachScreen.swift','utf8');
for(const token of ['enum PaceProgressComparator','struct PaceComparableRunResult','run.kilometers >= 2','run.duration_seconds.isFinite','(0...3).contains(pain)','days >= 7 && days <= 42','<= 0.10','<= 1','paceRelativeChange','Ceci n\'est pas','Ne pas annoncer un gain physiologique démontré']) {
  assert.ok(coach.toLowerCase().includes(token.toLowerCase()) || token==="Ceci n'est pas" && coach.includes("ceci n'est pas"),`Missing ${token}`)
}
assert.ok(screen.includes('Comparaison de deux courses similaires'));
assert.ok(screen.includes('comparaison insuffisante'));
assert.ok(coach.includes('notes:sharedNotes'));
console.log('V11 evidence-only comparable-run contract passed.');
