import SwiftUI


private struct PaceInterval: Identifiable {
    let id: Int
    let startMinute: Int
    let endMinute: Int
    let avgBPM: Double?
    let avgSpeed: Double?
    let avgWatts: Double?
}

struct RunIntervalsSection: View {
    let workout: WorkoutPayload
    @EnvironmentObject private var engine: HealthSyncEngine
    @State private var showAll = false
    private var w: WorkoutPayload { engine.snapshot.first { $0.source_uuid == workout.source_uuid } ?? workout }

    private var intervals: [PaceInterval] {
        guard w.isRun, w.duration_seconds >= 5 * 60 else { return [] }
        let windowCount = min(60, Int(ceil(w.duration_seconds / 300)))
        return (0..<windowCount).map { bucket in
            let begin = w.startDate.addingTimeInterval(Double(bucket * 300))
            let end = min(w.endDate, begin.addingTimeInterval(300))
            let h = w.heart_rate_series.compactMap { sample -> Double? in
                guard let date = PaceFormat.iso.date(from: sample.timestamp),
                      date >= begin, date < end else { return nil }
                return sample.bpm
            }
            func average(_ points: [PaceSensorPoint]?) -> Double? {
                let samples = (points ?? []).compactMap { sample -> Double? in
                    guard let date = PaceFormat.iso.date(from: sample.timestamp),
                          date >= begin, date < end, sample.value > 0 else { return nil }
                    return sample.value
                }
                guard !samples.isEmpty else { return nil }
                return samples.reduce(0,+)/Double(samples.count)
            }
            return PaceInterval(id: bucket,
                                startMinute: bucket*5,
                                endMinute: min(Int(ceil(w.duration_seconds/60)), (bucket+1)*5),
                                avgBPM: h.isEmpty ? nil : h.reduce(0,+)/Double(h.count),
                                avgSpeed: average(w.speed_series),
                                avgWatts: average(w.power_series))
        }
    }

    var body: some View {
        if !intervals.isEmpty {
            VStack(alignment: .leading, spacing: 13) {
                PaceSectionTitle(title: "Par tranches de 5 minutes")
                PaceCard {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Temps").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Allure").frame(maxWidth: .infinity, alignment: .trailing)
                            Text("FC").frame(maxWidth: .infinity, alignment: .trailing)
                            Text("W").frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 12)
                        ForEach(Array(intervals.prefix(showAll ? intervals.count : 6))) { item in
                            HStack {
                                Text("\(item.startMinute)–\(item.endMinute)'")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(item.avgSpeed.flatMap { $0 > 0.7 ? PaceFormat.pace(1000 / ($0 * 60)) : nil } ?? "—")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text(PaceFormat.heart(item.avgBPM))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text(item.avgWatts.map { "\(Int($0.rounded()))" } ?? "—")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .font(.footnote)
                            .monospacedDigit()
                            .padding(.vertical, 9)
                            if item.id != intervals.prefix(showAll ? intervals.count : 6).last?.id {
                                Divider()
                            }
                        }
                        if intervals.count > 6 {
                            Button(showAll ? "Réduire" : "Afficher toutes les tranches") { showAll.toggle() }
                                .font(.subheadline.weight(.semibold))
                                .tint(PaceColors.teal)
                                .padding(.top, 13)
                        }
                    }
                }
                Text("Découpage temporel calculé par PACE LAB, différent des kilomètres intermédiaires ou tours officiels. Moyennes des échantillons disponibles uniquement.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
