import SwiftUI

struct PaceSettingsScreen: View {
    @EnvironmentObject var engine: HealthSyncEngine
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirming = false
    var body: some View {
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Apple Santé").font(.headline)
                        Text(engine.status).font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "heart.text.square.fill").foregroundStyle(PaceColors.teal)
                }
                Button("Actualiser les activités") { engine.resync() }
                Button("Réglages de l’application") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            } header: { Text("Synchronisation") } footer: {
                Text("iOS peut retarder les mises à jour en arrière-plan. L’ouverture de PACE LAB relance la synchronisation.")
            }
            Section("Bibliothèque locale") {
                LabeledContent("Activités", value: "\(engine.snapshot.count)")
                LabeledContent("Courses", value: "\(engine.runHistory.count)")
                LabeledContent("Historique le plus ancien", value: engine.snapshot.last.map { PaceFormat.date($0.startDate) } ?? "—")
            }
            Section("À propos") {
                LabeledContent("Application", value: "PACE LAB")
                LabeledContent("Version", value: "2.1 · Native")
                Label("Aucune donnée Santé envoyée vers un serveur", systemImage: "lock.shield")
                    .font(.subheadline)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PaceColors.base)
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fermer") { dismiss() } } }
    }
}
