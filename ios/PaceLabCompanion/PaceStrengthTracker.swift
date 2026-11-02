import Foundation
import SwiftUI

/// One user-confirmed strength set. Apple Watch does not supply repetitions or dumbbell load.
struct PaceStrengthSet: Codable, Equatable {
    var repetitions: String = ""
    var weightKg: String = ""
    var completed: Bool = false
    var completedAt: Date?

    var actualRepetitions: Int? { Int(repetitions) }
    var actualWeightKg: Double? {
        Double(weightKg.replacingOccurrences(of: ",", with: "."))
    }
}

/// Stores strength set progress by session date, exercise and set number. All data stays on iPhone.
@MainActor final class PaceStrengthTracker: ObservableObject {
    @Published private(set) var records: [String: PaceStrengthSet] = [:]
    @Published private(set) var saveError: String?

    private let url: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = directory.appendingPathComponent("pace-strength-sets.json")
        if let bytes = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([String: PaceStrengthSet].self, from: bytes) {
            records = saved
        }
    }

    func entry(day: String, exerciseID: String, set: Int) -> PaceStrengthSet {
        records[key(day: day, exerciseID: exerciseID, set: set)] ?? PaceStrengthSet()
    }

    func completedSets(day: String, exercises: [PaceExercise]) -> Int {
        exercises.reduce(0) { subtotal, exercise in
            subtotal + (1...max(0, exercise.sets)).filter {
                entry(day: day, exerciseID: exercise.id, set: $0).completed
            }.count
        }
    }

    func totalSets(exercises: [PaceExercise]) -> Int {
        exercises.reduce(0) { $0 + max(0, $1.sets) }
    }

    func completedSets(day: String, exercise: PaceExercise) -> Int {
        (1...max(0, exercise.sets)).filter {
            entry(day: day, exerciseID: exercise.id, set: $0).completed
        }.count
    }

    func setCompleted(_ done: Bool, day: String, exerciseID: String, set: Int) {
        update(day: day, exerciseID: exerciseID, set: set) { record in
            record.completed = done
            record.completedAt = done ? Date() : nil
        }
    }

    func setRepetitions(_ value: String, day: String, exerciseID: String, set: Int) {
        let digits = String(value.filter(\.isNumber).prefix(3))
        update(day: day, exerciseID: exerciseID, set: set) { $0.repetitions = digits }
    }

    func setWeight(_ value: String, day: String, exerciseID: String, set: Int) {
        let filtered = String(value.filter { $0.isNumber || $0 == "," || $0 == "." }.prefix(8))
        // Keep partially entered decimals, such as "8,"; normalize for analysis only.
        update(day: day, exerciseID: exerciseID, set: set) { $0.weightKg = filtered }
    }

    private func key(day: String, exerciseID: String, set: Int) -> String {
        "\(day)|\(exerciseID)|\(set)"
    }

    private func update(day: String, exerciseID: String, set: Int,
                        transform: (inout PaceStrengthSet) -> Void) {
        guard !day.isEmpty, !exerciseID.isEmpty, (1...20).contains(set) else { return }
        let identifier = key(day: day, exerciseID: exerciseID, set: set)
        var record = records[identifier] ?? PaceStrengthSet()
        transform(&record)
        records[identifier] = record
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(records)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
            saveError = nil
        } catch {
            saveError = "Impossible d'enregistrer les séries sur cet iPhone."
        }
    }
}
