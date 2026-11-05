import SwiftUI

struct PaceSettingsScreen: View {
    @EnvironmentObject var engine: HealthSyncEngine
    @EnvironmentObject var sleep: PaceSleepHealthKit
    @EnvironmentObject var healthSignals: PaceHealthSignals
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
                Button("Activer les mesures supplémentaires de l’Apple Watch") { engine.requestAdvancedPermission() }
                Button(sleep.monitoringEnabled ? "Actualiser le sommeil" : "Autoriser le sommeil") {
                    if sleep.monitoringEnabled { sleep.refresh(force:true) }
                    else { sleep.requestAccess() }
                }
                LabeledContent("Sommeil", value:sleep.status)
                    .foregroundStyle(PaceColors.teal)
                if engine.advancedEnabled {
                    LabeledContent("Mesures détaillées", value: engine.advancedRemaining == 0 ?
                        "Recherche à jour" : "\(engine.advancedRemaining) courses à enrichir")
                }
                Button("Réglages de l’application") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            } header: { Text("Synchronisation") } footer: {
                Text("iOS peut retarder les mises à jour en arrière-plan. L’ouverture de PACE LAB relance la synchronisation.")
            }
            Section("Mesures cardiovasculaires et corporelles") {
                Button {
                    Task { await healthSignals.requestAccess() }
                } label: {
                    Label(healthSignals.accessRequested ?
                          "Redemander l'accès aux mesures complémentaires" :
                          "Activer les mesures complémentaires Santé",
                          systemImage: "waveform.path.ecg")
                }
                Button("Actualiser les mesures") {
                    Task { await healthSignals.refresh() }
                }
                .disabled(!healthSignals.accessRequested || healthSignals.isLoading)
                HStack {
                    if healthSignals.isLoading { ProgressView() }
                    Text(healthSignals.status).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(PaceHealthSignalTypes.definitions, id: \.id) { metric in
                    if let latest = healthSignals.latest(metric.id) {
                        LabeledContent(metric.name,
                            value: "\(String(format: "%.1f", latest.value)) \(metric.unitLabel)")
                            .font(.subheadline)
                    }
                }
                Text("La présence d'une mesure ne signifie ni diagnostic ni partage avec ChatGPT. Le partage est configuré séparément dans Coach.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Couverture des données") {
                NavigationLink {
                    PaceHealthCoverageScreen()
                } label: {
                    Label("Quelles données Santé sont exploitées ?", systemImage:"heart.text.clipboard")
                }
                Text("Le catalogue distingue les lecteurs intégrés des mesures encore à développer. Il n'affiche pas tes autorisations personnelles.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Bibliothèque locale") {
                LabeledContent("Activités", value: "\(engine.snapshot.count)")
                LabeledContent("Courses", value: "\(engine.runHistory.count)")
                LabeledContent("Historique le plus ancien", value: engine.snapshot.last.map { PaceFormat.date($0.startDate) } ?? "—")
            }
            Section("À propos") {
                LabeledContent("Application", value: "PACE LAB")
                LabeledContent("Version", value: "V7 · en validation")
                Label("Les mesures Santé restent sur l’iPhone. Seuls les résumés autorisés du Coach sont envoyés à OpenAI.", systemImage: "lock.shield")
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


/// Product capability inventory only — not an Apple Health authorization screen.
private struct PaceHealthCoverageScreen: View {
    private func stage(_ value: PaceHealthPipelineStage) -> String {
        switch value {
        case .availableInCurrentPipeline: return "Lecteur intégré"
        case .partialPipeline: return "Partiel"
        case .planned: return "À développer"
        }
    }

    var body: some View {
        List {
            Section {
                Text("La présence d'un lecteur ne signifie pas que tu as autorisé l'accès ni qu'une mesure existe. Les données prévues ne sont ni récupérées ni analysées par l'IA.")
                    .font(.subheadline)
            }
            ForEach(PaceHealthDataDomain.allCases, id: \.self) { domain in
                Section(domain.rawValue) {
                    ForEach(PaceHealthCoverageCatalog.grouped(domain)) { measure in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(measure.title).font(.subheadline.weight(.medium))
                                Spacer()
                                Text(stage(measure.stage))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            Text(measure.benefit)
                                .font(.caption).foregroundStyle(.secondary)
                            if measure.neverShareRawByDefault {
                                Label("Données brutes non partagées avec le Coach",
                                      systemImage: "lock.shield")
                                    .font(.caption2).foregroundStyle(PaceColors.teal)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Données Santé")
        .navigationBarTitleDisplayMode(.inline)
    }
}
