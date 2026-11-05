import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const swift = name => readFileSync('ios/PaceLabCompanion/'+name+'.swift','utf8');
const ui = swift('PaceCoachScreen');
const engine = swift('PaceCoachEngine');
const app = swift('PaceLabCompanionApp');
const programme = swift('PaceViewsProgramme');

// The composer stays anchored above the tab bar and doesn't get pushed
// below 100 long conversational messages.
assert.match(ui, /@FocusState private var composerFocused/);
assert.match(ui, /ScrollViewReader \{ chatScroll in/);
assert.match(ui, /\.safeAreaInset\(edge:\.bottom,spacing:0\)/);
assert.match(ui, /private var coachComposer: some View/);
assert.match(ui, /TextField\("Message au coach…"/);
assert.match(ui, /private func sendCoachMessage\(\)/);
assert.match(ui, /id\("coach-chat-end"\)/);
assert.match(ui, /chatScroll\.scrollTo\("coach-chat-end",anchor:\.bottom\)/);
assert.match(ui, /\.scrollDismissesKeyboard\(\.interactively\)/);
assert.match(ui, /ForEach\(coach\.conversation\.suffix\(100\)\)/);
assert.ok(ui.indexOf('private var coachComposer') < ui.indexOf('private var chatSection'));
assert.ok(!ui.substring(ui.indexOf('private var chatSection')).includes('TextField('));

// The chat does not repeat the same status card when nothing needs attention.
assert.match(ui, /if activeTab != \.chat \|\| !autopilot\.enabled/);
assert.match(ui, /coach\.automaticNeedsAttentionCount > 0 \|\| coach\.pending != nil/);

// The plan may show a matching measured workout, never infer fulfillment
// from a date alone or select arbitrarily between multiple same-type events.
assert.match(programme, /static func matching\(for day: PaceDay/);
assert.match(programme, /return candidates\.count == 1 \? candidates\.first : nil/);
assert.match(programme, /PacePlanActivityMatch\.matching\(for:day,in:engine\.snapshot\)/);
assert.match(programme, /Course enregistrée ·/);
assert.match(programme, /if !dayActivities\.isEmpty \|\| library\.completed\.contains\(day\.date\)/);
assert.match(programme, /à rapprocher du programme/);
assert.match(programme, /private var matchingActivity: WorkoutPayload\? \{/);

// AI can give deep answers when asked, rather than recycling numerical data.
// Automatic post-session updates remain distinguishable from an applied change.
assert.match(engine, /conversation\.suffix\(100\)/);
assert.match(engine, /développe vraiment lorsqu'il demande une analyse poussée/);
assert.match(engine, /Ne prétends jamais avoir analysé une mesure absente/);
assert.match(engine, /cette analyse ne change PAS le plan/);

// A retry becoming eligible during an open app no longer requires another
// HealthKit update; there is still no promise of suspended iOS execution.
assert.match(app, /Timer\.publish\(every:65,on:\.main,in:\.common\)\.autoconnect\(\)/);
assert.match(app, /_ = launchAutomaticSessionReview\(\)/);
assert.match(app, /coach\.beginAutomaticReview\(engine:engine,autonomousMode:autopilot\.enabled\)/);
console.log('V6.0 UX: composer ancré, conversation durable, suivi mesuré non ambigu, IA sobre et reprise automatique.');
