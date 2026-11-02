import Foundation

/// Intervals from HealthKit sleepAnalysis. In-bed and awake intervals do NOT count as sleep.
struct PaceSleepInterval: Codable, Sendable {
    let source: String
    let start: Date
    let end: Date
    let stage: Int
}

struct PaceSleepNight: Codable, Equatable {
    let day: Date
    let minutesAsleep: Int
    let source: String
}

struct PaceSleepSummary: Equatable {
    let nights: [PaceSleepNight]
    let mostRecent7AverageMinutes: Int?
    let previous7AverageMinutes: Int?
    let shortNights7: Int
    let coverage7: Int
    let coverage14: Int

    var promptContext: String {
        let recent = mostRecent7AverageMinutes.map { "\($0) min" } ?? "non calculable"
        let past = previous7AverageMinutes.map { "\($0) min" } ?? "non calculable"
        let nightly = nights.prefix(14).map {
            "\($0.day.formatted(date:.numeric,time:.omitted)): \($0.minutesAsleep) min"
        }.joined(separator:" ; ")
        return """
        SOMMEIL APPLE SANTÉ AUTORISÉ (agrégats locaux, aucune phase détaillée ni horaire brut).
        Couverture : \(coverage7)/7 journées récentes, \(coverage14)/14 journées ; moyenne récente : \(recent) ; précédente : \(past).
        Nuits de moins de 6 h dans les sept derniers jours : \(shortNights7) (simple description, pas un diagnostic).
        Nuits disponibles : \(nightly.isEmpty ? "aucune" : nightly).
        Seuls les segments de sommeil mesurés, dédoublonnés par source et regroupés de midi à midi, sont comptés.
        Les montres estiment le sommeil imparfaitement ; ne déduis ni stade fiable, ni score de récupération, ni pathologie.
        N'utilise ce contexte qu'avec la charge d'entraînement et le ressenti. Toute adaptation doit être proposée et validée.
        """
    }
}

enum PaceSleepRules {
    /// A "night" runs noon-to-noon in the user's calendar to keep sleep spanning midnight together.
    /// This groups daytime naps with the relevant 24-hour period rather than classifying insomnia.
    static func summarize(_ intervals:[PaceSleepInterval], now:Date = .now,
                          calendar:Calendar = .current) -> PaceSleepSummary {
        let lastDay = calendar.startOfDay(for:now.addingTimeInterval(-12*3600))
        guard let cutoff = calendar.date(byAdding:.day,value:-13,to:lastDay) else {
            return PaceSleepSummary(nights:[],mostRecent7AverageMinutes:nil,
                previous7AverageMinutes:nil,shortNights7:0,coverage7:0,coverage14:0)
        }
        // Ignore bed/awake records (stage 0/2); 1 and 3..5 represent sleep.
        let useful=intervals.filter {
            [1,3,4,5].contains($0.stage) && $0.start < $0.end &&
            $0.end <= now && $0.start >= cutoff.addingTimeInterval(-12*3600) &&
            $0.end.timeIntervalSince($0.start) <= 18*3600 && !$0.source.isEmpty
        }
        let grouped=Dictionary(grouping:useful) { value -> Date in
            calendar.startOfDay(for:value.end.addingTimeInterval(-12*3600))
        }
        let nights = grouped.compactMap { day, samples -> PaceSleepNight? in
            guard day >= cutoff && day <= lastDay else { return nil }
            let bySource=Dictionary(grouping:samples,by:\.source)
            // Use exactly ONE source per night; never add an Apple Watch estimate
            // to a duplicated sleep block imported from a second device.
            let candidate=bySource.compactMap { source, values -> (String,Int)? in
                let merged=mergeDuration(values.map { ($0.start,$0.end) })
                return merged > 0 ? (source,merged) : nil
            }.sorted { lhs,rhs in
                if lhs.1 == rhs.1 { return lhs.0 < rhs.0 }
                return lhs.1 > rhs.1
            }.first
            guard let candidate else { return nil }
            return PaceSleepNight(day:day,minutesAsleep:candidate.1,source:candidate.0)
        }.sorted { $0.day > $1.day }

        let sevenStart = calendar.date(byAdding:.day,value:-6,to:lastDay) ?? lastDay
        let recent=nights.filter { $0.day >= sevenStart }
        let older=nights.filter { $0.day < sevenStart }
        let average:([PaceSleepNight])->Int? = { values in
            guard values.count >= 3 else { return nil }
            return Int((Double(values.reduce(0) { $0 + $1.minutesAsleep }) /
                        Double(values.count)).rounded())
        }
        return PaceSleepSummary(nights:nights,
                                mostRecent7AverageMinutes:average(recent),
                                previous7AverageMinutes:average(older),
                                shortNights7:recent.filter { $0.minutesAsleep < 360 }.count,
                                coverage7:recent.count,coverage14:nights.count)
    }

    static func mergeDuration(_ intervals:[(Date,Date)]) -> Int {
        let sorted=intervals.filter { $0.0 < $0.1 }
            .sorted { $0.0 < $1.0 }
        guard let first=sorted.first else { return 0 }
        var lower=first.0,upper=first.1
        var total:TimeInterval=0
        for (start,end) in sorted.dropFirst() {
            if start <= upper {
                if end > upper { upper=end }
            } else {
                total += upper.timeIntervalSince(lower)
                lower=start;upper=end
            }
        }
        total += upper.timeIntervalSince(lower)
        return max(0,Int((total/60).rounded()))
    }
}
