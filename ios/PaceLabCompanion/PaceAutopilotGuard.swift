import Foundation

/// AI may request an action, but only this local, testable boundary can authorize
/// an unattended change. Never increases training load or acts on serious pain.
enum PaceAutopilotGuard {
    struct Decision: Equatable {
        let allowed: Bool
        let explanation: String
        let minutes: Int?
    }

    static func assess(action: String, target: PaceDay?,
                       lastRun: WorkoutPayload?, lastNote: PaceSessionNote?,
                       trend: PaceLongitudinalSnapshot, sleep: PaceSleepSummary,
                       hasPriorAdjustment: Bool,
                       lastAutomaticChange: Date? = nil,
                       now: Date = .now) -> Decision {
        guard action == "easier" else {
            return .init(allowed:false, explanation:"Pas de modification nécessaire ou avis demandé.",minutes:nil)
        }
        guard let target, target.type == "Course", let lastRun, lastRun.isRun,
              lastRun.endDate <= now, !hasPriorAdjustment else {
            return .init(allowed:false, explanation:"Course future introuvable ou déjà adaptée.",minutes:nil)
        }
        if let lastAutomaticChange, now.timeIntervalSince(lastAutomaticChange) < 7 * 86400 {
            return .init(allowed:false,explanation:"Une adaptation automatique existe déjà dans les sept derniers jours : préserver le cycle.",minutes:nil)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier:"en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from:target.date),
              date >= Calendar.current.startOfDay(for:now.addingTimeInterval(86400)),
              date <= now.addingTimeInterval(8 * 86400),
              target.minutes.isFinite, target.minutes >= 20 else {
            return .init(allowed:false,explanation:"La séance n'est pas dans la fenêtre de modification autorisée.",minutes:nil)
        }
        if let pain = lastNote?.pain, pain >= 4 {
            return .init(allowed:false,explanation:"Gêne importante : décision manuelle et réévaluation requises.",minutes:nil)
        }
        let evidence = PaceAutopilotSignificance.evidence(note:lastNote,trend:trend,sleep:sleep)
        guard evidence.count >= 2 else {
            return .init(allowed:false,explanation:"Moins de deux domaines indépendants et suffisamment renseignés : programme conservé.",minutes:nil)
        }
        let reduced = max(15, min(Int(target.minutes) - 1, Int((target.minutes * 0.80).rounded())))
        guard reduced < Int(target.minutes) else {
            return .init(allowed:false,explanation:"Réduction non exploitable.",minutes:nil)
        }
        return .init(allowed:true,explanation:"Au moins deux domaines indépendants vérifiés ; allègement plafonné à environ 20 %, suivi de la tolérance.",minutes:reduced)
    }
}
