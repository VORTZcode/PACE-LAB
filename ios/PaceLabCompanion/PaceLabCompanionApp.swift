import SwiftUI
import UIKit
import BackgroundTasks

// PACE-LAB native navigation: five clear destinations and visible coach.
/// HealthKit stays on-device until the athlete opts into particular AI summaries.
enum PacePrimaryTab: Hashable {
    case today, activities, programme, coach, nutrition
}
enum PaceCoachDestination: Hashable {
    case discussion, bilans, programme, settings
}
@MainActor final class PaceTabRouter: ObservableObject {
    private var routing = false
    @Published var selected: PacePrimaryTab = .today {
        didSet {
            if selected == .coach && !routing { coachDestination = .discussion }
        }
    }
    @Published var coachDestination: PaceCoachDestination = .discussion
    func openCoach(_ destination:PaceCoachDestination) {
        routing = true
        coachDestination = destination
        selected = .coach
        routing = false
    }

    init() {
        // UI audit previews use a fresh simulator (no personal HealthKit history).
        // Production builds cannot change the initial tab via launch arguments.
        #if DEBUG && targetEnvironment(simulator)
        if let preview=ProcessInfo.processInfo.arguments.first(where:{
            $0.hasPrefix("--pace-audit-tab=")
        }) {
            switch preview.replacingOccurrences(of:"--pace-audit-tab=",with:"") {
            case "activities": selected = .activities
            case "programme": selected = .programme
            case "coach": selected = .coach
            case "nutrition": selected = .nutrition
            default: break
            }
        }
        #endif
    }
}

final class PaceLabDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: HealthSyncEngine.refreshIdentifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            Task { @MainActor in HealthSyncEngine.shared.handleRefreshTask(task) }
        }
        Task { @MainActor in HealthSyncEngine.shared.startObservers() }
        return true
    }
}

@main
struct PaceLabCompanionApp: App {
    @UIApplicationDelegateAdaptor(PaceLabDelegate.self) var delegate
    @StateObject private var tabs = PaceTabRouter()
    @StateObject private var engine = HealthSyncEngine.shared
    @StateObject private var library = PaceLibrary()
    @StateObject private var journal = PaceSessionJournal()
    @StateObject private var chatGPT = PaceChatGPTConnection()
    @StateObject private var coach = PaceCoachEngine()
    @StateObject private var athleteProfile = PaceAthleteProfileStore()
    @StateObject private var adaptiveMonitor = PaceAdaptiveMonitor()
    @StateObject private var living = PaceLivingCoach()
    @StateObject private var sleep = PaceSleepHealthKit()
    @StateObject private var healthSignals = PaceHealthSignals.shared
    @StateObject private var autopilot = PaceAutopilot()
    @StateObject private var strengthTracker = PaceStrengthTracker()
    @StateObject private var strengthLinks = PaceStrengthWorkoutLinks.shared
    @StateObject private var runLinks = PaceRunWorkoutLinks.shared
    @State private var hasLoaded = false

