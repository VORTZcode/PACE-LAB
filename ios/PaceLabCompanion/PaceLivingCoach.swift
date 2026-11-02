import Foundation
import SwiftUI

/// An on-device, explainable snapshot. It does not call AI, diagnose illness,
/// infer pain from heart rate, or silently rewrite the training programme.
struct PaceLivingBrief: Equatable {
    enum Priority: String { case noData, feedback, maintain, review, discomfort }
    let priority: Priority
    let headline: String
    let detail: String
    let evidence: [String]
    let uncertainty: String
    let sourceWorkoutID: String?

    var promptContext: String {
        let measurements = evidence.joined(separator: " ; ")
        return "Bilan local non diagnostique : \(headline). \(detail). Faits observés : \(measurements). Limite : \(uncertainty)"
    }
}

enum PaceLivingCoachRules {
    static func calculate(runs: [WorkoutPayload],
                          notes: [String: PaceSessionNote],
                          completedStrengthSets: Int = 0,
                          now: Date = .now) -> PaceLivingBrief {
        let valid = runs.filter {
            $0.isRun && $0.kilometers.isFinite && $0.kilometers >= 0 &&
            $0.startDate <= now && $0.endDate <= now
        }.sorted { $0.startDate > $1.startDate }

        guard let last = valid.first else {
            return .init(priority: .noData, headline: "En attente de données",
                         detail: "Les séances enregistrées dans Apple Santé permettront de préparer un suivi.",
                         evidence: [], uncertainty: "Aucune course exploitable reçue.",
                         sourceWorkoutID: nil)
        }
        let longitudinal = PaceLongitudinalRules.calculate(runs: runs, notes: notes, now: now)
        let lastSeven = valid.filter { $0.startDate >= now.addingTimeInterval(-7 * 86400) }
        let lastTwentyEight = valid.filter { $0.startDate >= now.addingTimeInterval(-28 * 86400) }
        let weeklyKm = lastSeven.reduce(0.0) { $0 + $1.kilometers }
        let monthKm = lastTwentyEight.reduce(0.0) { $0 + $1.kilometers }
        let format = { (value: Double) -> String in
            String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
        }
        var facts: [String] = [
            "\(lastSeven.count) courses et \(format(weeklyKm)) km sur 7 jours glissants.",
            "\(lastTwentyEight.count) courses et \(format(monthKm)) km sur 28 jours glissants.",
            "Dernière course : \(format(last.kilometers)) km le \(last.startDate.formatted(date: .numeric, time: .omitted))."
        ]
        if completedStrengthSets > 0 {
            facts.append("\(completedStrengthSets) séries de renforcement validées sur les 7 derniers jours.")
        }
        facts.append(contentsOf: longitudinal.evidence)
        let note = notes[last.source_uuid]
        let effort = note?.effort
        let pain = note?.pain
        if let effort { facts.append("Effort déclaré après la dernière course : \(effort)/10.") }
        if let pain { facts.append("Gêne déclarée : \(pain)/10.") }

        let uncertainty = "RPE et gêne sont auto-déclarés. La montre ne mesure ni la douleur, ni la disponibilité à l'entraînement ; le volume ne suffit pas à estimer le risque de blessure."
        if (longitudinal.recent7MaximumDiscomfort ?? -1) >= 4 {
            return .init(priority: .discomfort, headline: "Récupération à réévaluer",
                         detail: "Une gêne significative a été déclarée au cours des 7 derniers jours. Ne force pas la progression ; réévalue la prochaine séance et demande un avis médical si la douleur persiste ou est importante.",
                         evidence: facts, uncertainty: uncertainty, sourceWorkoutID: last.source_uuid)
        }
        if effort == nil || pain == nil {
            return .init(priority: .feedback, headline: "Ton ressenti manque",
                         detail: "Ajoute ton effort perçu et une éventuelle gêne après la dernière course. Ces informations changent l'interprétation des données de ta montre.",
                         evidence: facts, uncertainty: uncertainty, sourceWorkoutID: last.source_uuid)
        }
        if longitudinal.recent7HighEffort >= 2 {
            return .init(priority: .review, headline: "Plusieurs séances exigeantes",
                         detail: "Au moins deux courses ont été déclarées très difficiles sur les 7 derniers jours. Vérifie la récupération et conserve la charge actuelle avant toute progression.",
                         evidence: facts, uncertainty: uncertainty, sourceWorkoutID: last.source_uuid)
        }
        if effort! >= 8 {
            return .init(priority: .review, headline: "Séance exigeante détectée",
                         detail: "Tu as déclaré un effort élevé. Le coach examinera la récupération avant toute modification ; le plan reste inchangé.",
                         evidence: facts, uncertainty: uncertainty, sourceWorkoutID: last.source_uuid)
        }
        // Internal attention flag for material 28-day shifts, not an injury-risk model.
        if let percent = longitudinal.comparisonPercent, percent >= 40 {
            return .init(priority: .review, headline: "Progression du volume à vérifier",
                         detail: "Le volume des 28 derniers jours a augmenté par rapport aux 28 précédents. Ce signal descriptif invite à vérifier la tolérance avant d'augmenter davantage.",
                         evidence: facts, uncertainty: uncertainty, sourceWorkoutID: last.source_uuid)
        }
        return .init(priority: .maintain, headline: "Poursuivre avec régularité",
                     detail: "Aucun signal prioritaire dans les mesures disponibles et ton dernier ressenti. Conserve le programme actuel, sans intensifier sur la base d'une seule bonne sortie.",
                     evidence: facts, uncertainty: uncertainty, sourceWorkoutID: last.source_uuid)
    }
}

