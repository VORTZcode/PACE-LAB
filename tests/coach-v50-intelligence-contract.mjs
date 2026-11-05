import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const file=name=>readFileSync('ios/PaceLabCompanion/'+name,'utf8');
const trends=file('PaceLongitudinalRules.swift');
const living=file('PaceLivingCoach.swift');
const profile=file('PaceAthleteProfile.swift');
const evidence=file('PaceEvidenceEngine.swift');
const coach=file('PaceCoachEngine.swift');
const app=file('PaceLabCompanionApp.swift');
const screen=file('PaceCoachScreen.swift');
const pbx=readFileSync('ios/PaceLabCompanion.xcodeproj/project.pbxproj','utf8');
for(const token of ['-56 * 86400','source_uuid','deduplicated','comparisonPercent','missingFeedback28',
                    'recent7HighEffort','recent7MaximumDiscomfort','evidenceQuality']) {
  assert.ok(trends.includes(token),'Missing independent longitudinal rule: '+token);
}
assert.match(profile,/preferredRunsPerWeek: 3/);
assert.match(profile,/preferredStrengthPerWeek: 2/);
assert.ok(living.includes('PaceLongitudinalRules.calculate'));
assert.ok(living.includes('PaceLivingCoachCard'));
assert.ok(living.includes('recent7HighEffort >= 2'));
assert.ok(living.includes('recent7MaximumDiscomfort ?? -1) >= 4'));
assert.ok(evidence.includes('runs.count > profile.preferredRunsPerWeek'));
assert.ok(evidence.includes('strengthCount > profile.preferredStrengthPerWeek'));
assert.ok(evidence.includes('adjustmentRationale'));
assert.ok(coach.includes('let sharedNotes = shareSessionNotes ?'));
assert.ok(coach.includes('notes:sharedNotes).promptContext'));
assert.ok(coach.includes('if let historical = acceptedPlans.first'));
assert.ok(coach.includes('func recordAcceptedPlan('));
assert.ok(coach.includes('func refreshAcceptedPlans('));
assert.ok(coach.includes('pace-coach-accepted-history.json'));
assert.ok(coach.includes('FileProtectionType.completeUntilFirstUserAuthentication'));
assert.ok(coach.includes('No proposed plan becomes historical until explicitly accepted'));
assert.ok(coach.includes('if let data = try? Data(contentsOf:acceptedPlansURL)'));
assert.ok(app.includes('coach.refreshAcceptedPlans(engine:engine,journal:journal)'));
assert.ok(screen.includes('try library.acceptCoachDraft(pending)\n                        coach.recordAcceptedPlan(pending,baseline:evidence)'));
assert.ok(screen.includes('Suivi du dernier plan accepté'));
assert.ok(pbx.includes('PaceLongitudinalRules.swift in Sources'));
console.log('V5.0: 56-day observed trends, athlete cadence guardrails, consent-scoped AI context, locally stored accepted-plan outcomes and coach UI.');
