import Foundation
import SwiftUI
import HealthKit

// Only training content is shipped in the app bundle. No personal HealthKit data is in Git.
struct PaceProgramme: Decodable {
    let plan: [PaceDay]
    let force: [PaceExercise]
    let recipes: [PaceRecipe]
}
struct PaceDay: Decodable, Identifiable {
    var id: String { date }
    let date: String
    let day: String
    let type: String
    let title: String
    let minutes: Double
    let intensity: String
    let objective: String
    let instructions: String
    let lunch: String
    let dinner: String
    let kcal: Double
    let protein: Double
    let status: String
}
struct PaceExercise: Decodable, Identifiable {
    var id: String { day + "|" + name }
    let day: String
    let block: String
    let name: String
    let sets: Int
    let reps: String
    let tempo: String
    let rest: Double
    let rir: Int
    let tips: String
    let easier: String
    let harder: String
}
struct PaceRecipe: Decodable, Identifiable {
    var id: String { day + "|" + meal }
    let day: String
    let meal: String
    let name: String
    let ingredients: String
    let method: String
    let kcal: Double
    let protein: Double
    let notes: String
}

struct PaceBodyLog: Identifiable, Codable {
    let id: UUID
    let date: Date
    let weightKg: Double?
    let waistCm: Double?
}
@MainActor final class PaceLibrary: ObservableObject {
    let programme: PaceProgramme
    @Published private(set) var completed: Set<String>
    @Published private(set) var eaten: Set<String>
    @Published private(set) var shoppingChecked: Set<String>
    @Published private(set) var bodyLogs: [PaceBodyLog]
    @Published private(set) var activeCoachDraft: PaceAICoachDraft?

    init() {
        if let file = Bundle.main.url(forResource: "pace-programme", withExtension: "json", subdirectory: "AppData"),
           let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode(PaceProgramme.self, from: data) {
            programme = decoded
        } else {
            programme = PaceProgramme(plan: [], force: [], recipes: [])
        }
        completed = Set(UserDefaults.standard.stringArray(forKey: "pace.v2.completed") ?? [])
        eaten = Set(UserDefaults.standard.stringArray(forKey: "pace.v2.eaten") ?? [])
        shoppingChecked = Set(UserDefaults.standard.stringArray(forKey: "pace.v2.shopping") ?? [])
        let raw = UserDefaults.standard.data(forKey: "pace.v2.body")
        bodyLogs = raw.flatMap { try? JSONDecoder().decode([PaceBodyLog].self, from: $0) } ?? []
        activeCoachDraft = UserDefaults.standard.data(forKey:"pace.coach.approved")
            .flatMap { try? JSONDecoder().decode(PaceAICoachDraft.self,from:$0) }
    }
    func toggleDay(_ id: String) {
        if !completed.insert(id).inserted { completed.remove(id) }
        UserDefaults.standard.set(Array(completed), forKey: "pace.v2.completed")
    }
    func toggleMeal(_ id: String) {
        if !eaten.insert(id).inserted { eaten.remove(id) }
        UserDefaults.standard.set(Array(eaten), forKey: "pace.v2.eaten")
    }
    func toggleGrocery(_ id: String) {
        if !shoppingChecked.insert(id).inserted { shoppingChecked.remove(id) }
        UserDefaults.standard.set(Array(shoppingChecked), forKey: "pace.v2.shopping")
    }
    func setGroceries(_ ids: [String], checked: Bool) {
        for id in ids {
            if checked { shoppingChecked.insert(id) }
            else { shoppingChecked.remove(id) }
        }
        UserDefaults.standard.set(Array(shoppingChecked), forKey: "pace.v2.shopping")
    }
    func clearGrocery() {
        shoppingChecked.removeAll()
        UserDefaults.standard.set([], forKey: "pace.v2.shopping")
    }
    func saveBody(date: Date, weight: Double?, waist: Double?) {
        let value = PaceBodyLog(id: UUID(), date: date, weightKg: weight, waistCm: waist)
        bodyLogs.append(value)
        bodyLogs.sort { $0.date < $1.date }
        if let data = try? JSONEncoder().encode(bodyLogs) {
            UserDefaults.standard.set(data, forKey: "pace.v2.body")
        }
    }
    var currentPlan: [PaceDay] {
        guard let draft = activeCoachDraft else { return programme.plan }
        return draft.training.sorted { $0.date < $1.date }.map { $0.asPaceDay(meals:draft.meals) }
    }
    var currentRecipes: [PaceRecipe] {
        guard let draft = activeCoachDraft else { return programme.recipes }
        return draft.meals.sorted { ($0.date, $0.meal) < ($1.date, $1.meal) }.map { $0.asRecipe() }
    }
    func acceptCoachDraft(_ draft: PaceAICoachDraft) throws {
        try draft.validate()
        let data = try JSONEncoder().encode(draft)
        UserDefaults.standard.set(data,forKey:"pace.coach.approved")
        activeCoachDraft = draft
        // The old plan's grocery checklist must not silently cross over to new ingredients.
        shoppingChecked.removeAll()
        UserDefaults.standard.set([],forKey:"pace.v2.shopping")
    }
    func revertCoachPlan() {
        UserDefaults.standard.removeObject(forKey:"pace.coach.approved")
        activeCoachDraft = nil
        shoppingChecked.removeAll()
        UserDefaults.standard.set([],forKey:"pace.v2.shopping")
    }
    var completedCount: Int { currentPlan.filter { completed.contains($0.date) }.count }
    var nextDay: PaceDay? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: .now)
        guard let last = currentPlan.last, today <= last.date else { return nil }
        return currentPlan.first(where: { $0.date >= today && !completed.contains($0.date) })
    }
}

