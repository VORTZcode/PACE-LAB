import Foundation
import HealthKit
import BackgroundTasks
import SwiftUI

// HealthKit background delivery is best effort. Historical import is paginated and resumable.
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
    private var needsForegroundBackfill = false
    private let diskURL: URL
    private let anchorURL: URL
    private var workoutAnchor: HKQueryAnchor?
    private var queue: [String: WorkoutPayload] = [:]

    private init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        diskURL = directory.appendingPathComponent("local-healthkit-workouts.json")
        anchorURL = directory.appendingPathComponent("healthkit-workout-anchor.bin")
        if let data = try? Data(contentsOf: anchorURL),
           let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data) {
            workoutAnchor = anchor
        }
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
    private func saveAnchor(_ anchor: HKQueryAnchor?) {
        guard let anchor,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else { return }
        do {
            try data.write(to: anchorURL, options: .atomic)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: anchorURL.path)
            workoutAnchor = anchor
        } catch {
            status = "Échec de sauvegarde du curseur Santé : \(error.localizedDescription)"
        }
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
                    await self.resyncAsync(enrichHistory: false)
                    complete() // Acknowledge HealthKit promptly; historical enrichment runs in foreground.
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

    // HealthKit's anchored pages import ALL years, and retain an incremental cursor across app launches.
    private func workoutPage() async throws -> (workouts: [HKWorkout], deleted: [HKDeletedObject], anchor: HKQueryAnchor?) {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(type: .workoutType(), predicate: nil,
                                               anchor: workoutAnchor, limit: 60) { _, samples, deleted, next, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKWorkout] ?? [], deleted ?? [], next))
            }
            healthStore.execute(query)
        }
    }
    private func workouts(predicate: NSPredicate?, limit: Int = HKObjectQueryNoLimit) async -> [HKWorkout] {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: limit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, _ in
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            healthStore.execute(query)
        }
    }
    private func summary(_ workout: HKWorkout) -> WorkoutPayload {
        let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let kind: String
        switch workout.workoutActivityType {
        case .running: kind = "running"
        case .walking: kind = "walking"
        case .cycling: kind = "cycling"
        case .traditionalStrengthTraining, .functionalStrengthTraining: kind = "strength"
        default: kind = "other"
        }
        return WorkoutPayload(
            source_uuid: workout.uuid.uuidString.lowercased(),
            activity_type: Int(workout.workoutActivityType.rawValue), activity_kind: kind,
            started_at: clock.string(from: workout.startDate), ended_at: clock.string(from: workout.endDate),
            duration_seconds: workout.duration,
            distance_meters: workout.statistics(for: distance)?.sumQuantity()?.doubleValue(for: .meter()),
            active_energy_kcal: workout.statistics(for: energy)?.sumQuantity()?.doubleValue(for: .kilocalorie()),
            hr_average_bpm: nil, hr_max_bpm: nil, hr_at_end_bpm: nil,
            recovery_hr_1min: nil, recovery_hr_2min: nil, recovery_hr_3min: nil, recovery_hr_5min: nil,
            apple_recovery_1min_delta: nil, recovery_state: "pending",
            heart_rate_series: [], details_complete: false)
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
        // Apple stores heart-rate recovery with a rate unit (count/min), not plain count.
        let delta = recordedRecovery.first?.quantity.doubleValue(for: bpmUnit)
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
            heart_rate_series: window.map { HeartRatePoint(timestamp: clock.string(from: $0.startDate), bpm: $0.quantity.doubleValue(for: bpmUnit)) },
            details_complete: true
        )
    }
    private func resyncAsync(enrichHistory: Bool = true) async {
        guard !isSyncing else {
            if enrichHistory { needsForegroundBackfill = true }
            return
        }
        isSyncing = true
        defer {
            isSyncing = false
            if needsForegroundBackfill {
                needsForegroundBackfill = false
                Task { await self.resyncAsync(enrichHistory: true) }
            }
        }
        var imported = 0
        do {
            // Phase 1: fast complete history, including older years, with disk persistence per page.
            for _ in 0..<100 {
                if Task.isCancelled { break }
                let page = try await workoutPage()
                let count = page.workouts.count + page.deleted.count
                for deletion in page.deleted { queue.removeValue(forKey: deletion.uuid.uuidString.lowercased()) }
                for workout in page.workouts {
                    let key = workout.uuid.uuidString.lowercased()
                    if queue[key] == nil { queue[key] = summary(workout); imported += 1 }
                }
                if count > 0 { storeQueue() } // Commit data before committing the HealthKit anchor.
                saveAnchor(page.anchor)
                status = "Historique Apple Santé : \(queue.count) activités enregistrées, \(imported) nouvelles."
                if count < 60 || page.anchor == nil { break }
                await Task.yield()
            }
        } catch {
            status = "Synchronisation Santé interrompue : \(error.localizedDescription). Les activités déjà importées sont conservées."
            return
        }

        // Phase 2: enrich summaries with actual heart-rate measurements; resume if iOS suspends us.
        let pendingIds = Set(queue.values.filter {
            $0.details_complete != true && ($0.details_complete == false || $0.heart_rate_series.isEmpty)
        }.map(\.source_uuid))
        if enrichHistory && !pendingIds.isEmpty {
            let all = await workouts(predicate: nil)
            let pending = all.filter { pendingIds.contains($0.uuid.uuidString.lowercased()) }
            for (index, workout) in pending.enumerated() {
                if Task.isCancelled { break }
                let data = await build(workout)
                queue[data.source_uuid] = data
                if (index + 1) % 8 == 0 || index + 1 == pending.count {
                    storeQueue()
                    status = "Cardio et récupération : \(index + 1) / \(pending.count) activités enrichies. Historique total : \(queue.count)."
                }
                await Task.yield()
            }
        }

        // A post-workout heart-rate sample can arrive AFTER the workout itself.
        // Refresh recent workouts without reprocessing the entire historical library.
        let date = Date().addingTimeInterval(-6*3600)
        let recent = await workouts(predicate: HKQuery.predicateForSamples(withStart: date, end: nil), limit: 20)
        for workout in recent {
            if Task.isCancelled { break }
            guard let old = queue[workout.uuid.uuidString.lowercased()] else { continue }
            if old.recovery_state == "complete" { continue }
            let updated = await build(workout)
            queue[updated.source_uuid] = updated
        }
        storeQueue()
        status = "\(queue.count) activités Apple Santé enregistrées localement. Synchronisation terminée."
        if !recent.isEmpty { scheduleBackgroundRefresh() }
    }
    private func scheduleBackgroundRefresh() {
        let req = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        req.earliestBeginDate = Date().addingTimeInterval(3*60)
        try? BGTaskScheduler.shared.submit(req) // earliestBeginDate is not a guaranteed wake-up time.
    }
    func handleRefreshTask(_ task: BGAppRefreshTask) {
        task.expirationHandler = { /* network operations may be interrupted; persistent queue retries next time. */ }
        Task { @MainActor in
            await resyncAsync(enrichHistory: false)
            task.setTaskCompleted(success: true)
            scheduleBackgroundRefresh()
        }
    }
}

extension Notification.Name {
    static let paceHealthKitUpdated = Notification.Name("pace.healthkit.updated")
}
