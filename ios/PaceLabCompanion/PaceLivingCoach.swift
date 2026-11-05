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

/// One actionable fact, never a miniature dashboard competing with the
/// next workout. Routine maintenance and missing optional data stay silent.
struct PaceLivingCoachCard: View {
    @EnvironmentObject private var living: PaceLivingCoach
    @EnvironmentObject private var coach: PaceCoachEngine
    @EnvironmentObject private var autopilot: PaceAutopilot
    @EnvironmentObject private var library: PaceLibrary
    @EnvironmentObject private var engine: HealthSyncEngine
    let onOpenCoach: () -> Void

    private struct Signal {
        let title: String
        let detail: String
        let origin: String
        let symbol: String
        let action: String
    }

    private var signal: Signal? {
        let now = Date.now
        // A safety concern outranks a routine activity report.
        if let decision=autopilot.entries.first(where: {
            $0.action == "à examiner" && now.timeIntervalSince($0.date) < 4*86400
        }) {
            return .init(title:"Une décision demande ton attention",
                         detail:decision.headline,origin:"COACH",symbol:"exclamationmark.shield",
                         action:"Voir pourquoi")
        }
        if let accepted=autopilot.entries.first(where:{
            $0.action == "allègement" && now.timeIntervalSince($0.date) < 5*86400 &&
            $0.sessionDate.map { library.approvedAdjustments[$0] != nil } == true
        }) {
            return .init(title:"Prochaine séance ajustée",
                         detail:accepted.headline,origin:"COACH",symbol:"calendar.badge.clock",
                         action:"Voir l'adaptation")
        }
        if let planned=coach.pending {
            return .init(title:"La semaine suivante est prête",
                         detail:String(planned.summary.prefix(160)),origin:"À VALIDER",
                         symbol:"calendar.badge.checkmark",action:"Examiner le programme")
        }
        if let latest=engine.snapshot.first,
           now.timeIntervalSince(latest.endDate) < 3*86400,
           let report=coach.report(for:latest.source_uuid), !report.isLocal {
            return .init(title:"Bilan de séance disponible",
                         detail:String(report.summary.prefix(210)),origin:"ANALYSE CHATGPT",
                         symbol:"waveform.path.ecg",action:"Lire le bilan")
        }
        if living.brief.priority == .discomfort {
            return .init(title:"Récupération à réévaluer",
                         detail:"Une gêne significative a été déclarée récemment.",
                         origin:"RESSENTI",symbol:"exclamationmark.shield",
                         action:"Examiner la situation")
        }
        if living.brief.priority == .feedback,
           let last=engine.runHistory.first,
           now.timeIntervalSince(last.endDate) < 36*3600 {
            return .init(title:"Un ressenti manque",
                         detail:"Ton effort perçu aide à interpréter la dernière course.",
                         origin:"À COMPLÉTER",symbol:"square.and.pencil",
                         action:"Ajouter mon ressenti")
        }
        if coach.automaticNeedsAttentionCount > 0 {
            return .init(title:"Analyse à reprendre",
                         detail:"Une activité n'a pas pu être analysée après plusieurs essais.",
                         origin:"COACH",symbol:"arrow.clockwise.circle",
                         action:"Voir les détails")
        }
        return nil
    }

    var body: some View {
        if let signal {
            PaceCard(padding:17) {
                VStack(alignment:.leading,spacing:9) {
                    HStack(spacing:8) {
                        Image(systemName:signal.symbol).foregroundStyle(PaceColors.teal)
                        Text(signal.origin)
                            .font(.caption2.weight(.bold)).tracking(0.8)
                            .foregroundStyle(.secondary)
                        Spacer(minLength:0)
                    }
                    Text(signal.title)
                        .font(.headline).foregroundStyle(.primary)
                    Text(signal.detail)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .lineLimit(2)
                    Button(action:onOpenCoach) {
                        HStack {
                            Text(signal.action)
                            Spacer()
                            Image(systemName:"arrow.up.right")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PaceColors.teal)
                }
            }
        }
    }
}
