import Foundation
func make(_ s: Int) -> String {
    let d = Date(timeIntervalSince1970: 1793520000 + Double(s))
    return ISO8601DateFormatter().string(from: d)
}
let start=make(0), end=make(1800)
let samples:[(timestamp:String,bpm:Double)] = [
    (make(1750),160), (make(10),105), (make(15),115),
    (make(800),148), (make(1801),170), (make(-50),80),
    (make(250),250), (make(1400),Double.nan)
]
guard let result = PaceHeartTimeline.prepare(start:start,end:end,samples:samples) else {fatalError("No result")}
assert(result.points.count == 4)
assert(result.points[0].minute < result.points[1].minute)
assert(result.points[0].bpm == 105)
assert(result.points.last!.bpm == 160)
assert(result.durationMinutes == 30)
assert(result.gapCount == 2)
assert(result.unmeasuredTailMinutes > 0)
assert(result.yLower < result.minBPM && result.yUpper > result.maxBPM)
let continuous:[(timestamp:String,bpm:Double)] = (0..<31).map { (make($0*60), 110.0 + Double($0)) }
let full = PaceHeartTimeline.prepare(start:start,end:end,samples:continuous)!
assert(full.gapCount == 0)
assert(full.unmeasuredTailMinutes == 0)
let fractional = ISO8601DateFormatter()
fractional.formatOptions = [.withInternetDateTime,.withFractionalSeconds]
assert(PaceHeartTimeline.decodeDate(fractional.string(from:Date(timeIntervalSince1970:1793520000.125))) != nil)
assert(PaceHeartTimeline.prepare(start:start,end:start,samples:samples) == nil)
print("V3.9_HEART_TESTS_OK: timestamps, exclusions, gaps, coverage, scales, fractional ISO8601")
