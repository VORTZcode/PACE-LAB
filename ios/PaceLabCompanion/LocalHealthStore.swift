import Foundation

// On-device HealthKit payload. UUID is stable for idempotent updates.
struct HeartRatePoint: Codable {
    let timestamp: String
    let bpm: Double
}
struct PaceSensorPoint: Codable {
    let timestamp: String
    let value: Double
}
struct WorkoutPayload: Codable {
    let source_uuid: String
    let activity_type: Int
    let activity_kind: String
    let started_at: String
    let ended_at: String
    let duration_seconds: Double
    let distance_meters: Double?
    let active_energy_kcal: Double?
    let hr_average_bpm: Double?
    let hr_max_bpm: Double?
    let hr_at_end_bpm: Double?
    let recovery_hr_1min: Double?
    let recovery_hr_2min: Double?
    let recovery_hr_3min: Double?
    let recovery_hr_5min: Double?
    let apple_recovery_1min_delta: Double?
    let recovery_state: String
    let heart_rate_series: [HeartRatePoint]
    let details_complete: Bool? // Backward-compatible with local files created by older PACE LAB versions.
    // Optional, backward-compatible sensor metrics: older saved workouts decode unchanged.
    var advanced_loaded: Bool? = nil
    var mean_power_w: Double? = nil
    var mean_speed_mps: Double? = nil
    var mean_stride_m: Double? = nil
    var mean_ground_contact_ms: Double? = nil
    var mean_vertical_oscillation_cm: Double? = nil
    var cadence_estimated_spm: Double? = nil
    var speed_series: [PaceSensorPoint]? = nil
    var power_series: [PaceSensorPoint]? = nil
    var stride_series: [PaceSensorPoint]? = nil
    var ground_contact_series: [PaceSensorPoint]? = nil
    var vertical_series: [PaceSensorPoint]? = nil

}

// Only summary fields cross from native Swift to the bundled offline web UI.
struct WorkoutWebSummary: Encodable {
    let source_uuid: String
    let activity_kind: String
    let started_at: String
    let duration_seconds: Double
    let distance_meters: Double?
    let hr_average_bpm: Double?
    let hr_max_bpm: Double?
    let hr_at_end_bpm: Double?
    let recovery_hr_1min: Double?
    let recovery_hr_2min: Double?
    let recovery_hr_3min: Double?
    let recovery_hr_5min: Double?
    let recovery_state: String
    init(_ p: WorkoutPayload) {
        source_uuid = p.source_uuid
        activity_kind = p.activity_kind
        started_at = p.started_at
        duration_seconds = p.duration_seconds
        distance_meters = p.distance_meters
        hr_average_bpm = p.hr_average_bpm
        hr_max_bpm = p.hr_max_bpm
        hr_at_end_bpm = p.hr_at_end_bpm
        recovery_hr_1min = p.recovery_hr_1min
        recovery_hr_2min = p.recovery_hr_2min
        recovery_hr_3min = p.recovery_hr_3min
        recovery_hr_5min = p.recovery_hr_5min
        recovery_state = p.recovery_state
    }
}
