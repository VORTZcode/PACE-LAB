import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const swift=n=>readFileSync('ios/PaceLabCompanion/'+n+'.swift','utf8');
const engine=swift('PaceCoachEngine');
const app=swift('PaceLabCompanionApp');
const auto=swift('PaceAutopilot');
const guard=swift('PaceAutopilotGuard');
const auth=swift('PaceChatGPTConnection');
const screen=swift('PaceCoachScreen');
const home=swift('PaceViewsCore');
const living=swift('PaceLivingCoach');
const plan=swift('PaceViewsProgramme');
const food=swift('PaceViewsNutrition');
const activities=swift('PaceViewsActivities');

// One event -> one eligible activity -> one GPT call. Older activities can be
// analyzed without changing the user's current focused workout in the UI.
for(const text of [
 'candidateActivities(engine: HealthSyncEngine',
 'automaticPendingCount=eligible.count',
 'automaticNeedsAttentionCount=eligible.filter',
 'automaticInFlightID=item.source_uuid',
 'PaceAutoReviewRetryRules.ready(',
 'workoutID:String? = nil',
 'workoutID:run.source_uuid',
 'publishSessionInsight(report,run:run)',
 'pace.coach.conversation-session.',
 'reviewAttempts.removeValue(forKey:run.source_uuid)',
 'guard shareRunSummaries,',
 'automaticInFlightID = nil'
]) assert.ok(engine.includes(text), 'Missing V5.9 auto-queue: '+text);
assert.ok(guard.includes('static let maximumAttempts = 3'));
assert.ok(app.includes('workoutID:reservedID'));
assert.ok(app.includes('try? await Task.sleep(for:.seconds(27))'));
assert.ok(app.includes('!autopilot.isEvaluating'));
assert.ok(app.includes('prepareNextWeekIfNeeded()'));
assert.ok(app.includes('coach.pending == nil'));
assert.ok(app.includes('coach.generate(client:chatGPT'));
assert.ok(!app.includes('library.acceptCoachDraft('), 'full plan may not be silently adopted');
assert.ok(app.includes('enum PaceCoachDestination'));
assert.ok(app.includes('coachDestination = .discussion'));
assert.ok(app.includes('func openCoach(_ destination:PaceCoachDestination)'));
assert.ok(home.includes('tabs.openCoach(.bilans)'));
assert.ok(home.includes('tabs.openCoach(.programme)'));
assert.ok(home.includes('tabs.openCoach(.settings)'));


// AI is conversational and writes useful athlete-facing updates once, rather
// than repeating every internal decision and streaming status on the home tab.
assert.ok(auth.includes('onDelta:((String)->Void)? = nil'));
assert.ok(auth.includes('onDelta?(fragment)'));
assert.ok(engine.includes('streamingReply += fragment'));
assert.ok(engine.includes('func publishImportantDecision('));
assert.ok(auto.includes('if sources.count < 2'));
assert.ok(auto.includes('if localSignificantPain'));
assert.ok(auto.includes('Ce signal n\'a pas été transmis à ChatGPT'));
assert.ok(auto.includes('publishImportantDecision('));
assert.ok(auto.includes('body:"Une séance a été allégée.'));
assert.ok(!auto.includes('" · Alternative examinée : " + decision.alternativeConsidered'));
assert.ok(!home.includes('autopilot.status'));
assert.ok(living.includes('if let signal'));
assert.ok(living.includes('return nil'));
assert.ok(!living.includes('COACH ÉVOLUTIF'));

// Actions above exposition, no duplicated sales copy or pretended exercise.
assert.ok(screen.includes('case chat = "Discuter"'));
assert.ok(screen.includes('activeTab: PaceCoachTab = .chat'));
assert.ok(screen.includes('coach.streamingReply'));
assert.ok(screen.includes('Conversation'));
assert.ok(screen.includes('Mesures et sources utilisées'));
assert.ok(screen.includes('DisclosureGroup("Comprendre l\'analyse")'));
assert.ok(!screen.includes('Des données, des décisions éclairées') || screen.includes('if athleteProfile.profile == nil { coachHeader }'));
assert.ok(plan.includes('Revoir les consignes prévues'));
assert.ok(plan.includes('Fréquence différente de ton profil'));
assert.ok(food.includes('Repas de la semaine'));
assert.ok(activities.includes('Text("Ma progression")'));
console.log('V5.9: bounded multi-activity autonomy, proactive coach chat, no AI noise, cautious decisions and simplified pathways.');
