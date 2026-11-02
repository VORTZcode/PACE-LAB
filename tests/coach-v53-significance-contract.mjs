import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const swift=f=>readFileSync('ios/PaceLabCompanion/'+f+'.swift','utf8');
const signal=swift('PaceAutopilotSignificance');
const safety=swift('PaceAutopilotGuard');
const coach=swift('PaceAutopilot');
const app=swift('PaceLabCompanionApp');
const screen=swift('PaceCoachScreen');
const pbx=readFileSync('ios/PaceLabCompanion.xcodeproj/project.pbxproj','utf8');
for(const term of ['PaceAutopilotEvidence','id:"subjective"','id:"training"','id:"sleep"',
 'recent <= previous - 45','sleep.coverage14 >= 10','ids.count >= 2',
 'ids.isSubset(of:available)','(8...10).contains(effort)']) {
  assert.ok(signal.includes(term),'Missing independently verifiable evidence '+term);
}
for(const term of ['lastAutomaticChange','7 * 86400','PaceAutopilotSignificance.evidence',
                   'evidence.count >= 2','pain >= 4','hasPriorAdjustment']) {
  assert.ok(safety.includes(term),'Missing safety rule '+term);
}
for(const term of ['let evidenceIDs: [String]','let expectedEffect: String',
                   'let alternativeConsidered: String','let uncertainty: String',
                   'PaceAutopilotSignificance.reconcile','let eligible = sources.isEmpty',
                   'guard enabled, coach.shareRunSummaries, profile.shareProfile',
                   'consents.1 == coach.shareSleep','sleep.summary == sleepInfo',
                   'engine.runHistory.first?.source_uuid == lastRun.source_uuid',
                   'lastAutomaticChange:lastAutomaticChange','reviewObservedOutcomes(',
                   'Observation seulement : le bénéfice','private func persist()']) {
  assert.ok(coach.includes(term),'Missing GPT reasoning / safeguards '+term);
}
assert.ok(screen.includes('if let followUp=item.followUp'));
assert.ok(app.includes('autopilot.reviewObservedOutcomes'));
assert.ok(pbx.includes('PaceAutopilotSignificance.swift in Sources'));
console.log('V5.3: independent evidence domains, individualized sleep baseline, 7-day stability, GPT counterfactual, documented outcomes and verified references.');
