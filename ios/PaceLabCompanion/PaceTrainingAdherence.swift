import Foundation

/// Pure, deterministic plan-to-workout reconciliation. A date/type coincidence
/// is never proof that the prescribed intensity, sets or duration were done.
struct PaceTrainingPlanEntry {
    let date: String
    let type: String
    let minutes: Double
}

struct PaceTrainingWorkoutEntry {
    let uuid: String
    let day: String
    let kind: String
    let seconds: Double
}

enum PaceTrainingEvidenceState: String {
    case confirmedWorkout, manuallyCompleted, missed, candidate, ambiguous
    case noRecording, recoveryDay
}

struct PaceTrainingDayEvidence {
    let date: String
    let state: PaceTrainingEvidenceState
    let workoutUUID: String?
    let plannedMinutes: Double
    let actualMinutes: Double?
}

struct PaceTrainingAdherenceSnapshot {
    let entries: [PaceTrainingDayEvidence]
    var confirmed: Int { entries.filter { $0.state == .confirmedWorkout }.count }
    var selfReported: Int { entries.filter { $0.state == .manuallyCompleted }.count }
    var missed: Int { entries.filter { $0.state == .missed }.count }
    var ambiguous: Int { entries.filter { $0.state == .ambiguous }.count }
    var unconfirmedCandidates: Int { entries.filter { $0.state == .candidate }.count }
    var plannedTrainingCount: Int {
        entries.filter { $0.state != .recoveryDay }.count
    }

    var coachSummary: String {
        "SUIVI DU PROGRAMME (calcul local) : \(plannedTrainingCount) séances sportives prévues ; \(confirmed) explicitement liées à une activité Apple Santé ; \(selfReported) validées manuellement sans liaison démontrée ; \(missed) déclarées non réalisées ; \(unconfirmedCandidates) activités plausibles encore non associées ; \(ambiguous) jours comportant plusieurs activités possibles. Une date identique ne prouve jamais la réalisation des intensités ou exercices prescrits. Ne pas compenser automatiquement les séances manquées."
    }
}

enum PaceTrainingAdherence {
    static func calculate(planned: [PaceTrainingPlanEntry],
                          workouts: [PaceTrainingWorkoutEntry],
                          confirmedUUIDByDay: [String: String],
                          completed: Set<String>,
                          missed: Set<String>) -> PaceTrainingAdherenceSnapshot {
        let validKinds = ["Course": "running", "Musculation": "strength"]
        let workoutByUUID = Dictionary(
            workouts.filter { !$0.uuid.isEmpty }.map { ($0.uuid, $0) },
            uniquingKeysWith: { first, _ in first })
        let entries: [PaceTrainingDayEvidence] = planned.map { item in
            guard let kind = validKinds[item.type] else {
                return .init(date: item.date, state: .recoveryDay, workoutUUID: nil,
                             plannedMinutes: item.minutes, actualMinutes: nil)
            }
            let candidates = workouts.filter { $0.day == item.date && $0.kind == kind }
            if missed.contains(item.date) {
                return .init(date: item.date, state: .missed, workoutUUID: nil,
                             plannedMinutes: item.minutes, actualMinutes: nil)
            }
            if let linked = confirmedUUIDByDay[item.date],
               let workout = workoutByUUID[linked],
               workout.day == item.date && workout.kind == kind {
                return .init(date: item.date, state: .confirmedWorkout,
                             workoutUUID: linked, plannedMinutes: item.minutes,
                             actualMinutes: workout.seconds / 60)
            }
            if completed.contains(item.date) {
                // A tap on "done" does not verify a matching Apple Watch session.
                return .init(date: item.date, state: .manuallyCompleted,
                             workoutUUID: nil, plannedMinutes: item.minutes,
                             actualMinutes: nil)
            }
            if candidates.count > 1 {
                return .init(date: item.date, state: .ambiguous,
                             workoutUUID: nil, plannedMinutes: item.minutes,
                             actualMinutes: nil)
            }
            if let candidate = candidates.first {
                return .init(date: item.date, state: .candidate,
                             workoutUUID: candidate.uuid,
                             plannedMinutes: item.minutes,
                             actualMinutes: candidate.seconds / 60)
            }
            return .init(date: item.date, state: .noRecording,
                         workoutUUID: nil, plannedMinutes: item.minutes,
                         actualMinutes: nil)
        }
        return .init(entries: entries)
    }
}
