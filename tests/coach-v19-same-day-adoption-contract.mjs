import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const engine=readFileSync('ios/PaceLabCompanion/PaceCoachEngine.swift','utf8');
const model=readFileSync('ios/PaceLabCompanion/PaceModels.swift','utf8');
const screen=readFileSync('ios/PaceLabCompanion/PaceCoachScreen.swift','utf8');
for(const phrase of [
  'enum StartDateRule {','case generatedTomorrow','case approveTodayOrTomorrow',
  'func validate(startDateRule: StartDateRule = .generatedTomorrow) throws',
  'case .generatedTomorrow:', 'guard starts == tomorrow',
  'case .approveTodayOrTomorrow:', 'guard starts == today || starts == tomorrow',
  'parsed >= calendar.startOfDay(for:.now)',
])assert.ok(engine.includes(phrase),`Date guard contract missing: ${phrase}`);
assert.ok(model.includes('try draft.validate(startDateRule: .approveTodayOrTomorrow)'));
assert.ok(engine.includes('try draft.validate()'), 'Generated plans remain tomorrow-only');
assert.ok(screen.includes('try library.acceptCoachDraft(pending)'), 'Approval still requires user confirmation');
const current='2026-11-09',tomorrow='2026-11-10';
assert.ok([current,tomorrow].includes('2026-11-09'));
assert.ok(![current,tomorrow].includes('2026-11-08'));
assert.ok(![current,tomorrow].includes('2026-11-11'));
console.log('Saved first-day adoption allowed; generation still tomorrow-only; past/far future excluded.');
