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
            subtotal + (0..<max(0, exercise.sets)).filter {
                entry(day: day, exerciseID: exercise.id, set: $0 + 1).completed
            }.count
        }
    }

    func completedSets(since date: Date, until now: Date = .now) -> Int {
        records.values.filter { $0.completed && ($0.completedAt.map { $0 >= date && $0 <= now } ?? false) }.count
    }

    func totalSets(exercises: [PaceExercise]) -> Int {
        exercises.reduce(0) { $0 + max(0, $1.sets) }
    }

    func completedSets(day: String, exercise: PaceExercise) -> Int {
        (0..<max(0, exercise.sets)).filter {
            entry(day: day, exerciseID: exercise.id, set: $0 + 1).completed
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

    /// Optional, user-authorized coach context. No inferred Apple Watch repetitions.
    func coachSummary(library: PaceLibrary) -> String {
        var items: [String] = []
        for day in library.currentPlan.filter({ $0.type == "Musculation" }).suffix(7) {
            for exercise in library.programme.force.filter({ $0.day == day.day }) {
                for index in 0..<max(0, exercise.sets) {
                    let number = index + 1
                    let value = entry(day: day.date, exerciseID: exercise.id, set: number)
                    guard value.completed || !value.repetitions.isEmpty ||
                          !value.weightKg.isEmpty else { continue }
                    let unit = exercise.isTimed ? "secondes" : "répétitions"
                    let measure = value.repetitions.isEmpty
                        ? "valeur non renseignée" : "\(value.repetitions) \(unit)"
                    let load = exercise.tracksLoad && !value.weightKg.isEmpty
                        ? ", charge \(value.weightKg) kg" : ""
                    let status = value.completed ? "validée" : "non validée"
                    items.append("\(day.date), \(exercise.name), série \(number) : \(measure)\(load) (\(status))")
                    if items.count >= 60 { break }
                }
                if items.count >= 60 { break }
            }
            if items.count >= 60 { break }
        }
        guard !items.isEmpty else { return "Aucune série de musculation saisie manuellement dans le programme actuel." }
        return (["HISTORIQUE DE MUSCULATION SAISI PAR L'UTILISATEUR (pas mesuré par l'Apple Watch).",
                 "Les exercices chronométrés sont exprimés en secondes, jamais en répétitions ; ne pas inventer de charge absente."] + items).joined(separator: "\n")
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
