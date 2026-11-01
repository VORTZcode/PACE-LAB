import SwiftUI
import UIKit
import WebKit
import BackgroundTasks

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
    var body: some Scene {
        WindowGroup {
            TabView {
                PaceLabWebView()
                    .tabItem { Label("PACE LAB", systemImage: "figure.run") }
                HealthBridgeView()
                    .tabItem { Label("Apple Santé", systemImage: "heart.text.square") }
            }
            .environmentObject(engine)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                engine.resync()
            }
        }
    }
}

struct PaceLabWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default() // Persistent local storage for user-entered plan and meals.
        configuration.userContentController.addUserScript(WKUserScript(source: "window.__PACE_LAB_NATIVE=true;", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let web = WKWebView(frame: .zero, configuration: configuration)
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 0.965, green: 0.976, blue: 0.988, alpha: 1)
        web.navigationDelegate = context.coordinator
        context.coordinator.webView = web
        if let dir = Bundle.main.url(forResource: "WebApp", withExtension: nil),
           let main = URL(string: "index.html", relativeTo: dir)?.absoluteURL {
            web.loadFileURL(main, allowingReadAccessTo: dir)
        } else {
            web.loadHTMLString("<h2>PACE LAB</h2><p>Ressources web non incluses dans le bundle. Vérifier ios/project.yml.</p>", baseURL: nil)
        }
        return web
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        private var observation: NSObjectProtocol?
        override init() {
            super.init()
            observation = NotificationCenter.default.addObserver(forName: .paceHealthKitUpdated, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
        deinit { if let o = observation { NotificationCenter.default.removeObserver(o) } }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { refresh() }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Only code bundled inside the signed app may receive private HealthKit summaries.
            let scheme = navigationAction.request.url?.scheme
            decisionHandler(scheme == "file" || scheme == "about" ? .allow : .cancel)
        }
        @MainActor func refresh() {
            guard let webView = webView else { return }
            let payloads = HealthSyncEngine.shared.snapshot.map(WorkoutWebSummary.init)
            guard let encoded = try? JSONEncoder().encode(payloads),
                  let json = String(data: encoded, encoding: .utf8) else { return }
            webView.evaluateJavaScript("window.PaceNativeHealth && window.PaceNativeHealth.ingest(\(json))") { _, _ in }
        }
    }
}

struct HealthBridgeView: View {
    @EnvironmentObject var engine: HealthSyncEngine
    var body: some View {
        NavigationStack {
            Form {
                Section("Apple Santé") {
                    Button("Autoriser la lecture des entraînements") { engine.requestPermission() }
                    Button("Actualiser mes séances maintenant") { engine.resync() }
                    Text(engine.status).font(.footnote)
                    Text("\(engine.savedCount) séance(s) enregistrée(s) localement").font(.subheadline)
                }
                Section("Récupération cardiaque") {
                    Text("PACE LAB analyse les mesures réelles de fréquence cardiaque pendant les 3 minutes suivant la séance. L'actualisation dépend de la disponibilité des données dans Santé.")
                    Text("Les mises à jour en arrière-plan dépendent d'iOS et ne sont pas garanties exactement 3 minutes après la séance.")
                }
                Section("Confidentialité") {
                    Text("Aucune connexion Supabase, aucun compte PACE LAB, aucun envoi de données de santé à un serveur. Les données détaillées restent sur cet iPhone.")
                    Text("Pour afficher tes courses dans l'application, ouvre l'onglet PACE LAB.")
                }
            }
            .navigationTitle("Apple Santé")
        }
    }
}
