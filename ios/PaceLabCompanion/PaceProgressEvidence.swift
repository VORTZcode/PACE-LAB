import Foundation

/// Pure, on-device calculations. This layer never sends HealthKit data to GPT.
/// It distinguishes recorded volume from evidence of physiological progress.
struct PaceProgressWindow {
    let runCount: Int
    let distanceKm: Double
    let activeWeeks: Int
}

struct PaceRunComparison {
    let currentID: String
    let priorID: String
    let priorDate: Date
    let currentKm: Double
    let priorKm: Double
    /// Negative means that the more recent run had a lower (faster) pace.
    let paceDifferenceSecondsPerKm: Double
    let heartDifferenceBPM: Double?
    let comparableHeartRate: Bool

    var evidenceLabel: String {
        if comparableHeartRate {
            return "Distance proche et FC moyenne similaire ; pente, météo et effort ressenti restent inconnus."
        }
        return "Distance proche uniquement : intensité et conditions potentiellement différentes."
    }
}

struct PaceRunDistanceMilestone: Identifiable {
    var id: Int { targetKm }
    let targetKm: Int
    let sourceUUID: String
    let date: Date
    let distanceKm: Double
    let paceSecondsPerKm: Double
    /// Not a split, race result or GPS segment record.
    var description: String { "Meilleure allure sur une sortie complète de distance proche" }
}

struct PaceProgressSnapshot {
    let current28: PaceProgressWindow
    let previous28: PaceProgressWindow
    let comparison: PaceRunComparison?
    let latestRunID: String?
    let validHistoryCount: Int
    let milestones: [PaceRunDistanceMilestone]

    var hasTwoPeriods: Bool {
        current28.runCount > 0 && previous28.runCount > 0
    }
}

/// Dates are decoded from the original payload, not an optional UI timestamp.
/// Duplicate UUIDs, future workouts and obviously invalid speed samples are excluded.
enum PaceProgressEvidence {
    private struct Entry {
        let payload: WorkoutPayload
        let date: Date
        let km: Double
        let secondsPerKm: Double
    }

