import Foundation
import SwiftUI

/// Deterministic, on-device review. ChatGPT never silently mutates the training plan.
struct PaceAdaptation: Codable, Identifiable {
    enum Recommendation: String, Codable { case maintain, requestFeedback, easier, pause }
    let workoutUUID: String
    let recommendation: Recommendation
    let sessionDate: String?
    let proposedMinutes: Int?
    let reasons: [String]
    let headline: String
    let createdAt: Date
    var id: String { workoutUUID }
    var requiresApproval: Bool { recommendation == .easier || recommendation == .pause }
}

struct PaceApprovedAdjustment: Codable, Identifiable {
    let sessionDate: String
    let originWorkout: String
    let recommendation: PaceAdaptation.Recommendation
    let minutes: Int
    let reason: String
    let approvedAt: Date
    var id: String { sessionDate }
}

enum PaceAdaptiveRules {
    static func assess(last:WorkoutPayload,history:[WorkoutPayload],
                       note:PaceSessionNote,nextRun:PaceDay?,now:Date = .now) -> PaceAdaptation {
        let day = nextRun?.date
        let before = last.startDate.addingTimeInterval(-30 * 86400)
        let previous = history.filter {
            $0.source_uuid != last.source_uuid &&
            $0.startDate >= before && $0.startDate < last.startDate &&
            $0.isRun && $0.kilometers.isFinite && $0.kilometers > 0
        }
        let previousMax = previous.map(\.kilometers).max() ?? 0
        var reasons:[String] = []
        let pain = note.pain
        let effort = note.effort
        if let pain, pain >= 4 {
            reasons.append("Gêne déclarée de \(pain)/10. L'Apple Watch ne peut pas identifier la cause.")
            return .init(workoutUUID:last.source_uuid,recommendation:.pause,sessionDate:day,
                         proposedMinutes:0,reasons:reasons,
                         headline:"Faire une pause et réévaluer la douleur",createdAt:now)
        }
        if let pain,pain > 0 {
            reasons.append("Gêne déclarée de \(pain)/10 ; vérifier son évolution avant de courir.")
        }
        if let effort,effort >= 8 {
            reasons.append("Difficulté ressentie \(effort)/10, supérieure à l'effort attendu pour une séance facile.")
        }
        if previousMax > 0 && last.kilometers > previousMax * 1.10 {
            reasons.append("Distance de la sortie > 110 % de la plus longue sortie précédente sur 30 jours (signal de prudence issu d'une étude observationnelle).")
        }
        if !reasons.isEmpty {
            let minutes = nextRun.map { max(15,Int(($0.minutes * 0.8).rounded())) }
            return .init(workoutUUID:last.source_uuid,recommendation:.easier,
                         sessionDate:day,proposedMinutes:minutes,reasons:reasons,
                         headline:"Alléger la prochaine course",createdAt:now)
        }
        if effort == nil || pain == nil {
            return .init(workoutUUID:last.source_uuid,recommendation:.requestFeedback,
                         sessionDate:day,proposedMinutes:nil,
                         reasons:["Le ressenti ou la gêne après séance ne sont pas encore renseignés.",
                                  "Une bonne allure ou fréquence cardiaque isolée ne suffit pas pour augmenter la charge."],
                         headline:"Comment as-tu vécu cette séance ?",createdAt:now)
        }
        return .init(workoutUUID:last.source_uuid,recommendation:.maintain,
                     sessionDate:day,proposedMinutes:nil,
                     reasons:["Aucun signal de surcharge identifié avec les seules données disponibles.",
                              "Le plan actuel reste stable. Aucune progression automatique n'est justifiée."],
                     headline:"Conserver le programme",createdAt:now)
    }
}

@MainActor final class PaceAdaptiveMonitor: ObservableObject {
    @Published private(set) var latest: PaceAdaptation?
    @Published private(set) var dismissedUUID: String? =
        UserDefaults.standard.string(forKey:"pace.adaptive.dismissed")
    @Published private(set) var lastReviewedFingerprint = ""
    private let recordURL: URL = {
        FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
            .appendingPathComponent("pace-adaptive-latest.json")
    }()

    init() {
        if let data = try? Data(contentsOf:recordURL) {
            latest = try? JSONDecoder().decode(PaceAdaptation.self,from:data)
        }
    }
    func refresh(engine:HealthSyncEngine,journal:PaceSessionJournal,library:PaceLibrary) {
        guard let run = engine.runHistory.first,run.isRun,
              run.endDate.timeIntervalSinceNow <= -180 else { return }
        let note = journal.note(for:run.source_uuid)
        let notedAt = journal.notes[run.source_uuid]?.updatedAt.timeIntervalSince1970 ?? 0
        let fingerprint = "\(run.source_uuid)|\(notedAt)|\(run.recovery_state)"
        guard fingerprint != lastReviewedFingerprint else { return }
        lastReviewedFingerprint = fingerprint
        let day = library.nextScheduledRun(after:run.endDate)
        let result = PaceAdaptiveRules.assess(last:run,history:engine.runHistory,
                                               note:note,nextRun:day)
        latest = result
        if let data = try? JSONEncoder().encode(result) {
            let dir = recordURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
            if (try? data.write(to:recordURL,options:.atomic)) != nil {
                try? FileManager.default.setAttributes(
                    [.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath:recordURL.path)
            }
        }
        // If the user has already dismissed the SAME run, don't re-open it.
    }
    var visible: PaceAdaptation? {
        guard let latest,dismissedUUID != latest.workoutUUID else { return nil }
        return latest
    }
    func dismiss() {
        guard let uuid = latest?.workoutUUID else { return }
        dismissedUUID = uuid
        UserDefaults.standard.set(uuid,forKey:"pace.adaptive.dismissed")
    }
}
