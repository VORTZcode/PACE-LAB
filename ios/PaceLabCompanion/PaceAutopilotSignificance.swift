import Foundation

/// Independent, observable domains. Subjective effort and pain are ONE
/// self-reported domain, not two independent reasons to alter a plan.
struct PaceAutopilotEvidence: Equatable {
    let id: String
    let statement: String
}

enum PaceAutopilotSignificance {
    static func evidence(note: PaceSessionNote?,
                         trend: PaceLongitudinalSnapshot,
                         sleep: PaceSleepSummary) -> [PaceAutopilotEvidence] {
        var result: [PaceAutopilotEvidence] = []
        if let effort = note?.effort, (8...10).contains(effort) {
            result.append(.init(id:"subjective",
                statement:"Effort perçu élevé : \(effort)/10 (déclaration de l'athlète)."))
        } else if let pain = note?.pain, (1...3).contains(pain) {
            result.append(.init(id:"subjective",
                statement:"Gêne légère déclarée : \(pain)/10 (même domaine que le ressenti)."))
        }
        // The 40% threshold is a conservative *review* convention, not a
        // clinical injury-risk predictor. ComparisonPercent is nil when
        // there is insufficient history across the previous 56 days.
        if let percent = trend.comparisonPercent, percent > 40 {
            result.append(.init(id:"training",
                statement:String(format:"Volume des 28 derniers jours supérieur de %.0f %% aux 28 précédents.",percent)))
        }
        // Compare against this athlete's own previous week, with minimum
        // coverage; a single poor night or generic 6h threshold never triggers.
        if sleep.coverage7 >= 4, sleep.coverage14 >= 10,
           let recent=sleep.mostRecent7AverageMinutes,
           let previous=sleep.previous7AverageMinutes,
           recent <= previous - 45, recent < 420 {
            result.append(.init(id:"sleep",
                statement:"Sommeil moyen récent \(recent) min contre \(previous) min précédemment, \(sleep.coverage7)/7 nuits observées."))
        }
        return result
    }

    static func reconcile(action: String,
                          claimedEvidenceIDs: [String],
                          supported: [PaceAutopilotEvidence]) -> Bool {
        guard action == "easier" else { return false }
        let ids=Set(claimedEvidenceIDs)
        let available=Set(supported.map(\.id))
        // Two independent sources, exactly grounded in source IDs; prevents
        // the model double-counting different metrics from the same workout.
        return ids.count >= 2 && ids.isSubset(of:available)
    }
}