extension WorkoutPayload: Identifiable {
    var id: String { source_uuid }
    var startDate: Date { PaceFormat.iso.date(from: started_at) ?? .distantPast }
    var endDate: Date { PaceFormat.iso.date(from: ended_at) ?? .distantPast }
    var kilometers: Double { (distance_meters ?? 0) / 1000 }
    var isRun: Bool { activity_kind == "running" }
    var cadenceLabel: String { activity_kind == "running" ? "Course à pied" : (activity_kind == "walking" ? "Marche" : activity_kind == "cycling" ? "Vélo" : activity_kind == "strength" ? "Renforcement" : "Activité") }
    var symbol: String { activity_kind == "running" ? "figure.run" : activity_kind == "walking" ? "figure.walk" : activity_kind == "cycling" ? "bicycle" : activity_kind == "strength" ? "dumbbell.fill" : "figure.mixed.cardio" }
    var paceMinutes: Double? {
        guard kilometers > 0.05, duration_seconds > 0 else { return nil }
        return duration_seconds / 60 / kilometers
    }
}

enum PaceFormat {
    static let iso = ISO8601DateFormatter()
    static func distance(_ km: Double, places: Int = 1) -> String {
        km.formatted(.number.precision(.fractionLength(places)).locale(Locale(identifier: "fr_FR")))
    }
    static func heart(_ bpm: Double?) -> String {
        guard let bpm, bpm > 0 else { return "—" }
        return "\(Int(bpm.rounded()))"
    }
    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? "\(h) h \(String(format: "%02d", m))" : "\(m) min"
    }
    static func pace(_ value: Double?) -> String {
        guard let value, value.isFinite, value > 0 else { return "—" }
        let sec = Int((value * 60).rounded())
        return "\(sec / 60):\(String(format: "%02d", sec % 60))"
    }
    static func date(_ date: Date) -> String { date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR"))) }
    static func fullDate(_ date: Date) -> String { date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(Locale(identifier: "fr_FR"))) }
}

enum PaceColors {
    static let teal = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.36, green: 0.80, blue: 0.71, alpha: 1)
        : UIColor(red: 0.10, green: 0.43, blue: 0.38, alpha: 1)
    })
    static let base = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let muted = Color(uiColor: .secondaryLabel)
}

extension HealthSyncEngine {
    var runHistory: [WorkoutPayload] { snapshot.filter(\.isRun) }
    func totalDistance(year: Int) -> Double {
        runHistory.filter { Calendar.current.component(.year, from: $0.startDate) == year }
            .reduce(0) { $0 + $1.kilometers }
    }
    func runs(year: Int) -> [WorkoutPayload] {
        runHistory.filter { Calendar.current.component(.year, from: $0.startDate) == year }
    }
}
