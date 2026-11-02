import Foundation
import HealthKit
import SwiftUI

/// Requests sleepAnalysis *separately* from workout access. No raw sleep history is
/// written to disk or sent to OpenAI; only an explicit, consented aggregate can leave.
@MainActor final class PaceSleepHealthKit: ObservableObject {
    @Published private(set) var monitoringEnabled =
        UserDefaults.standard.bool(forKey:"pace.sleep.healthkit-requested")
    @Published private(set) var summary = PaceSleepRules.summarize([])
    @Published private(set) var status = "Accès au sommeil non demandé."
    @Published private(set) var isLoading = false
    private let store = HKHealthStore()
    private let type = HKObjectType.categoryType(forIdentifier:.sleepAnalysis)!
    private var inFlight = false
    private var observer: HKObserverQuery?
    private var lastRefresh: Date?

    func requestAccess() {
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "Apple Santé n'est pas disponible sur cet appareil."
            return
        }
        status = "Demande d'accès aux données de sommeil…"
        store.requestAuthorization(toShare:[],read:[type]) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.status = "Accès au sommeil : \(error.localizedDescription)"
                    return
                }
                // HealthKit does not disclose read-access decisions. The user
                // may deny access; zero returned samples do not mean zero sleep.
                self.monitoringEnabled = true
                UserDefaults.standard.set(true,forKey:"pace.sleep.healthkit-requested")
                self.startObservers()
                self.refresh(force:true)
            }
        }
    }

    /// HealthKit callbacks are best-effort; foreground refresh is still necessary.
    func startObservers() {
        guard monitoringEnabled, HKHealthStore.isHealthDataAvailable(),
              observer == nil else { return }
        let query = HKObserverQuery(sampleType:type,predicate:nil) { [weak self] _,complete,_ in
            Task { @MainActor in
                self?.refresh(force:true)
                complete()
            }
        }
        observer=query
        store.execute(query)
        store.enableBackgroundDelivery(for:type,frequency:.hourly) { _,_ in
            // OS schedules delivery; hourly is requested, not guaranteed.
        }
    }

    func refresh(force:Bool=false) {
        guard monitoringEnabled,HKHealthStore.isHealthDataAvailable(),!inFlight else { return }
        if !force, let lastRefresh, Date.now.timeIntervalSince(lastRefresh) < 180 { return }
        inFlight=true
        isLoading=true
        let start = Date.now.addingTimeInterval(-17 * 86400)
        let predicate = HKQuery.predicateForSamples(withStart:start,end:Date.now,options:[])
        let query=HKSampleQuery(sampleType:type,predicate:predicate,limit:HKObjectQueryNoLimit,
                 sortDescriptors:[NSSortDescriptor(key:HKSampleSortIdentifierEndDate,ascending:false)]) {
            [weak self] _, samples, error in
            Task { @MainActor in
                guard let self else { return }
                self.inFlight=false
                self.isLoading=false
                self.lastRefresh = .now
                if let error {
                    self.status="Lecture du sommeil : \(error.localizedDescription)"
                    return
                }
                let intervals=(samples as? [HKCategorySample] ?? []).map {
                    PaceSleepInterval(source:$0.sourceRevision.source.bundleIdentifier,
                                      start:$0.startDate,end:$0.endDate,stage:$0.value)
                }
                self.summary=PaceSleepRules.summarize(intervals)
                self.status=self.summary.coverage14 == 0
                    ? "Aucune donnée de sommeil accessible pour les 14 derniers jours. Vérifie la source et les autorisations Apple Santé."
                    : "\(self.summary.coverage14) journées de sommeil disponibles sur 14."
            }
        }
        store.execute(query)
    }
}