@MainActor final class PaceLivingCoach: ObservableObject {
    @Published private(set) var brief: PaceLivingBrief = PaceLivingCoachRules.calculate(runs: [], notes: [:])
    @Published private(set) var updatedAt: Date?
    @Published private(set) var history: PaceLongitudinalSnapshot =
        PaceLongitudinalRules.calculate(runs: [], notes: [:])

    func refresh(engine: HealthSyncEngine, journal: PaceSessionJournal,
                 strength: PaceStrengthTracker) {
        let since = Date.now.addingTimeInterval(-7 * 86400)
        let completedSets = strength.completedSets(since: since)
        let nextHistory = PaceLongitudinalRules.calculate(runs: engine.runHistory,
                                                         notes: journal.notes)
        let next = PaceLivingCoachRules.calculate(runs: engine.runHistory,
                                                  notes: journal.notes,
                                                  completedStrengthSets: completedSets)
        if nextHistory != history || next != brief {
            history = nextHistory
            brief = next
            updatedAt = .now
        }
    }
}

/// Compact home signal: sources are always measured or explicitly reported,
/// and any adjustment remains behind the review/approval flow.
struct PaceLivingCoachCard: View {
    @EnvironmentObject private var living: PaceLivingCoach
    let onOpenCoach: () -> Void

    var body: some View {
        PaceCard {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Label("COACH ÉVOLUTIF", systemImage: "brain.head.profile")
                        .font(.caption.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(PaceColors.teal)
                    Spacer()
                    Text("LOCAL · ACTUALISÉ")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(living.brief.headline)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Text(living.brief.detail)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("4 semaines de course · km par 7 jours")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                HStack(alignment: .bottom, spacing: 10) {
                    let km = Array(living.history.weeklyKmNewestFirst.prefix(4).reversed())
                    let upper = max(km.max() ?? 0, 1)
                    ForEach(0..<km.count, id: \.self) { index in
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f", km[index]))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            Capsule()
                                .fill(PaceColors.teal.opacity(0.45 + Double(index) * 0.16))
                                .frame(height: max(5, CGFloat(km[index] / upper) * 32))
                            Text(index == 3 ? "Actuelle" : "S-\(3-index)")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Semaine \(index + 1), \(String(format: "%.1f", km[index])) kilomètres")
                    }
                }
                Text(living.history.evidenceQuality + " · " +
                     "\(living.history.feedbackCount28)/\(living.history.recent28Runs) ressentis complets")
                    .font(.caption2).foregroundStyle(.secondary)
                if let fact = living.brief.evidence.first {
                    Label(fact, systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption).foregroundStyle(PaceColors.teal)
                }
                Button(action: onOpenCoach) {
                    HStack {
                        Text(living.brief.priority == .feedback ? "Compléter mon ressenti" : "Voir l'analyse du coach")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }.font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(PaceColors.teal)
                .padding(.top, 3)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
