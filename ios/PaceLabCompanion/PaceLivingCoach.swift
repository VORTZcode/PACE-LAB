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
        let lastSeven = valid.filter { $0.startDate >= now.addingTimeInterval(-7 * 86400) }
        let lastTwentyEight = valid.filter { $0.startDate >= now.addingTimeInterval(-28 * 86400) }
        let previousTwentyOne = valid.filter {
            $0.startDate < now.addingTimeInterval(-7 * 86400) &&
            $0.startDate >= now.addingTimeInterval(-28 * 86400)
        }
        let weeklyKm = lastSeven.reduce(0.0) { $0 + $1.kilometers }
        let monthKm = lastTwentyEight.reduce(0.0) { $0 + $1.kilometers }
        let baselineWeekly = previousTwentyOne.reduce(0.0) { $0 + $1.kilometers } / 3.0
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
        let note = notes[last.source_uuid]
        let effort = note?.effort
        let pain = note?.pain
        if let effort { facts.append("Effort déclaré après la dernière course : \(effort)/10.") }
        if let pain { facts.append("Gêne déclarée : \(pain)/10.") }

        let uncertainty = "RPE et gêne sont auto-déclarés. La montre ne mesure ni la douleur, ni la disponibilité à l'entraînement ; le volume ne suffit pas à estimer le risque de blessure."
        if let pain, pain >= 4 {
            return .init(priority: .discomfort, headline: "Récupération à réévaluer",
                         detail: "Une gêne significative a été déclarée. N'augmente pas la charge ; examine la prochaine séance et demande un avis médical si la douleur persiste ou est importante.",
                         evidence: facts, uncertainty: uncertainty, sourceWorkoutID: last.source_uuid)
        }
        if effort == nil || pain == nil {
            return .init(priority: .feedback, headline: "Ton ressenti manque",
                         detail: "Ajoute ton effort perçu et une éventuelle gêne après la dernière course. Ces informations changent l'interprétation des données de ta montre.",
                         evidence: facts, uncertainty: uncertainty, sourceWorkoutID: last.source_uuid)
        }
        if effort! >= 8 {
            return .init(priority: .review, headline: "Séance exigeante détectée",
                         detail: "Tu as déclaré un effort élevé. Le coach examinera la récupération avant toute modification ; le plan reste inchangé.",
                         evidence: facts, uncertainty: uncertainty, sourceWorkoutID: last.source_uuid)
        }
        // The 1.4 ratio is an internal review trigger, not an evidence-based
        // injury threshold or a reason to automatically reduce training.
        if previousTwentyOne.count >= 3 && lastSeven.count >= 2 &&
           baselineWeekly > 0 && weeklyKm / baselineWeekly > 1.4 {
            facts.append("Volume sur 7 jours supérieur à 1,4 fois la moyenne hebdomadaire des 21 jours précédents (simple indicateur de variation).")
            return .init(priority: .review, headline: "Variation de volume à examiner",
                         detail: "Le volume récent a nettement changé. Vérifie fatigue et sensations avant d'envisager plus d'intensité.",
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

    func refresh(engine: HealthSyncEngine, journal: PaceSessionJournal,
                 strength: PaceStrengthTracker) {
        let since = Date.now.addingTimeInterval(-7 * 86400)
        let completedSets = strength.completedSets(since: since)
        let next = PaceLivingCoachRules.calculate(runs: engine.runHistory,
                                                  notes: journal.notes,
                                                  completedStrengthSets: completedSets)
        if next != brief { brief = next; updatedAt = .now }
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
