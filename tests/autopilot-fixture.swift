import Foundation

struct PaceDay { let date:String; let type:String; let minutes:Double }
struct WorkoutPayload { let isRun:Bool; let endDate:Date }
struct PaceSessionNote { let effort:Int?; let pain:Int? }
struct PaceLongitudinalSnapshot {
    let comparisonPercent:Double?
    let weeklyRunsNewestFirst:[Int]
    let recent28Runs:Int
    let recent28Km:Double
}
struct PaceSleepSummary {
    let coverage7:Int
    let coverage14:Int
    let mostRecent7AverageMinutes:Int?
    let previous7AverageMinutes:Int?
}

@main struct AutopilotFixture {
    static func require(_ condition:Bool,_ message:String) {
        if !condition { fputs("FAIL "+message+"\n",stderr); exit(1) }
    }
    static func main() {
        let now=Date(timeIntervalSince1970:1_793_611_200)
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"en_US_POSIX")
        formatter.dateFormat="yyyy-MM-dd"
        let tomorrow=Calendar.current.date(byAdding:.day,value:1,to:Calendar.current.startOfDay(for:now))!
        let day=PaceDay(date:formatter.string(from:tomorrow),type:"Course",minutes:45)
        let run=WorkoutPayload(isRun:true,endDate:now.addingTimeInterval(-3600))
        let calm=PaceLongitudinalSnapshot(comparisonPercent:nil,
                                            weeklyRunsNewestFirst:[0,0,0,0],recent28Runs:0,recent28Km:0)
        let highTrend=PaceLongitudinalSnapshot(comparisonPercent:55,
                                            weeklyRunsNewestFirst:[2,2,2,2],recent28Runs:8,recent28Km:30)
        let noSleep=PaceSleepSummary(coverage7:0,coverage14:0,
                                     mostRecent7AverageMinutes:nil,previous7AverageMinutes:nil)
        let shortSleep=PaceSleepSummary(coverage7:5,coverage14:12,
                                        mostRecent7AverageMinutes:330,previous7AverageMinutes:425)
        func evaluate(_ action:String="easier",_ note:PaceSessionNote?=nil,
                      _ trend:PaceLongitudinalSnapshot=calm,_ sleep:PaceSleepSummary=noSleep,
                      _ target:PaceDay?=nil,_ already:Bool=false,
                      _ lastChange:Date?=nil) -> PaceAutopilotGuard.Decision {
            PaceAutopilotGuard.assess(action:action,target:target ?? day,lastRun:run,
                                     lastNote:note,trend:trend,sleep:sleep,
                                     hasPriorAdjustment:already,lastAutomaticChange:lastChange,now:now)
        }
        require(!evaluate("maintain",PaceSessionNote(effort:9,pain:2)).allowed,
                "maintain does not change program")
        require(!evaluate("review",PaceSessionNote(effort:9,pain:2)).allowed,
                "manual review is not autonomous")
        require(!evaluate().allowed,"unknown values are not signals")
        require(!evaluate("easier",PaceSessionNote(effort:9,pain:0)).allowed,
                "one subjective domain cannot trigger")
        require(!evaluate("easier",PaceSessionNote(effort:9,pain:2)).allowed,
                "effort and mild pain from same session are correlated")
        require(!evaluate("easier",PaceSessionNote(effort:3,pain:4),highTrend,shortSleep).allowed,
                "significant pain requires human review")
        let valid=evaluate("easier",PaceSessionNote(effort:9,pain:0),highTrend)
        require(valid.allowed && valid.minutes==36,"two independent domains permit conservative 20% easing")
        require(!evaluate("easier",PaceSessionNote(effort:9,pain:0),highTrend,noSleep,nil,true).allowed,
                "already adjusted cannot be adjusted twice")
        require(!evaluate("easier",PaceSessionNote(effort:9,pain:0),highTrend,noSleep,nil,false,
                          now.addingTimeInterval(-2*86400)).allowed,
                "one automatic adjustment per 7 days")
        require(evaluate("easier",PaceSessionNote(effort:9,pain:nil),calm,shortSleep).allowed,
                "declared effort plus changed personal sleep baseline")
        require(!evaluate("easier",PaceSessionNote(effort:9,pain:nil),calm,
                          PaceSleepSummary(coverage7:2,coverage14:8,
                              mostRecent7AverageMinutes:330,previous7AverageMinutes:425)).allowed,
                "sleep missing coverage cannot justify")
        require(!evaluate("easier",PaceSessionNote(effort:9,pain:nil),calm,
                          PaceSleepSummary(coverage7:5,coverage14:12,
                              mostRecent7AverageMinutes:330,previous7AverageMinutes:nil)).allowed,
                "sleep without personal baseline cannot justify")
        require(!evaluate("easier",PaceSessionNote(effort:9,pain:0),highTrend,noSleep,
                          PaceDay(date:day.date,type:"Musculation",minutes:45)).allowed,
                "no autonomous strength changes")
        require(!evaluate("easier",PaceSessionNote(effort:9,pain:0),highTrend,noSleep,
                          PaceDay(date:day.date,type:"Course",minutes:15)).allowed,
                "do not change already short sessions")

        let observed=PaceAutopilotSignificance.evidence(
            note:PaceSessionNote(effort:9,pain:2),trend:highTrend,sleep:noSleep)
        let sparseHigh=PaceLongitudinalSnapshot(comparisonPercent:80,
                                            weeklyRunsNewestFirst:[5,0,0,0],recent28Runs:5,recent28Km:45)
        require(!evaluate("easier",PaceSessionNote(effort:9,pain:0),sparseHigh).allowed,
                "no training trend decision from one week of activity")
        require(!PaceAutopilotSignificance.evidence(
                    note:nil,trend:sparseHigh,sleep:noSleep).contains(where:{$0.id=="training"}),
                "sparse history not treated as longitudinal signal")
        require(observed.count==2 && observed.map(\.id)==["subjective","training"],
                "subjective and training are distinct domains")
        require(PaceAutopilotSignificance.reconcile(action:"easier",
                claimedEvidenceIDs:["subjective","training"],supported:observed),
                "model evidence references verified local sources")
        require(!PaceAutopilotSignificance.reconcile(action:"easier",
                claimedEvidenceIDs:["subjective","subjective"],supported:observed),
                "duplicate evidence is not independent")
        require(!PaceAutopilotSignificance.reconcile(action:"easier",
                claimedEvidenceIDs:["subjective","sleep"],supported:observed),
                "AI cannot claim absent evidence")
        require(!PaceAutopilotSignificance.reconcile(action:"maintain",
                claimedEvidenceIDs:["subjective","training"],supported:observed),
                "model cannot mutate on maintain")
        print("PASS: meaningful coach decisions, independent evidence, personal sleep baseline, cooldown and grounded AI claims.")
    }
}
