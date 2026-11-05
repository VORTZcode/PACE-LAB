import Foundation

/// Execute with:
/// swiftc ios/PaceLabCompanion/LocalHealthStore.swift \
///   ios/PaceLabCompanion/PaceProgressEvidence.swift \
///   tests/progress-evidence-fixture.swift -o /tmp/pace-progress-fixture
/// /tmp/pace-progress-fixture
@main struct PaceProgressEvidenceFixture {
    static func run(_ id: String, _ started: String, km: Double, pace: Double,
                    heart: Double? = nil, complete: Bool = true) -> WorkoutPayload {
        WorkoutPayload(
            source_uuid: id, activity_type: 37, activity_kind: "running",
            started_at: started, ended_at: started,
            duration_seconds: pace * km, distance_meters: km * 1000,
            active_energy_kcal: nil,
            hr_average_bpm: heart, hr_max_bpm: nil, hr_at_end_bpm: nil,
            recovery_hr_1min: nil, recovery_hr_2min: nil,
            recovery_hr_3min: nil, recovery_hr_5min: nil,
            apple_recovery_1min_delta: nil, recovery_state: "partial",
            heart_rate_series: [], details_complete: complete
        )
    }

    static func main() {
        let iso = ISO8601DateFormatter()
        let now = iso.date(from: "2026-11-05T18:00:00Z")!
        let samples = [
            run("latest", "2026-11-04T08:00:00Z", km: 5, pace: 360, heart: 145),
            run("similar", "2026-10-20T08:00:00Z", km: 4.98, pace: 380, heart: 148),
            run("previous", "2026-09-30T08:00:00Z", km: 5.1, pace: 400, heart: 154),
            run("latest", "2026-11-04T08:00:00Z", km: 5, pace: 360,
                heart: 145, complete: false), // same HealthKit UUID, not two activities
            run("future", "2026-11-20T08:00:00Z", km: 5, pace: 330),
            run("corrupted", "2026-10-28T08:00:00Z", km: 0, pace: 300)
        ]
        let result = PaceProgressEvidence.snapshot(samples, at: now)
        precondition(result.validHistoryCount == 3, "Deduplicate and reject corrupted/future data")
        precondition(result.current28.runCount == 2)
        precondition(abs(result.current28.distanceKm - 9.98) < 0.001)
        precondition(result.previous28.runCount == 1)
        precondition(result.current28.activeWeeks >= 1)
        precondition(result.hasTwoPeriods)
        guard let compared = result.comparison else { preconditionFailure("Comparable run expected") }
        precondition(compared.currentID == "latest" && compared.priorID == "similar")
        precondition(compared.paceDifferenceSecondsPerKm < 0)
        precondition(compared.comparableHeartRate, "HR may support conditional comparability")
        precondition(compared.heartDifferenceBPM == -3)
        let onlyLatest = PaceProgressEvidence.snapshot([samples[0]], at: now)
        precondition(onlyLatest.comparison == nil && !onlyLatest.hasTwoPeriods)
        let olderComparison = PaceProgressEvidence.comparison(for: samples[1], in: samples, at: now)
        precondition(olderComparison?.priorID == "previous", "A historical comparison must use only an earlier workout")
        let selectedComparison = PaceProgressEvidence.comparison(for: samples[0], in: samples, at: now)
        precondition(selectedComparison?.priorID == "similar")
        let highHR = [
            samples[0],
            run("higherHR", "2026-10-20T08:00:00Z", km: 4.98, pace: 380, heart: 180)
        ]
        let differentIntensity = PaceProgressEvidence.snapshot(highHR, at: now)
        precondition(differentIntensity.comparison?.comparableHeartRate == false)
        print("PASS: time windows, valid workouts, duplicate UUID, similar distance, descriptive pace, HR evidence limits.")
    }
}
