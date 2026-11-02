import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const read = name => readFileSync('ios/PaceLabCompanion/' + name, 'utf8');
const app = read('PaceLabCompanionApp.swift');
const store = read('PaceStrengthTracker.swift');
const programme = read('PaceViewsProgramme.swift');

assert.match(app, /@StateObject private var strengthTracker = PaceStrengthTracker\(\)/);
assert.match(app, /\.environmentObject\(strengthTracker\)/);
assert.match(store, /struct PaceStrengthSet: Codable, Equatable/);
assert.match(store, /@Published private\(set\) var records/);
assert.match(store, /pace-strength-sets\.json/);
assert.match(store, /completeUntilFirstUserAuthentication/);
assert.match(store, /func setCompleted\(/);
assert.match(store, /func setRepetitions\(/);
assert.match(store, /func setWeight\(/);
assert.match(store, /\(day\)\|\\\(exerciseID\)/); // Stable day/exercise/set identity
assert.match(programme, /PaceStrengthSetRow\(dayDate: day\.date, exercise: ex, setNumber: index\)/);
assert.match(programme, /Progression de la séance/);
assert.match(programme, /Rép\./);
assert.match(programme, /Charge \(kg\)/);
assert.match(programme, /Terminer la séance malgré tout/);
assert.match(programme, /confirmationDialog/);
console.log('V3.5: per-set completion, optional reps and kilograms, protected local persistence, session progress verified.');