    private static func parseDate(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    private static func validRuns(_ workouts: [WorkoutPayload], at now: Date) -> [Entry] {
        var unique: [String: Entry] = [:]
        for workout in workouts where workout.activity_kind == "running" {
            guard !workout.source_uuid.isEmpty,
                  let date = parseDate(workout.started_at), date <= now,
                  let meters = workout.distance_meters,
                  meters.isFinite, workout.duration_seconds.isFinite,
                  (500...50000).contains(meters),
                  workout.duration_seconds >= 180,
                  workout.duration_seconds <= 10 * 3600 else { continue }
            let km = meters / 1000
            let pace = workout.duration_seconds / km
            guard (150...1200).contains(pace) else { continue }
            let entry = Entry(payload: workout, date: date, km: km, secondsPerKm: pace)
            if let previous = unique[workout.source_uuid] {
                if previous.payload.details_complete != true && workout.details_complete == true {
                    unique[workout.source_uuid] = entry
                }
            } else {
                unique[workout.source_uuid] = entry
            }
        }
        return unique.values.sorted {
            $0.date == $1.date ? $0.payload.source_uuid < $1.payload.source_uuid : $0.date > $1.date
        }
    }

    private static func summary(_ entries: [Entry], from start: Date, to end: Date,
                                calendar: Calendar) -> PaceProgressWindow {
        let selected = entries.filter { $0.date >= start && $0.date < end }
        let weeks = Set(selected.compactMap { entry -> Int? in
            guard let days = calendar.dateComponents([.day], from: start, to: entry.date).day,
                  (0..<28).contains(days) else { return nil }
            return days / 7
        })
        return PaceProgressWindow(runCount: selected.count,
                                  distanceKm: selected.reduce(0) { $0 + $1.km },
                                  activeWeeks: weeks.count)
    }

    static func snapshot(_ workouts: [WorkoutPayload],
                         at now: Date = .now,
                         calendar: Calendar = .current) -> PaceProgressSnapshot {
        let entries = validRuns(workouts, at: now)
        let recentStart = calendar.date(byAdding: .day, value: -28, to: now) ??
            now.addingTimeInterval(-28 * 86400)
        let previousStart = calendar.date(byAdding: .day, value: -56, to: now) ??
            now.addingTimeInterval(-56 * 86400)
        let current = summary(entries, from: recentStart, to: now.addingTimeInterval(0.001),
                              calendar: calendar)
        let previous = summary(entries, from: previousStart, to: recentStart, calendar: calendar)
        let latest = entries.first
        let comparison = latest.flatMap { current in
            compare(current, against: entries)
        }
        return PaceProgressSnapshot(current28: current, previous28: previous,
                                    comparison: comparison,
                                    latestRunID: latest?.payload.source_uuid,
                                    validHistoryCount: entries.count,
                                    milestones: distanceMilestones(entries))
    }

    private static func distanceMilestones(_ entries: [Entry]) -> [PaceRunDistanceMilestone] {
        [3, 5, 10].compactMap { target -> PaceRunDistanceMilestone? in
            let candidates = entries.filter {
                abs($0.km - Double(target)) / Double(target) <= 0.03
            }
            // The full-workout pace is measured. It does NOT represent a 3/5/10 km split.
            guard let best = candidates.min(by: {
                if abs($0.secondsPerKm - $1.secondsPerKm) < 0.001 {
                    return $0.date > $1.date
                }
                return $0.secondsPerKm < $1.secondsPerKm
            }) else { return nil }
            return .init(targetKm: target, sourceUUID: best.payload.source_uuid,
                         date: best.date, distanceKm: best.km,
                         paceSecondsPerKm: best.secondsPerKm)
        }
    }

    /// The same comparison method is reused in the progress dashboard and the
    /// detailed activity sheet; no conflicting distance thresholds.
    static func comparison(for workout: WorkoutPayload, in workouts: [WorkoutPayload],
                           at now: Date = .now) -> PaceRunComparison? {
        let entries = validRuns(workouts, at: now)
        guard let selected = entries.first(where: {
            $0.payload.source_uuid == workout.source_uuid
        }) else { return nil }
        return compare(selected, against: entries)
    }

    private static func compare(_ latest: Entry, against entries: [Entry]) -> PaceRunComparison? {
        let candidates = entries.filter { prior in
            let elapsed = latest.date.timeIntervalSince(prior.date)
            let distanceRatio = abs(prior.km - latest.km) / latest.km
            return prior.payload.source_uuid != latest.payload.source_uuid &&
                elapsed >= 7 * 86400 && elapsed <= 120 * 86400 &&
                distanceRatio <= 0.10
        }
        // Prefer similar distance, then recent observations; no best-performance cherry-picking.
        guard let prior = candidates.min(by: { a, b in
            let gapA = abs(a.km - latest.km)
            let gapB = abs(b.km - latest.km)
            if abs(gapA - gapB) < 0.001 { return a.date > b.date }
            return gapA < gapB
        }) else { return nil }
        let a = latest.payload.hr_average_bpm
        let b = prior.payload.hr_average_bpm
        let bothHRValid = a.map { $0.isFinite && (40...230).contains($0) } == true &&
            b.map { $0.isFinite && (40...230).contains($0) } == true
        let heartDelta = bothHRValid ? a! - b! : nil
        let closeHeart = heartDelta.map { abs($0) <= 8 } ?? false
        return PaceRunComparison(currentID: latest.payload.source_uuid,
                                 priorID: prior.payload.source_uuid,
                                 priorDate: prior.date,
                                 currentKm: latest.km, priorKm: prior.km,
                                 paceDifferenceSecondsPerKm: latest.secondsPerKm - prior.secondsPerKm,
                                 heartDifferenceBPM: heartDelta,
                                 comparableHeartRate: closeHeart)
    }
}


extension PaceProgressSnapshot {
    /// The Coach receives these facts only inside the existing opt-in run-data block.
    /// It must not turn descriptive comparisons into claims of causality.
    var coachEvidenceContext: String {
        let recent = String(format: "%.1f", current28.distanceKm)
        let older = String(format: "%.1f", previous28.distanceKm)
        var facts = [
            "PROGRESSION FACTUELLE (calcul local, pas une décision IA) :",
            "28 derniers jours : \(current28.runCount) courses, \(recent) km, \(current28.activeWeeks)/4 semaines actives.",
            "28 jours précédents : \(previous28.runCount) courses, \(older) km.",
            "Ces deux volumes décrivent une charge enregistrée, pas un gain de capacité cardiovasculaire."
        ]
        if let c = comparison {
            let delta = Int(c.paceDifferenceSecondsPerKm.rounded())
            facts.append("Dernière course contre séance de distance similaire : écart d'allure \(delta) s/km. \(c.evidenceLabel)")
        } else {
            facts.append("Aucune course historique de distance suffisamment similaire pour comparaison descriptive récente.")
        }
        return facts.joined(separator: " ")
    }
}
