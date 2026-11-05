import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const swift = name => readFileSync('ios/PaceLabCompanion/'+name+'.swift','utf8');
const home = swift('PaceLivingCoach');
const screen = swift('PaceCoachScreen');
const engine = swift('PaceCoachEngine');
const report = swift('PaceCoachReport');
const athlete = swift('PaceAthleteProfile');
// A single Button wraps the entire card, including the title, summary and link-like footer.
assert.match(home,/Button \{ onOpenCoach\(signal.destination\) \} label: \{\s*PaceCard/);
const card = home.slice(home.indexOf('var body: some View {',home.indexOf('struct PaceLivingCoachCard')));
assert.ok(!card.includes('Button { onOpenCoach(signal.destination) } label: {\n                        HStack'), 'No nested footer action');
assert.match(home,/contentShape\(RoundedRectangle\(cornerRadius:24\)\)/);
assert.match(home,/accessibilityLabel\("\\\(signal.title\)/);
// Goals: confirmed, optionally shared; no unsupported reliance on ChatGPT saved memories.
for(const field of ['runningGoal','bodyGoal','motivation','preferredRunsPerWeek','preferredStrengthPerWeek']) {
 assert.ok(athlete.includes(field),'Goal field missing: '+field);
}
assert.match(engine,/profile\.shareProfile,let value = profile\.profile/);
assert.match(engine,/value\.aiContext/);
assert.match(screen,/!athleteProfile\.shareProfile/);
assert.match(screen,/Activer le partage de mes objectifs avec le Coach/);
// Each new report saves a consent provenance and reuses at most three validated reports.
// Legacy or locally generated reports have no consent provenance and cannot be replayed.
assert.match(report,/var sharedContextDomains: \[String\]\? = nil/);
assert.match(engine,/report\.sharedContextDomains = Array\(consentAtStart\)\.sorted\(\)/);
assert.match(engine,/consentAtStart == currentSharedDomains\(profile:profile\)/);
assert.match(engine,/!report\.isLocal/);
assert.match(engine,/let recordedDomains = report\.sharedContextDomains/);
assert.match(engine,/Set\(recordedDomains\)\.isSubset\(of:authorized\)/);
assert.match(engine,/prefix\(3\)\.map \{ report in/);
assert.match(engine,/if let memory = priorAnalysisContext/);
// Waist is opt-in and weight is not conflated with observed muscle mass.
assert.match(engine,/shareWaist = UserDefaults\.standard\.bool/);
assert.match(screen,/Tour de taille renseigné et évolution/);
assert.match(engine,/if shareWaist \{/);
assert.match(engine,/Aucune estimation de masse grasse|aucune estimation de masse grasse/);
console.log('V6.1: full-card touch, confirmed goals, bounded analysis continuity, consent-safe legacy handling, opt-in body trend.');
