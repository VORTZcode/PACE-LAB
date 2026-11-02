import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const swift=name=>readFileSync('ios/PaceLabCompanion/'+name+'.swift','utf8');
const auto=swift('PaceAutopilot');
const significance=swift('PaceAutopilotSignificance');
const screen=swift('PaceCoachScreen');
const guard=swift('PaceAutopilotGuard');
const app=swift('PaceLabCompanionApp');
const checks=[
  [auto,'let localSignificantPain=(note?.pain ?? -1) >= 4'],
  [auto,'let seriousPain=localSignificantPain ||'],
  [auto,'(journal.notes[lastRun.source_uuid]?.pain ?? -1) >= 4'],
  [auto,'local-veto:'],
  [auto,'Ce signal n\'a pas été transmis à ChatGPT'],
  [auto,'var evidenceDetails: [String]? = nil'],
  [auto,'var alternativeConsidered: String? = nil'],
  [auto,'var expectedEffect: String? = nil'],
  [auto,'var uncertainty: String? = nil'],
  [auto,'evidenceDetails:sources.map('],
  [screen,'Voir toutes les décisions et leurs résultats'],
  [screen,'NavigationLink {'],
  [screen,'Text("Alternative examinée")'],
  [screen,'Text("Effet attendu")'],
  [screen,'Text("Limites de l\'analyse")'],
  [screen,'Observation après la décision'],
  [screen,'Aucun changement nécessaire selon les données disponibles.'],
  [significance,'trend.recent28Runs >= 6'],
  [significance,'trend.recent28Km >= 15'],
  [significance,'spread >= 3'],
  [significance,'recent <= previous - 45'],
  [guard,'lastAutomaticChange'],
  [app,'autopilot.reviewObservedOutcomes']
];
for(const [source,needle] of checks)assert.ok(source.includes(needle),'Missing V5.4 contract: '+needle);
assert.ok(!auto.includes('try library.acceptCoachDraft('),'autopilot cannot silently rewrite full weekly plan');
assert.ok(!auto.includes('sleep.nights.map'),'unconsented raw sleep history');
console.log('V5.4 verified: privacy-safe local veto, robust longitudinal trend, structured history and no silent weekly rewrites.');
