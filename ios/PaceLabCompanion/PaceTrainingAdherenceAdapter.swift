import Foundation

/// Connects PACE LAB's current plan and confirmed user links to the pure
/// training-adherence engine. All date matching uses the athlete's local day.
@MainActor enum PaceTrainingAdherenceAdapter {
    static func snapshot(library: PaceLibrary, engine: HealthSyncEngine,
                         runLinks: PaceRunWorkoutLinks = .shared,
                         strengthLinks: PaceStrengthWorkoutLinks = .shared) -> PaceTrainingAdherenceSnapshot {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        let plan = library.currentPlan.map {
            PaceTrainingPlanEntry(date: $0.date, type: $0.type, minutes: $0.minutes)
        }
        let workouts = engine.snapshot.map {
            PaceTrainingWorkoutEntry(uuid: $0.source_uuid,
                day: formatter.string(from: $0.startDate),
                kind: $0.activity_kind, seconds: $0.duration_seconds)
        }
        var confirmed = strengthLinks.byDay
        for (day, workoutID) in runLinks.byDay { confirmed[day] = workoutID }
        return PaceTrainingAdherence.calculate(
            planned: plan, workouts: workouts,
            confirmedUUIDByDay: confirmed,
            completed: library.completed,
            missed: Set(library.missedSessions.keys)
        )
    }
}
