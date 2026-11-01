import SwiftUI
import UIKit
import BackgroundTasks

final class PaceLabDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: HealthSyncEngine.refreshIdentifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            HealthSyncEngine.shared.handleRefreshTask(task)
        }
        HealthSyncEngine.shared.startObservers()
        return true
    }
}

@main
struct PaceLabCompanionApp: App {
    @UIApplicationDelegateAdaptor(PaceLabDelegate.self) var delegate
    @StateObject private var engine = HealthSyncEngine.shared
    var body: some Scene {
        WindowGroup {
            HealthBridgeView()
                .environmentObject(engine)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    engine.resync()
                }
        }
    }
}

struct HealthBridgeView: View {
    @EnvironmentObject var engine: HealthSyncEngine
    @State private var url = UserDefaults.standard.string(forKey: "pace_sync_url") ?? ""
    @State private var key = UserDefaults.standard.string(forKey: "pace_sync_key") ?? ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Connexion privée PACE LAB") {
                    TextField("https://<projet>.supabase.co", text: $url)
                        .keyboardType(.URL).autocorrectionDisabled().textInputAutocapitalization(.never)
                    SecureField("Clé publique (publishable key)", text: $key)
                    TextField("E-mail du compte PACE LAB", text: $email)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    SecureField("Mot de passe", text: $password)
                    Button("Se connecter") {
                        Task { await engine.signIn(url: url, publicKey: key, email: email, password: password); password = "" }
                    }
                }
                Section("Apple Santé") {
                    Button("Autoriser l'accès aux entraînements") { engine.requestPermission() }
                    Button("Synchroniser les activités maintenant") { engine.resync() }
                    Text(engine.status).font(.footnote)
                    Text("Séances locales en attente : \(engine.queuedCount)").font(.footnote)
                }
                Section("Récupération cardiaque") {
                    Text("Lecture des mesures disponibles jusqu'à 5 min après la fin de la séance. Apple Watch conserve généralement une mesure active pendant environ 3 min : les minutes sans échantillon restent manquantes.")
                    Text("iOS peut retarder le traitement en arrière-plan. À l'ouverture, PACE LAB rattrape les données non synchronisées.")
                }
            }
            .navigationTitle("PACE LAB Sync")
        }
    }
}
