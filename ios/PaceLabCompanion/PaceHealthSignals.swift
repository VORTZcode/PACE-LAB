import Foundation
import HealthKit
import SwiftUI

/// PACE LAB does not assume that an Apple Health reading exists or that a user
/// granted access merely because the authorization dialog was dismissed.
struct PaceHealthSignalObservation: Codable {
    let date: Date
    let value: Double
}

struct PaceHealthSignalDefinition {
    let id: String
    let name: String
    let identifier: HKQuantityTypeIdentifier
    let unit: HKUnit
    let unitLabel: String
    let minimum: Double
    let maximum: Double
}

enum PaceHealthSignalTypes {
    static let definitions: [PaceHealthSignalDefinition] = [
        .init(id: "resting-heart-rate", name: "Fréquence cardiaque au repos",
              identifier: .restingHeartRate,
              unit: HKUnit.count().unitDivided(by: .minute()),
              unitLabel: "bpm", minimum: 30, maximum: 160),
        .init(id: "hrv-sdnn", name: "Variabilité cardiaque SDNN",
              identifier: .heartRateVariabilitySDNN,
              unit: HKUnit.secondUnit(with: .milli),
              unitLabel: "ms", minimum: 3, maximum: 400),
        .init(id: "vo2max", name: "VO₂ max estimée",
              identifier: .vo2Max,
              unit: HKUnit.literUnit(with: .milli)
                .unitDivided(by: HKUnit.gramUnit(with: .kilo))
                .unitDivided(by: .minute()),
              unitLabel: "mL/kg/min", minimum: 10, maximum: 95),
        .init(id: "walking-heart-rate", name: "Fréquence cardiaque de marche",
              identifier: .walkingHeartRateAverage,
              unit: HKUnit.count().unitDivided(by: .minute()),
              unitLabel: "bpm", minimum: 30, maximum: 220),
        .init(id: "body-mass-healthkit", name: "Poids enregistré dans Santé",
              identifier: .bodyMass,
              unit: HKUnit.gramUnit(with: .kilo),
              unitLabel: "kg", minimum: 20, maximum: 400),
        .init(id: "body-fat-percentage", name: "Masse grasse mesurée",
              identifier: .bodyFatPercentage,
              unit: HKUnit.percent(),
              unitLabel: "%", minimum: 1, maximum: 75),
        .init(id: "lean-body-mass", name: "Masse maigre mesurée",
              identifier: .leanBodyMass,
              unit: HKUnit.gramUnit(with: .kilo),
              unitLabel: "kg", minimum: 10, maximum: 300)
    ]
}

/// A basic trend is a description of recordings, not a fatigue diagnosis.
enum PaceSignalTrends {
    static func summary(id: String, name: String, unit: String,
                        points: [PaceHealthSignalObservation],
                        at now: Date) -> String? {
        let valid = points.filter {
            $0.value.isFinite && $0.date <= now &&
            $0.date >= now.addingTimeInterval(-56 * 86400)
        }.sorted { $0.date > $1.date }
        guard let latest = valid.first else { return nil }
        let latestValue = String(format: "%.1f", latest.value)
        let recentStart = now.addingTimeInterval(-14 * 86400)
        let olderStart = now.addingTimeInterval(-42 * 86400)
        let recent = valid.filter { $0.date >= recentStart }
        let older = valid.filter { $0.date >= olderStart && $0.date < recentStart }
        var result = "\(name) : dernière mesure \(latestValue) \(unit) (\(latest.date.formatted(date: .abbreviated, time: .omitted)))."
        if recent.count >= 3 && older.count >= 3 {
            func median(_ values: [Double]) -> Double {
                let sorted = values.sorted()
                return sorted[sorted.count / 2]
            }
            let current = median(recent.map(\.value))
            let baseline = median(older.map(\.value))
            result += " Médiane 14 j \(String(format: "%.1f", current)) ; 14–42 j précédents \(String(format: "%.1f", baseline)) \(unit), écart descriptif \(String(format: "%+.1f", current - baseline))."
        } else {
            result += " Pas assez de relevés comparables pour une tendance."
        }
        result += " Ne pas en déduire à elle seule un état de santé, un niveau de fatigue ou une modification du programme."
        return result
    }
}

