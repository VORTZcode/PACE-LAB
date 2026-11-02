import Foundation

/// Explainable 56-day training history. Pure calculation: no external AI, no medical scoring.
struct PaceLongitudinalSnapshot: Equatable {
    let weeklyKmNewestFirst: [Double]
    let weeklyRunsNewestFirst: [Int]
    let recent28Km: Double
    let previous28Km: Double
    let recent28Runs: Int
    let previous28Runs: Int
    let last7Km: Double
    let recent7HighEffort: Int
    let recent7MaximumDiscomfort: Int?
    let feedbackCount28: Int
    let missingFeedback28: Int
    let comparisonPercent: Double?
    let evidenceQuality: String
    let interpretation: String

    var evidence: [String] {
        var result = [
            "Volumes des quatre périodes de 7 jours, de la plus récente à la plus ancienne : " +
                weeklyKmNewestFirst.prefix(4).map { String(format: "%.1f", $0) }.joined(separator: " / ") + " km.",
            "\(recent28Runs) courses et \(String(format: "%.1f", recent28Km)) km sur 28 jours.",
            "Ressenti complet sur \(feedbackCount28)/\(recent28Runs) courses récentes (\(missingFeedback28) à compléter)."
        ]
        if let comparisonPercent {
            result.append("Évolution du volume sur 28 jours par rapport aux 28 précédents : \(String(format: "%+.0f", comparisonPercent)) %.")
        }
        if recent7HighEffort > 0 {
            result.append("\(recent7HighEffort) effort(s) perçu(s) à 8/10 ou davantage sur 7 jours.")
        }
        if let recent7MaximumDiscomfort {
            result.append("Gêne maximale déclarée sur 7 jours : \(recent7MaximumDiscomfort)/10.")
        }
        return result
    }

    var promptContext: String {
        ("HISTORIQUE LONGITUDINAL LOCAL (mesures descriptives uniquement, pas de score de récupération).\n" +
         evidence.joined(separator: "\n") +
         "\nQualité de données : \(evidenceQuality). \(interpretation)\n" +
         "Les données manquantes sont inconnues ; aucune augmentation de charge n'est automatique.")
    }
}

enum PaceLongitudinalRules {
    static func calculate(runs: [WorkoutPayload],
                          notes: [String: PaceSessionNote],
                          now: Date = .now) -> PaceLongitudinalSnapshot {
        let lower = now.addingTimeInterval(-56 * 86400)
        // HealthKit can return the same workout more than once after resync.
        // Require valid times and positive, finite distance and duration.
        var deduplicated: [String: WorkoutPayload] = [:]
        for run in runs where run.isRun &&
            run.startDate >= lower && run.startDate <= now &&
            run.endDate <= now && run.endDate >= run.startDate &&
            run.kilometers.isFinite && run.kilometers > 0 &&
            run.duration_seconds.isFinite && run.duration_seconds > 0 {
            guard !run.source_uuid.isEmpty else { continue }
            if let previous = deduplicated[run.source_uuid],
               previous.endDate >= run.endDate { continue }
            deduplicated[run.source_uuid] = run
        }
        let valid = Array(deduplicated.values)
        let bucket: [[WorkoutPayload]] = (0..<8).map { index in
            let upper = now.addingTimeInterval(-Double(index * 7 * 86400))
            let lower = upper.addingTimeInterval(-7 * 86400)
            return valid.filter { $0.startDate >= lower && $0.startDate < upper }
        }
        let km = bucket.map { $0.reduce(0.0) { $0 + $1.kilometers } }
        let counts = bucket.map(\.count)
        let recent = bucket.prefix(4).flatMap { $0 }
        let previous = bucket.suffix(4).flatMap { $0 }
        let recentDistance = km.prefix(4).reduce(0, +)
        let previousDistance = km.suffix(4).reduce(0, +)
        let last7 = bucket[0]
        let highEffort = last7.filter {
            guard let value = notes[$0.source_uuid]?.effort else { return false }
            return (8...10).contains(value)
        }.count
        let discomfort = last7.compactMap { notes[$0.source_uuid]?.pain }
            .filter { (0...10).contains($0) }.max()
        let complete = recent.filter { run in
            guard let note = notes[run.source_uuid],
                  let effort = note.effort, let pain = note.pain else { return false }
            return (1...10).contains(effort) && (0...10).contains(pain)
        }.count
        // A percentage from one old workout would imply unsupported precision.
        let comparable = previous.count >= 4 &&
            bucket.suffix(4).filter { !$0.isEmpty }.count >= 3 &&
            recent.count >= 4 &&
            bucket.prefix(4).filter { !$0.isEmpty }.count >= 3 &&
            previousDistance >= 5
        let percent = comparable ? ((recentDistance - previousDistance) / previousDistance) * 100 : nil
        let quality: String
        let interpretation: String
        if recent.count < 4 {
            quality = "Historique limité"
            interpretation = "Moins de quatre courses sur 28 jours : ne pas extrapoler une tendance."
        } else if percent == nil {
            quality = "Tendance courte"
            interpretation = "Comparaison sur 56 jours indisponible ou périodes trop irrégulières."
        } else {
            quality = "Comparaison descriptive sur 56 jours"
            interpretation = "La variation de volume n'établit ni aptitude ni risque de blessure ; croiser avec le ressenti."
        }
        return .init(weeklyKmNewestFirst: km, weeklyRunsNewestFirst: counts,
                     recent28Km: recentDistance, previous28Km: previousDistance,
                     recent28Runs: recent.count, previous28Runs: previous.count,
                     last7Km: km[0], recent7HighEffort: highEffort,
                     recent7MaximumDiscomfort: discomfort,
                     feedbackCount28: complete,
                     missingFeedback28: recent.count - complete,
                     comparisonPercent: percent, evidenceQuality: quality,
                     interpretation: interpretation)
    }
}
