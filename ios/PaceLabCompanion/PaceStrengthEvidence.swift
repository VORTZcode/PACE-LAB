import Foundation

struct PaceMeasuredStrengthSet {
    let name: String
    let completedAt: Date
    let isTimed: Bool
    let countOrSeconds: Int
    let weightKg: Double?
}

struct PaceStrengthExerciseEvidence: Identifiable {
    let id: String
    let name: String
    let sessions: Int
    let completedSets: Int
    let maxRepetitions: Int?
    let maxDurationSeconds: Int?
    let maxWeightKg: Double?
    let indicativeVolumeKgReps: Double?
    let lastDate: Date
}

/// Reports recorded work, never infers muscle gain from weight or set volume.
enum PaceStrengthEvidence {
    static func summarize(_ raw: [PaceMeasuredStrengthSet],
                          at now: Date = .now) -> [PaceStrengthExerciseEvidence] {
        let valid = raw.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.completedAt <= now &&
            $0.completedAt >= now.addingTimeInterval(-180 * 86400) &&
            (1...3600).contains($0.countOrSeconds) &&
            (!$0.isTimed || $0.countOrSeconds <= 900) &&
            ($0.weightKg == nil ||
             ($0.weightKg!.isFinite && (0...250).contains($0.weightKg!)))
        }
        let grouped = Dictionary(grouping: valid) {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        return grouped.compactMap { key, sets -> PaceStrengthExerciseEvidence? in
            guard let last = sets.max(by: { $0.completedAt < $1.completedAt }) else { return nil }
            let isTimed = sets.allSatisfy(\.isTimed)
            let reps = isTimed ? [] : sets.filter { !$0.isTimed }.map(\.countOrSeconds)
            let duration = isTimed ? sets.map(\.countOrSeconds) : []
            let loads = sets.filter { !$0.isTimed }
                .compactMap(\.weightKg)
            let volume = sets.filter { !$0.isTimed && $0.weightKg != nil }
                .reduce(0.0) { $0 + Double($1.countOrSeconds) * $1.weightKg! }
            let distinctDays = Set(sets.map {
                Calendar.current.startOfDay(for: $0.completedAt)
            })
            return .init(id: key, name: last.name,
                         sessions: distinctDays.count, completedSets: sets.count,
                         maxRepetitions: reps.max(),
                         maxDurationSeconds: duration.max(),
                         maxWeightKg: loads.max(),
                         indicativeVolumeKgReps: loads.isEmpty ? nil : volume,
                         lastDate: last.completedAt)
        }.sorted { $0.lastDate > $1.lastDate }
    }
}
