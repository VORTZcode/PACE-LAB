import Foundation
import SwiftUI

/// Joins a confirmed Apple Health workout to the user's manually entered strength sets.
/// Existing strength and HealthKit files are never rewritten by this link.
@MainActor final class PaceStrengthWorkoutLinks: ObservableObject {
    @Published private(set) var byDay: [String:String] = [:]
    @Published private(set) var error: String?
    private let url: URL

    init() {
        url = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
            .appendingPathComponent("pace-strength-health-links.json")
        if let bytes = try? Data(contentsOf:url) {
            byDay = (try? JSONDecoder().decode([String:String].self,from:bytes)) ?? [:]
        }
    }
    func confirm(day:String,workoutUUID:String) {
        guard !day.isEmpty,!workoutUUID.isEmpty else { return }
        var next = byDay
        next[day] = workoutUUID
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                   withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to:url,options:.atomic)
            try FileManager.default.setAttributes(
                [.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath:url.path)
            byDay = next
            error = nil
        } catch {
            self.error = "Impossible d'associer la séance Apple Watch."
        }
    }
    func confirmedWorkoutUUID(for day:String) -> String? { byDay[day] }

    /// Earlier versions only stored the day completion and the manually entered sets.
    /// In that case, infer a link only for one HealthKit strength workout on the same date.
    func associatedDay(for workout:WorkoutPayload,library:PaceLibrary,
                       tracker:PaceStrengthTracker,history:[WorkoutPayload]) -> PaceDay? {
        guard workout.activity_kind == "strength" else { return nil }
        if let date = byDay.first(where:{$0.value == workout.source_uuid})?.key {
            return library.currentPlan.first(where:{$0.date == date && $0.type == "Musculation"})
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier:"en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let calendarDay = formatter.string(from:workout.startDate)
        guard byDay[calendarDay] == nil,
              let day = library.currentPlan.first(where:{$0.date == calendarDay && $0.type == "Musculation"}),
              history.filter({
                  $0.activity_kind == "strength" &&
                  Calendar.current.isDate($0.startDate,inSameDayAs:workout.startDate)
              }).count == 1 else { return nil }
        let exercises = library.programme.force.filter({$0.day == day.day})
        let hasEntries = exercises.contains { exercise in
            (0..<max(0,exercise.sets)).contains { index in
                let record = tracker.entry(day:day.date,exerciseID:exercise.id,set:index+1)
                return record.completed || !record.repetitions.isEmpty || !record.weightKg.isEmpty
            }
        }
        return library.completed.contains(day.date) || hasEntries ? day : nil
    }
}
