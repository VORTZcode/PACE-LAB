import Foundation

@main struct PaceStrengthEvidenceFixture {
    static func main() {
        let now = Date(timeIntervalSince1970: 1793800000)
        let valid: [PaceMeasuredStrengthSet] = [
            .init(name:"Goblet squat",completedAt:now.addingTimeInterval(-18*86400),
                  isTimed:false,countOrSeconds:10,weightKg:8),
            .init(name:"Goblet squat",completedAt:now.addingTimeInterval(-10*86400),
                  isTimed:false,countOrSeconds:12,weightKg:10),
            .init(name:"Planche",completedAt:now.addingTimeInterval(-5*86400),
                  isTimed:true,countOrSeconds:30,weightKg:nil),
            .init(name:"Planche",completedAt:now.addingTimeInterval(-1*86400),
                  isTimed:true,countOrSeconds:45,weightKg:nil),
            .init(name:"Goblet squat",completedAt:now.addingTimeInterval(86400),
                  isTimed:false,countOrSeconds:100,weightKg:50),
            .init(name:"Goblet squat",completedAt:now.addingTimeInterval(-5*86400),
                  isTimed:false,countOrSeconds:0,weightKg:8)
        ]
        let summary = PaceStrengthEvidence.summarize(valid,at:now)
        precondition(summary.count == 2)
        let squat = summary.first { $0.id == "goblet squat" }!
        precondition(squat.completedSets == 2)
        precondition(squat.sessions == 2)
        precondition(squat.maxRepetitions == 12)
        precondition(squat.maxWeightKg == 10)
        precondition(squat.indicativeVolumeKgReps == 200)
        let plank = summary.first { $0.id == "planche" }!
        precondition(plank.maxDurationSeconds == 45)
        precondition(plank.maxWeightKg == nil)
        precondition(plank.maxRepetitions == nil)
        print("PASS: strength repetitions, volume, distinct days, timed sets, invalid entries and missing loads.")
    }
}