    var body: some Scene {
        WindowGroup {
            TabView(selection:$tabs.selected) {
                TodayScreen()
                    .tabItem { Label("Aujourd’hui", systemImage: "house") }
                    .tag(PacePrimaryTab.today)
                ActivitiesScreen()
                    .tabItem { Label("Activités", systemImage: "figure.run") }
                    .tag(PacePrimaryTab.activities)
                ProgrammeScreen()
                    .tabItem { Label("Programme", systemImage: "calendar") }
                    .tag(PacePrimaryTab.programme)
                PaceCoachScreen()
                    .tabItem { Label("Coach", systemImage: "brain.head.profile") }
                    .tag(PacePrimaryTab.coach)
                NutritionScreen()
                    .tabItem { Label("Nutrition", systemImage: "fork.knife") }
                    .tag(PacePrimaryTab.nutrition)
            }
            .tint(PaceColors.volt)
            .preferredColorScheme(.dark)
            .environmentObject(tabs)
            .environmentObject(engine)
            .environmentObject(library)
            .environmentObject(journal)
            .environmentObject(chatGPT)
            .environmentObject(coach)
            .environmentObject(athleteProfile)
            .environmentObject(adaptiveMonitor)
            .environmentObject(living)
            .environmentObject(sleep)
            .environmentObject(healthSignals)
            .environmentObject(autopilot)
            .environmentObject(strengthTracker)
            .environmentObject(strengthLinks)
            .environmentObject(runLinks)
            .onReceive(engine.$revision) { _ in
                sleep.refresh()
                living.refresh(engine:engine,journal:journal,strength:strengthTracker)
                coach.detectNewWorkout(engine:engine)
                coach.refreshAcceptedPlans(engine:engine,journal:journal)
                adaptiveMonitor.refresh(engine:engine,journal:journal,library:library)
                autopilot.reviewObservedOutcomes(engine:engine,journal:journal)
                // A new run always receives a session report when the athlete
                // authorized either auto-review or autonomous coaching.
                if !launchAutomaticSessionReview() { launchAutopilot() }
            }
            .onReceive(strengthTracker.$records) { _ in
                living.refresh(engine:engine,journal:journal,strength:strengthTracker)
                if !launchAutomaticSessionReview() { launchAutopilot() }
            }
            .onReceive(library.$completed) { _ in
                // A confirmed session can unlock the HealthKit review, but
                // manually checking a box cannot fabricate workout measurements.
                if !launchAutomaticSessionReview() { launchAutopilot() }
            }
            .onReceive(library.$missedSessions) { _ in
                // Keep the coach aware of missed training, without making up a workout.
                if !launchAutomaticSessionReview() { launchAutopilot() }
            }
            .onReceive(journal.$notes) { _ in
                living.refresh(engine:engine,journal:journal,strength:strengthTracker)
                adaptiveMonitor.refresh(engine:engine,journal:journal,library:library)
                coach.refreshAcceptedPlans(engine:engine,journal:journal)
                autopilot.reviewObservedOutcomes(engine:engine,journal:journal)
                launchAutopilot()
            }
            .onReceive(sleep.$summary) { _ in launchAutopilot() }
            .onReceive(autopilot.$enabled) { _ in
                if !launchAutomaticSessionReview() { launchAutopilot() }
            }
            .onReceive(coach.$autoReview) { _ in
                _ = launchAutomaticSessionReview()
            }
            .onReceive(coach.$shareStrengthSets) { _ in
                coach.detectNewWorkout(engine: engine)
                _ = launchAutomaticSessionReview()
            }
            .onReceive(coach.$shareRunSummaries) { _ in
                _ = launchAutomaticSessionReview()
            }
            .onReceive(chatGPT.$planUsageEnabled) { _ in
                _ = launchAutomaticSessionReview()
            }
            // Foreground catch-up: bounded retry windows can expire without a
            // new HealthKit event. No polling service or background guarantee.
            .onReceive(Timer.publish(every:65,on:.main,in:.common).autoconnect()) { _ in
                _ = launchAutomaticSessionReview()
            }
            .onAppear {
                guard !hasLoaded else { return }
                sleep.startObservers()
                sleep.refresh(force:true)
                Task { await healthSignals.refresh() }
                hasLoaded = true
                engine.startObservers()
                living.refresh(engine:engine,journal:journal,strength:strengthTracker)
                coach.refreshAcceptedPlans(engine:engine,journal:journal)
                engine.resync()
                if !launchAutomaticSessionReview() { launchAutopilot() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                sleep.startObservers()
                sleep.refresh(force:true)
                Task { await healthSignals.refresh() }
                living.refresh(engine:engine,journal:journal,strength:strengthTracker)
                coach.refreshAcceptedPlans(engine:engine,journal:journal)
                engine.resync()
                if !launchAutomaticSessionReview() { launchAutopilot() }
            }
        }
    }

    @discardableResult
    private func launchAutomaticSessionReview() -> Bool {
        guard chatGPT.planUsageEnabled, !coach.isLoading, !autopilot.isEvaluating,
              coach.beginAutomaticReview(engine:engine,autonomousMode:autopilot.enabled)
        else { return false }
        guard let reservedID=coach.pendingAutomaticWorkoutID else { return false }
        Task { @MainActor in
            await coach.analyzeSession(client:chatGPT,engine:engine,library:library,
                journal:journal,profile:athleteProfile,strength:strengthTracker,sleep:sleep,
                workoutID:reservedID)
            // Keep review and training changes sequential. Process the remaining
            // recent activities gradually, without a burst of GPT requests.
            launchAutopilot()
            try? await Task.sleep(for:.seconds(27))
            _ = launchAutomaticSessionReview()
        }
        return true
    }

    private func launchAutopilot() {
        guard autopilot.enabled else { return }
        Task { @MainActor in
            await autopilot.evaluateIfNeeded(client:chatGPT,coach:coach,engine:engine,
                sleep:sleep,journal:journal,profile:athleteProfile,
                strength:strengthTracker,library:library)
            prepareNextWeekIfNeeded()
            // If the previous review had to wait for the autonomous decision,
            // the next eligible workout can now proceed.
            _ = launchAutomaticSessionReview()
        }
    }

    /// Only prepare a draft; a full seven-day programme and nutrition plan
    /// cannot replace the current programme without the athlete accepting it.
    private func prepareNextWeekIfNeeded() {
        guard autopilot.enabled, chatGPT.planUsageEnabled, coach.shareRunSummaries,
              athleteProfile.profile != nil, athleteProfile.shareProfile,
              !coach.isLoading, !autopilot.isEvaluating, coach.pending == nil,
              !engine.runHistory.isEmpty else { return }
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"en_US_POSIX")
        formatter.dateFormat="yyyy-MM-dd"
        let today=formatter.string(from:.now)
        let plan=library.currentPlan.sorted(by:{$0.date < $1.date})
        guard let last=plan.last, !plan.isEmpty,
              plan.filter({ $0.date >= today }).count <= 2 else { return }
        let key="pace.coach.weekly-proposal." + last.date
        let attemptKey=key + ".attempt"
        guard !UserDefaults.standard.bool(forKey:key) else { return }
        if let attempted=UserDefaults.standard.object(forKey:attemptKey) as? Date,
           Date.now.timeIntervalSince(attempted) < 24*3600 { return }
        UserDefaults.standard.set(Date.now,forKey:attemptKey)
        Task { @MainActor in
            await coach.generate(client:chatGPT,engine:engine,library:library,
                journal:journal,profile:athleteProfile,strength:strengthTracker,sleep:sleep)
            if coach.pending != nil {
                UserDefaults.standard.set(true,forKey:key)
                coach.publishImportantDecision(
                    "J'ai préparé la semaine suivante avec tes dernières données. " +
                    "Tu peux examiner les séances et les repas dans Mon programme, " +
                    "puis accepter ou refuser la proposition. Rien n'a été remplacé.",
                    key:"next-week-" + last.date)
            }
        }
    }
}
