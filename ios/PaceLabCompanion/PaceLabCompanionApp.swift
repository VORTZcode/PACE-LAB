import SwiftUI
import UIKit
import BackgroundTasks

// PACE LAB V2: fully native iPhone UI. HealthKit remains on-device.
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
            TabView {
                TodayScreen()
                    .tabItem { Label("Aujourd’hui", systemImage: "house") }
                ActivitiesScreen()
                    .tabItem { Label("Activités", systemImage: "figure.run") }
                ProgrammeScreen()
                    .tabItem { Label("Programme", systemImage: "calendar") }
                ProgressScreen()
                    .tabItem { Label("Progrès", systemImage: "chart.xyaxis.line") }
                NutritionScreen()
                    .tabItem { Label("Nutrition", systemImage: "fork.knife") }
            }
            .tint(PaceColors.teal)
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
                launchAutopilot()
                if !autopilot.enabled && chatGPT.planUsageEnabled && !coach.isLoading &&
                   coach.beginAutomaticReview(engine:engine) {
                    coach.focusWorkoutID = nil
                    Task { await coach.analyzeSession(client:chatGPT,engine:engine,library:library,journal:journal,profile:athleteProfile,strength:strengthTracker,sleep:sleep) }
                }
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
            .onReceive(autopilot.$enabled) { _ in launchAutopilot() }
            .onAppear {
                guard !hasLoaded else { return }
                sleep.startObservers()
                sleep.refresh(force:true)
                hasLoaded = true
                engine.startObservers()
                living.refresh(engine:engine,journal:journal,strength:strengthTracker)
                coach.refreshAcceptedPlans(engine:engine,journal:journal)
                engine.resync()
                launchAutopilot()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                sleep.startObservers()
                sleep.refresh(force:true)
                living.refresh(engine:engine,journal:journal,strength:strengthTracker)
                coach.refreshAcceptedPlans(engine:engine,journal:journal)
                engine.resync()
                launchAutopilot()
            }
        }
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