/// Optional, local-only HealthKit trend reader. New API calls occur only after
/// an explicit user request; separate sharing consent is required for ChatGPT.
@MainActor final class PaceHealthSignals: ObservableObject {
    static let shared = PaceHealthSignals()
    @Published private(set) var observations: [String: [PaceHealthSignalObservation]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var status = "Tendances complémentaires non activées."
    @Published private(set) var accessRequested = UserDefaults.standard.bool(forKey: "pace.health.signals-requested")
    private let healthStore = HKHealthStore()
    private let storageURL: URL

    private init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask)[0]
        storageURL = directory.appendingPathComponent("pace-health-trends-local.json")
        if let bytes = try? Data(contentsOf: storageURL),
           let values = try? JSONDecoder().decode(
               [String: [PaceHealthSignalObservation]].self, from: bytes) {
            observations = values
            status = "Dernières mesures locales restaurées. Actualiser si nécessaire."
        }
    }

    func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "Apple Santé n'est pas disponible sur cet appareil."
            return
        }
        let types = Set(PaceHealthSignalTypes.definitions.compactMap {
            HKObjectType.quantityType(forIdentifier: $0.identifier)
        })
        do {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                healthStore.requestAuthorization(toShare: [], read: types) { _, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
            accessRequested = true
            UserDefaults.standard.set(true, forKey: "pace.health.signals-requested")
            status = "Demande terminée. Seules les mesures réellement accessibles seront affichées."
            await refresh()
        } catch {
            status = "Autorisation Santé interrompue : \(error.localizedDescription)"
        }
    }

    func refresh() async {
        guard accessRequested, !isLoading else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "Apple Santé indisponible sur cet appareil."
            return
        }
        isLoading = true
        defer { isLoading = false }
        let now = Date()
        let since = now.addingTimeInterval(-56 * 86400)
        var collected: [String: [PaceHealthSignalObservation]] = [:]
        for item in PaceHealthSignalTypes.definitions {
            guard let type = HKObjectType.quantityType(forIdentifier: item.identifier) else { continue }
            let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
                let predicate = HKQuery.predicateForSamples(withStart: since, end: now)
                let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 500,
                                          sortDescriptors: [NSSortDescriptor(
                                            key: HKSampleSortIdentifierEndDate, ascending: false)]) {
                    _, results, _ in
                    continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
                }
                healthStore.execute(query)
            }
            let filtered = samples.compactMap { sample -> PaceHealthSignalObservation? in
                let value = sample.quantity.doubleValue(for: item.unit)
                guard value.isFinite, (item.minimum...item.maximum).contains(value)
                else { return nil }
                return .init(date: sample.endDate, value: value)
            }
            if !filtered.isEmpty { collected[item.id] = filtered }
        }
        observations = collected
        let total = collected.values.reduce(0) { $0 + $1.count }
        status = total > 0
            ? "\(total) mesures consultables, réparties dans \(collected.count) catégories."
            : "Aucune mesure complémentaire accessible. Données absentes ou lecture non autorisée."
        do {
            let bytes = try JSONEncoder().encode(collected)
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: storageURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: storageURL.path)
        } catch {
            status += " Impossible de conserver la dernière lecture."
        }
    }

    func latest(_ id: String) -> PaceHealthSignalObservation? {
        observations[id]?.max(by: { $0.date < $1.date })
    }

    /// Invoked only after separate GPT data-sharing consent has been enabled.
    var consentedCoachContext: String {
        guard accessRequested else { return "Tendances Santé supplémentaires non activées." }
        let lines = PaceHealthSignalTypes.definitions.compactMap { def -> String? in
            guard let values = observations[def.id] else { return nil }
            return PaceSignalTrends.summary(id: def.id, name: def.name,
                                            unit: def.unitLabel, points: values, at: .now)
        }
        return lines.isEmpty ? "Aucune tendance complémentaire disponible ; ne rien inférer."
            : "Mesures HealthKit complémentaires autorisées, résumés locaux sans identifiants ni séries brutes : " +
              lines.joined(separator: " ")
    }
}
