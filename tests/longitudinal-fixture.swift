import Foundation

struct PaceSessionNote { var effort:Int?; var pain:Int? }
struct WorkoutPayload {
    let source_uuid:String
    let startDate:Date
    let endDate:Date
    let kilometers:Double
    let duration_seconds:Double
    let isRun:Bool
}
@main struct LongitudinalFixture {
    static func check(_ value:Bool,_ message:String) {
        if !value { fputs("FAIL: "+message+"\n",stderr); exit(1) }
    }
    static func main() {
        let anchor=Date(timeIntervalSince1970:1_780_000_000)
        let empty=PaceLongitudinalRules.calculate(runs:[],notes:[:],now:anchor)
        check(empty.recent28Runs == 0 && empty.comparisonPercent == nil,"no invented history")
        check(empty.weeklyKmNewestFirst.count == 8,"eight periods")
        func run(_ id:String,daysAgo:Double,km:Double=4,duration:Double=2100,isRun:Bool=true)->WorkoutPayload{
            let start=anchor.addingTimeInterval(-daysAgo*86400)
            return .init(source_uuid:id,startDate:start,endDate:start.addingTimeInterval(1800),
                         kilometers:km,duration_seconds:duration,isRun:isRun)
        }
        let older=(0..<4).map { run("older-\($0)",daysAgo:Double(31+7*$0),km:3) }
        let newer=(0..<4).map { run("newer-\($0)",daysAgo:Double(3+7*$0),km:6) }
        let all=older+newer
        let notes:[String:PaceSessionNote]=[
            "newer-0":.init(effort:9,pain:5),
            "newer-1":.init(effort:8,pain:0),
            "newer-2":.init(effort:3,pain:0),
            "newer-3":.init(effort:5,pain:0)
        ]
        let analysis=PaceLongitudinalRules.calculate(
            runs:all + [newer[0],run("future",daysAgo:-1),run("not-run",daysAgo:2,isRun:false),
                        run("invalid",daysAgo:2,km:-2),run("no-duration",daysAgo:2,duration:0),
                        run("old",daysAgo:65)],
            notes:notes,now:anchor)
        check(analysis.recent28Runs==4,"four recent runs and deduplication")
        check(analysis.previous28Runs==4,"four prior runs")
        check(abs(analysis.recent28Km-24)<0.001,"recent volume")
        check(abs(analysis.previous28Km-12)<0.001,"previous volume")
        check(abs((analysis.comparisonPercent ?? 0)-100)<0.001,"56 day comparison")
        check(analysis.recent7MaximumDiscomfort==5,"pain directly reported")
        check(analysis.recent7HighEffort==1,"RPE of latest week")
        check(analysis.feedbackCount28==4 && analysis.missingFeedback28==0,"four notes complete")
        let missing=PaceLongitudinalRules.calculate(runs:all,notes:[:],now:anchor)
        check(missing.missingFeedback28==4,"absence is unknown, not zero")
        let sparse=PaceLongitudinalRules.calculate(runs:[run("a",daysAgo:1)],notes:[:],now:anchor)
        check(sparse.comparisonPercent == nil && sparse.evidenceQuality=="Historique limité","sparse baseline")
        check(sparse.weeklyKmNewestFirst.reduce(0,+) == 4,"one run counted once")
        print("PASS: longitudinal trends, deduplication, sparse data, user RPE, pain and 56-day comparison")
    }
}