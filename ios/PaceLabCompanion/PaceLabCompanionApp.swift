import SwiftUI
import UIKit
import BackgroundTasks

// PACE-LAB native navigation: five clear destinations and visible coach.
/// HealthKit stays on-device until the athlete opts into particular AI summaries.
enum PacePrimaryTab: Hashable {
    case today, activities, programme, coach, nutrition
}
@MainActor final class PaceTabRouter: ObservableObject {
    @Published var selected: PacePrimaryTab = .today

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
    @StateObject private var autopilot = PaceAutopilot()
    @StateObject private var strengthTracker = PaceStrengthTracker()
    @StateObject private var strengthLinks = PaceStrengthWorkoutLinks()
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
            .tint(PaceColors.teal)
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
            .environmentObject(autopilot)
            .environmentObject(strengthTracker)
            .environmentObject(strengthLinks)
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
                launchAutopilot()
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
            .onReceive(chatGPT.$planUsageEnabled) { _ in
                _ = launchAutomaticSessionReview()
            }
            .onAppear {
                guard !hasLoaded else { return }
                sleep.startObservers()
                sleep.refresh(force:true)
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
                living.refresh(engine:engine,journal:journal,strength:strengthTracker)
                coach.refreshAcceptedPlans(engine:engine,journal:journal)
                engine.resync()
                if !launchAutomaticSessionReview() { launchAutopilot() }
            }
        }
    }

    @discardableResult
    private func launchAutomaticSessionReview() -> Bool {
        guard chatGPT.planUsageEnabled, !coach.isLoading,
              coach.beginAutomaticReview(engine:engine,autonomousMode:autopilot.enabled)
        else { return false }
        coach.focusWorkoutID = nil
        Task { @MainActor in
            await coach.analyzeSession(client:chatGPT,engine:engine,library:library,
                journal:journal,profile:athleteProfile,strength:strengthTracker,sleep:sleep)
            // Keep session interpretation and training adjustments sequential,
            // so simultaneous OpenAI requests cannot conflict or discard results.
            launchAutopilot()
        }
        return true
    }

    private func launchAutopilot() {
        guard autopilot.enabled else { return }
        Task { @MainActor in
            await autopilot.evaluateIfNeeded(client:chatGPT,coach:coach,engine:engine,
                sleep:sleep,journal:journal,profile:athleteProfile,
                strength:strengthTracker,library:library)
        }
    }
}
