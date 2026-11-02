import SwiftUI

private struct PaceInterval: Identifiable, Sendable {
    let id: Int
    let startMinute: Int
    let endMinute: Int
    let avgBPM: Double?
    let avgSpeed: Double?
    let avgWatts: Double?
}

private struct PaceBucket: Sendable {
    var heartSum = 0.0
    var heartCount = 0
    var speedSum = 0.0
    var speedCount = 0
    var wattsSum = 0.0
    var wattsCount = 0
}

/// Process each sensor series exactly once, off the main thread.
/// Old implementation scanned/parses each sample again for every 5-minute row.
private enum PaceIntervalCalculator {
    nonisolated static func calculate(_ workout: WorkoutPayload) -> [PaceInterval] {
        guard workout.isRun, workout.duration_seconds >= 300 else { return [] }
        let count = min(60, Int(ceil(workout.duration_seconds / 300)))
        guard count > 0 else { return [] }
        var buckets = Array(repeating: PaceBucket(), count: count)
        let clock = ISO8601DateFormatter()
        guard let start = clock.date(from: workout.started_at) else { return [] }

        for p in workout.heart_rate_series {
            guard p.bpm.isFinite, (25...245).contains(p.bpm),
                  let date = clock.date(from: p.timestamp) else { continue }
            let elapsed = date.timeIntervalSince(start)
            guard elapsed >= 0, elapsed < workout.duration_seconds else { continue }
            let index = min(count - 1, Int(elapsed / 300))
            buckets[index].heartSum += p.bpm
            buckets[index].heartCount += 1
        }
        for p in workout.speed_series ?? [] {
            guard p.value.isFinite, (0.7...12).contains(p.value),
                  let date = clock.date(from: p.timestamp) else { continue }
            let elapsed = date.timeIntervalSince(start)
            guard elapsed >= 0, elapsed < workout.duration_seconds else { continue }
            let index = min(count - 1, Int(elapsed / 300))
            buckets[index].speedSum += p.value
            buckets[index].speedCount += 1
        }
        for p in workout.power_series ?? [] {
            guard p.value.isFinite, (1...1800).contains(p.value),
                  let date = clock.date(from: p.timestamp) else { continue }
            let elapsed = date.timeIntervalSince(start)
            guard elapsed >= 0, elapsed < workout.duration_seconds else { continue }
            let index = min(count - 1, Int(elapsed / 300))
            buckets[index].wattsSum += p.value
            buckets[index].wattsCount += 1
        }
        return buckets.enumerated().map { index, b in
            PaceInterval(
                id: index, startMinute: index*5,
                endMinute: min(Int(ceil(workout.duration_seconds / 60)), (index+1)*5),
                avgBPM: b.heartCount > 0 ? b.heartSum/Double(b.heartCount) : nil,
                avgSpeed: b.speedCount > 0 ? b.speedSum/Double(b.speedCount) : nil,
                avgWatts: b.wattsCount > 0 ? b.wattsSum/Double(b.wattsCount) : nil
            )
        }
    }
}

struct RunIntervalsSection: View {
    let workout: WorkoutPayload
    @EnvironmentObject private var engine: HealthSyncEngine
    @State private var showAll = false
    @State private var intervals: [PaceInterval] = []
    @State private var isLoading = false

    private var w: WorkoutPayload { engine.workout(id: workout.source_uuid) ?? workout }
    private var dataKey: String {
        let item = w
        return "\(item.source_uuid)|\(item.heart_rate_series.count)|\(item.speed_series?.count ?? 0)|\(item.power_series?.count ?? 0)"
    }

    var body: some View {
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
                    if isLoading && intervals.isEmpty {
                        ProgressView("Préparation des intervalles")
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                    } else {
                        ForEach(Array(intervals.prefix(showAll ? intervals.count : 6))) { item in
                            HStack(spacing: 5) {
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
                            if item.id != (showAll ? intervals : Array(intervals.prefix(6))).last?.id {
                                Divider()
                            }
                        }
                        if intervals.count > 6 {
                            Button {
                                showAll.toggle()
                            } label: {
                                HStack {
                                    Image(systemName: showAll ? "chevron.up" : "chevron.down")
                                    Text(showAll ? "Réduire" : "Afficher les \(intervals.count) tranches")
                                }
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(PaceColors.teal)
                            .padding(.top, 6)
                        }
                    }
                }
            }
            Text("Tranches temporelles calculées à partir des échantillons disponibles. Ce ne sont ni des kilomètres intermédiaires ni des tours Apple.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .task(id: dataKey) {
            let input = w
            guard input.isRun, input.duration_seconds >= 300 else { return }
            isLoading = true
            let result = await Task.detached(priority: .userInitiated) {
                PaceIntervalCalculator.calculate(input)
            }.value
            guard !Task.isCancelled else { return }
            intervals = result
            isLoading = false
        }
    }
}
