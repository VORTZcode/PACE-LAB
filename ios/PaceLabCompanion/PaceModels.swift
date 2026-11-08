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
    /// Timed exercises are logged in seconds, preserving already recorded values.
    let measurement_unit: String?
    let load_expected: Bool?
    var isTimed: Bool {
        if let measurement_unit { return measurement_unit == "seconds" }
        return reps.lowercased().contains(" s") || tempo.lowercased().contains("isométrique")
    }
    var tracksLoad: Bool {
        if let load_expected { return load_expected }
        return !name.lowercased().contains("planche")
    }
    var metricLabel: String { isTimed ? "Durée (s)" : "Répétitions" }
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

/// A planned session can be missed without being counted as completed.
struct PaceMissedSession: Codable, Equatable {
    let date: String
    let reason: String
    let note: String
    let recordedAt: Date
}

/// A dated, user-declared meal. This is not an observation of actual calories.
struct PaceMealDeclaration: Codable, Identifiable {
    let id: String
    let date: String
    let meal: String
    let recipeName: String
    let declaredAt: Date
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
    @Published private(set) var missedSessions: [String: PaceMissedSession] = [:]
    private var mealURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pace-dated-meal-declarations.json")
    }
    private var missedURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pace-missed-sessions.json")
    }
    private func persistMissed() {
        guard let bytes = try? JSONEncoder().encode(missedSessions) else { return }
        try? FileManager.default.createDirectory(at: missedURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if (try? bytes.write(to: missedURL, options: .atomic)) != nil {
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: missedURL.path)
        }
    }
    @Published private(set) var eaten: Set<String>
    @Published private(set) var mealDeclarations: [String: PaceMealDeclaration] = [:]
    @Published private(set) var mealSaveError: String?
    @Published private(set) var shoppingChecked: Set<String>
    @Published private(set) var bodyLogs: [PaceBodyLog]
    @Published private(set) var activeCoachDraft: PaceAICoachDraft?
    @Published private(set) var approvedAdjustments: [String:PaceApprovedAdjustment] = [:]
    private var adaptationURL: URL {
        FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
            .appendingPathComponent("pace-adaptive-approved.json")
    }
    private func persistAdaptations() {
        guard let data = try? JSONEncoder().encode(approvedAdjustments) else { return }
        try? FileManager.default.createDirectory(at:adaptationURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories:true)
        if (try? data.write(to:adaptationURL,options:.atomic)) != nil {
            try? FileManager.default.setAttributes(
                [.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath:adaptationURL.path)
        }
    }

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
        // Legacy weekday-only checkmarks have no date provenance. They are
        // retained in the old store but never imputed to the current week.

        shoppingChecked = Set(UserDefaults.standard.stringArray(forKey: "pace.v2.shopping") ?? [])
        let raw = UserDefaults.standard.data(forKey: "pace.v2.body")
        bodyLogs = raw.flatMap { try? JSONDecoder().decode([PaceBodyLog].self, from: $0) } ?? []
        activeCoachDraft = UserDefaults.standard.data(forKey:"pace.coach.approved")
            .flatMap { try? JSONDecoder().decode(PaceAICoachDraft.self,from:$0) }
        approvedAdjustments = (try? Data(contentsOf:adaptationURL))
            .flatMap { try? JSONDecoder().decode([String:PaceApprovedAdjustment].self,from:$0) } ?? [:]
        missedSessions = (try? Data(contentsOf: missedURL))
            .flatMap { try? JSONDecoder().decode([String: PaceMissedSession].self, from: $0) } ?? [:]
        missedSessions = missedSessions.filter { !completed.contains($0.key) }
        mealDeclarations = (try? Data(contentsOf: mealURL))
            .flatMap { try? JSONDecoder().decode(
                [String: PaceMealDeclaration].self, from: $0) } ?? [:]
    }
    func markDayCompleted(_ id: String) {
        if missedSessions.removeValue(forKey: id) != nil { persistMissed() }
        guard completed.insert(id).inserted else { return }
        UserDefaults.standard.set(Array(completed), forKey: "pace.v2.completed")
    }
    func toggleDay(_ id: String) {
        if !completed.insert(id).inserted {
            completed.remove(id)
        } else if missedSessions.removeValue(forKey: id) != nil {
            persistMissed()
        }
        UserDefaults.standard.set(Array(completed), forKey: "pace.v2.completed")
    }
    func markDayMissed(_ date: String, reason: String, note: String) {
        guard currentPlan.contains(where: { $0.date == date }) else { return }
        let allowed = ["Manque de temps", "Fatigue", "Douleur ou gêne", "Maladie", "Imprévu", "Autre"]
        guard allowed.contains(reason) else { return }
        completed.remove(date)
        UserDefaults.standard.set(Array(completed), forKey: "pace.v2.completed")
        missedSessions[date] = PaceMissedSession(date: date, reason: reason,
            note: String(note.prefix(500)).trimmingCharacters(in: .whitespacesAndNewlines),
            recordedAt: .now)
        persistMissed()
    }
    func clearMissed(_ date: String) {
        guard missedSessions.removeValue(forKey: date) != nil else { return }
        persistMissed()
    }
    func isMealDeclared(_ recipe: PaceRecipe, on date: String) -> Bool {
        mealDeclarations[date + "|" + recipe.meal + "|" + recipe.name] != nil
    }

    func toggleMealDeclaration(_ recipe: PaceRecipe, on date: String) {
        // Don't allow consumption entries for a date or recipe outside the
        // currently displayed plan. No quantities or nutrients are invented.
        guard currentPlan.contains(where: { $0.date == date && $0.day == recipe.day }),
              currentRecipes.contains(where: {
                  $0.day == recipe.day && $0.meal == recipe.meal && $0.name == recipe.name
              }) else { return }
        let id = date + "|" + recipe.meal + "|" + recipe.name
        var next = mealDeclarations
        if next.removeValue(forKey: id) == nil {
            next[id] = PaceMealDeclaration(id: id, date: date, meal: recipe.meal,
                                           recipeName: recipe.name, declaredAt: .now)
        }
        do {
            let bytes = try JSONEncoder().encode(next)
            try FileManager.default.createDirectory(
                at: mealURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: mealURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: mealURL.path)
            mealDeclarations = next
            mealSaveError = nil
        } catch {
            mealSaveError = "Impossible d'enregistrer cette déclaration de repas."
        }
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
        let base: [PaceDay]
        if let draft = activeCoachDraft {
            base = draft.training.sorted { $0.date < $1.date }.map { $0.asPaceDay(meals:draft.meals) }
        } else {
            base = programme.plan
        }
        return base.map { day in
            guard let adjustment = approvedAdjustments[day.date] else { return day }
            let isPause = adjustment.recommendation == .pause
            return PaceDay(date:day.date,day:day.day,
                type:isPause ? "Repos" : day.type,
                title:isPause ? "Repos · adaptation validée" : "Course facile · adaptation validée",
                minutes:Double(adjustment.minutes),
                intensity:isPause ? "Repos" : "Très facile",
                objective:isPause ? "Suspendre la course en raison de la gêne déclarée." :
                    "Réduire la charge à court terme sans modifier le cycle complet.",
                instructions:isPause ? "Repos. Si la douleur est importante ou persistante, demander un avis médical. " + adjustment.reason :
                    "Allure de conversation, sans fractionné. " + adjustment.reason,
                lunch:day.lunch,dinner:day.dinner,kcal:day.kcal,protein:day.protein,
                status:day.status)
        }
    }
    func nextScheduledRun(after endDate:Date) -> PaceDay? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier:"en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let next = Calendar.current.date(byAdding:.day,value:1,to:Calendar.current.startOfDay(for:endDate)) ?? endDate
        let day = formatter.string(from:next)
        return currentPlan.first(where:{ $0.date >= day && $0.type == "Course" && !completed.contains($0.date) && missedSessions[$0.date] == nil })
    }
    func approveAdaptation(_ proposal:PaceAdaptation) throws {
        guard proposal.requiresApproval,let date = proposal.sessionDate,
              let target = currentPlan.first(where:{ $0.date == date }),
              target.type == "Course", !completed.contains(date),
              proposal.proposedMinutes != nil else {
            throw PaceChatError.invalid("La séance proposée n'est plus disponible, aucune modification appliquée.")
        }
        let tomorrow = Calendar.current.date(byAdding:.day,value:1,
                        to:Calendar.current.startOfDay(for:.now)) ?? .now
        let format = DateFormatter()
        format.locale = Locale(identifier:"en_US_POSIX")
        format.dateFormat = "yyyy-MM-dd"
        guard date >= format.string(from:tomorrow) else {
            throw PaceChatError.invalid("Impossible de modifier une séance passée.")
        }
        let minutes = proposal.recommendation == .pause ? 0 : min(Int(target.minutes),max(15,proposal.proposedMinutes ?? 15))
        let value = PaceApprovedAdjustment(sessionDate:date,originWorkout:proposal.workoutUUID,
            recommendation:proposal.recommendation,minutes:minutes,
            reason:proposal.reasons.joined(separator:" "),approvedAt:.now)
        var copy = approvedAdjustments
        copy[date] = value
        approvedAdjustments = copy
        persistAdaptations()
    }
    func undoAdaptation(on date:String) {
        approvedAdjustments.removeValue(forKey:date)
        persistAdaptations()
    }
    var currentRecipes: [PaceRecipe] {
        guard let draft = activeCoachDraft else { return programme.recipes }
        return draft.meals.sorted { ($0.date, $0.meal) < ($1.date, $1.meal) }.map { $0.asRecipe() }
    }
    func acceptCoachDraft(_ draft: PaceAICoachDraft) throws {
        try draft.validate(startDateRule: .approveTodayOrTomorrow)
        let data = try JSONEncoder().encode(draft)
        UserDefaults.standard.set(data,forKey:"pace.coach.approved")
        activeCoachDraft = draft
        approvedAdjustments.removeAll()
        try? FileManager.default.removeItem(at:adaptationURL)
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
    var missedCount: Int { currentPlan.filter { missedSessions[$0.date] != nil }.count }
    var nextDay: PaceDay? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: .now)
        guard let last = currentPlan.last, today <= last.date else { return nil }
        return currentPlan.first(where: { $0.date >= today && !completed.contains($0.date) && missedSessions[$0.date] == nil })
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

/// PACE-LAB V17 — Athletic Precision. One palette for every native module.
enum PaceColors {
    /// Signature Volt Lime, matching the approved athletic brand direction.
    static let volt = Color(red: 0.78, green: 1.00, blue: 0.21)
    /// Compatibility alias — existing graphs/buttons adopt the same identity.
    static let teal = volt
    static let base = Color(red: 0.055, green: 0.079, blue: 0.090)
    static let surface = Color(red: 0.095, green: 0.126, blue: 0.143)
    static let elevated = Color(red: 0.127, green: 0.161, blue: 0.177)
    static let porcelain = Color(red: 0.965, green: 0.972, blue: 0.959)
    static let titanium = Color(red: 0.68, green: 0.73, blue: 0.73)
    static let muted = titanium
    /// High contrast when a button is filled with lime.
    static let onVolt = Color(red: 0.055, green: 0.079, blue: 0.090)
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
