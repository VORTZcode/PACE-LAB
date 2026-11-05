import Foundation
import SwiftUI

/// User-confirmed link from a planned run to a real HealthKit workout.
/// This metadata never changes Apple Health records or synthesizes a workout.
@MainActor final class PaceRunWorkoutLinks: ObservableObject {
    static let shared = PaceRunWorkoutLinks()
    @Published private(set) var byDay: [String: String] = [:]
    @Published private(set) var error: String?

    private let url: URL
    private init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask)[0]
        url = directory.appendingPathComponent("pace-run-health-links.json")
        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([String: String].self, from: data) {
            byDay = saved
        }
    }

    func confirmedWorkoutUUID(for date: String) -> String? { byDay[date] }

    func confirm(date: String, workout: WorkoutPayload) {
        guard workout.isRun, UUID(uuidString: workout.source_uuid) != nil else {
            error = "Cette activité Apple Santé n'est pas une course identifiable."
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        guard formatter.string(from: workout.startDate) == date else {
            error = "Cette activité ne correspond pas à la date du programme."
            return
        }
        var next = byDay
        next[date] = workout.source_uuid
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path)
            byDay = next
            error = nil
        } catch {
            error = "Impossible de sauvegarder l'association. Aucun statut n'a changé."
        }
    }

    func unlink(date: String) {
        guard byDay[date] != nil else { return }
        var next = byDay
        next.removeValue(forKey: date)
        do {
            try JSONEncoder().encode(next).write(to: url, options: .atomic)
            byDay = next
            error = nil
        } catch {
            error = "Impossible de retirer l'association. Elle reste inchangée."
        }
    }
}
