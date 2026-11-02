import Foundation

/// Real elapsed-time positions for Apple Watch heart samples.
/// Never interpolates missing heart-rate data and never extends a line beyond the last measurement.
enum PaceHeartTimeline {
    struct Point: Identifiable {
        let id: Int
        let minute: Double
        let bpm: Double
        let segment: Int
    }
    struct Result {
        let points: [Point]
        let durationMinutes: Double
        let firstMinute: Double
        let lastMinute: Double
        let gapCount: Int
        let minBPM: Double
        let maxBPM: Double

        var unmeasuredTailMinutes: Double { max(0, durationMinutes - lastMinute) }
        var hasMissingTail: Bool { unmeasuredTailMinutes > 1.5 }
        var yLower: Double { max(30, floor(minBPM / 10) * 10 - 10) }
        var yUpper: Double { min(245, ceil(maxBPM / 10) * 10 + 10) }
    }

    static func decodeDate(_ value: String) -> Date? {
        let plain = ISO8601DateFormatter()
        if let d = plain.date(from: value) { return d }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value)
    }

    static func prepare(start: String, end: String, samples: [(timestamp:String,bpm:Double)]) -> Result? {
        guard let started = decodeDate(start), let ended = decodeDate(end),
              ended > started else { return nil }
        let duration = ended.timeIntervalSince(started) / 60
        let sorted = samples.compactMap { item -> (Double,Double)? in
            guard let date = decodeDate(item.timestamp),
                  date >= started, date <= ended,
                  item.bpm.isFinite, (25...245).contains(item.bpm) else { return nil }
            return (date.timeIntervalSince(started)/60,item.bpm)
        }.sorted { $0.0 < $1.0 }
        guard let first = sorted.first, let last = sorted.last else { return nil }
        var segment = 0
        var gaps = 0
        var points: [Point] = []
        for (index,item) in sorted.enumerated() {
            if index > 0, item.0 - sorted[index-1].0 > 2 {
                segment += 1
                gaps += 1
            }
            points.append(Point(id:index,minute:item.0,bpm:item.1,segment:segment))
        }
        return Result(points:points,
                      durationMinutes:duration,
                      firstMinute:first.0,
                      lastMinute:last.0,
                      gapCount:gaps,
                      minBPM:sorted.map(\.1).min() ?? first.1,
                      maxBPM:sorted.map(\.1).max() ?? first.1)
    }
}
