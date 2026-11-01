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
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                engine.startObservers()
                engine.resync()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                engine.resync()
            }
        }
    }
}
