import Foundation
import HealthKit
import BackgroundTasks
import SwiftUI

// HealthKit background delivery is best effort. This engine never promises a 5-minute deadline.
// Requeries on foreground, HealthKit observer deliveries, and a best-effort BG refresh request.
@MainActor
final class HealthSyncEngine: ObservableObject {
    static let shared = HealthSyncEngine()
    static let refreshIdentifier = "com.pacelab.healthcompanion.refresh"

    @Published private(set) var status = "Prêt à demander l'accès Santé."
    @Published private(set) var savedCount = 0
    @Published private(set) var revision = 0
    private let healthStore = HKHealthStore()
    private let bpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
    private let clock = ISO8601DateFormatter()
    private var startedObservers = false
    private var isSyncing = false
    private let diskURL: URL
    private var queue: [String: WorkoutPayload] = [:]

    private init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        diskURL = directory.appendingPathComponent("local-healthkit-workouts.json")
        if let data = try? Data(contentsOf: diskURL),
           let saved = try? JSONDecoder().decode([String: WorkoutPayload].self, from: data) {
            queue = saved
            savedCount = saved.count
        }
    }
    private func storeQueue() {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        try? data.write(to: diskURL, options: .atomic)
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: diskURL.path)
        savedCount = queue.count
        revision += 1
        NotificationCenter.default.post(name: .paceHealthKitUpdated, object: nil)
    }
    func startObservers() {
        guard HKHealthStore.isHealthDataAvailable(), !startedObservers else { return }
        startedObservers = true
        let watched: [HKSampleType] = [HKObjectType.workoutType(), HKObjectType.quantityType(forIdentifier: .heartRate)!]
        for type in watched {
            let observer = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, complete, error in
                guard let self = self else { complete(); return }
                if error != nil { complete(); return }
                Task { @MainActor in
                    await self.resyncAsync()
                    complete() // Must call after processing the HealthKit notification.
                }
            }
            healthStore.execute(observer)
        }
        configureBackgroundDelivery()
        scheduleBackgroundRefresh()
    }
    private func configureBackgroundDelivery() {
        // Retry after the user grants HealthKit permission, not only on first app launch.
        let watched: [HKSampleType] = [HKObjectType.workoutType(), HKObjectType.quantityType(forIdentifier: .heartRate)!]
        for type in watched {
            let frequency: HKUpdateFrequency = type == HKObjectType.workoutType() ? .immediate : .hourly
            healthStore.enableBackgroundDelivery(for: type, frequency: frequency) { [weak self] enabled, _ in
                if !enabled { Task { @MainActor in self?.status = "Notification Santé en arrière-plan indisponible. Tu pourras toujours actualiser à l'ouverture." } }
            }
        }
    }
    func requestPermission() {
        guard HKHealthStore.isHealthDataAvailable() else { status = "HealthKit indisponible sur cet appareil."; return }
        let reads: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRateRecoveryOneMinute)!
        ]
        healthStore.requestAuthorization(toShare: [], read: reads) { [weak self] _, error in
            Task { @MainActor in
                if let error = error { self?.status = "Autorisation Santé : \(error.localizedDescription)"; return }
                self?.status = "Demande d'autorisation terminée. Importation des séances disponibles…"
                self?.startObservers()
                self?.configureBackgroundDelivery()
                await self?.resyncAsync()
            }
        }
    }
    var snapshot: [WorkoutPayload] { queue.values.sorted { $0.started_at > $1.started_at } }
    func resync() { Task { await resyncAsync() } }

    private func workouts() async -> [HKWorkout] {
        await withCheckedContinuation { continuation in
            let start = Date().addingTimeInterval(-30*24*3600)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 40, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }
    }
    private func quantities(_ type: HKQuantityType, start: Date, end: Date) async -> [HKQuantitySample] {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 15000,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }
    private func nearbyBPM(_ samples: [HKQuantitySample], at target: Date, tolerance: TimeInterval) -> Double? {
        let candidates = samples.filter { abs($0.startDate.timeIntervalSince(target)) <= tolerance }
        guard let match = candidates.min(by: { abs($0.startDate.timeIntervalSince(target)) < abs($1.startDate.timeIntervalSince(target)) }) else { return nil }
        return match.quantity.doubleValue(for: bpmUnit)
    }
    private func build(_ workout: HKWorkout) async -> WorkoutPayload {
        let end = workout.endDate
        let heart = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let window = await quantities(heart, start: workout.startDate, end: end.addingTimeInterval(300))
        let inWorkout = window.filter { $0.startDate >= workout.startDate && $0.startDate <= end }
        let bpm = inWorkout.map { $0.quantity.doubleValue(for: bpmUnit) }
        // HR at finish = last actual reading within 60 seconds. Never substitute peak HR.
        let beforeEnd = inWorkout.filter { $0.startDate >= end.addingTimeInterval(-60) }
        let endHR = beforeEnd.last?.quantity.doubleValue(for: bpmUnit)
        let post = window.filter { $0.startDate > end && $0.startDate <= end.addingTimeInterval(300) }
        let recoveryType = HKObjectType.quantityType(forIdentifier: .heartRateRecoveryOneMinute)!
        let recordedRecovery = await quantities(recoveryType, start: end.addingTimeInterval(-30), end: end.addingTimeInterval(900))
        let delta = recordedRecovery.first?.quantity.doubleValue(for: HKUnit.count())
        let third = nearbyBPM(post, at: end.addingTimeInterval(180), tolerance: 35)
        let fifth = nearbyBPM(post, at: end.addingTimeInterval(300), tolerance: 35)
        let oldEnough = Date().timeIntervalSince(end) >= 180
        let state = !oldEnough ? "pending" : third == nil ? "partial" : "complete"
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        // Apple's workout summaries can have different associated quantities depending on activity.
        let meters = workout.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .meter())
        let kcal = workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
        return WorkoutPayload(
            source_uuid: workout.uuid.uuidString.lowercased(), activity_type: Int(workout.workoutActivityType.rawValue),
            activity_kind: workout.workoutActivityType == .running ? "running" : workout.workoutActivityType == .walking ? "walking" : workout.workoutActivityType == .cycling ? "cycling" : (workout.workoutActivityType == .traditionalStrengthTraining || workout.workoutActivityType == .functionalStrengthTraining) ? "strength" : "other",
            started_at: clock.string(from: workout.startDate), ended_at: clock.string(from: end),
            duration_seconds: workout.duration, distance_meters: meters, active_energy_kcal: kcal,
            hr_average_bpm: bpm.isEmpty ? nil : bpm.reduce(0,+)/Double(bpm.count), hr_max_bpm: bpm.max(),
            hr_at_end_bpm: endHR,
            recovery_hr_1min: nearbyBPM(post, at: end.addingTimeInterval(60), tolerance: 35),
            recovery_hr_2min: nearbyBPM(post, at: end.addingTimeInterval(120), tolerance: 35),
            recovery_hr_3min: third,
            recovery_hr_5min: fifth, apple_recovery_1min_delta: delta,
            recovery_state: state,
            heart_rate_series: window.map { HeartRatePoint(timestamp: clock.string(from: $0.startDate), bpm: $0.quantity.doubleValue(for: bpmUnit)) }
        )
    }
    private func resyncAsync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        let recent = await workouts()
        for workout in recent {
            let payload = await build(workout)
            // Persist a protected local copy; no network request or third-party account.
            if let previous = queue[payload.source_uuid], previous.recovery_state == "complete" && payload.recovery_state != "complete" { continue }
            queue[payload.source_uuid] = payload
        }
        storeQueue()
        status = "\(queue.count) séances stockées sur cet iPhone. Aucune donnée transmise à un serveur."
        if recent.contains(where: { Date().timeIntervalSince($0.endDate) < 3600 }) { scheduleBackgroundRefresh() }
    }
    private func scheduleBackgroundRefresh() {
        let req = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        req.earliestBeginDate = Date().addingTimeInterval(3*60)
        try? BGTaskScheduler.shared.submit(req) // earliestBeginDate is not a guaranteed wake-up time.
    }
    func handleRefreshTask(_ task: BGAppRefreshTask) {
        task.expirationHandler = { /* network operations may be interrupted; persistent queue retries next time. */ }
        Task { @MainActor in
            await resyncAsync()
            task.setTaskCompleted(success: true)
            scheduleBackgroundRefresh()
        }
    }
}

extension Notification.Name {
    static let paceHealthKitUpdated = Notification.Name("pace.healthkit.updated")
}
