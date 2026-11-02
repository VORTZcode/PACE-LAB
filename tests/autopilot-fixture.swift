import Foundation

struct PaceDay { let date:String; let type:String; let minutes:Double }
struct WorkoutPayload { let isRun:Bool; let endDate:Date }
struct PaceSessionNote { let effort:Int?; let pain:Int? }
struct PaceLongitudinalSnapshot { let comparisonPercent:Double? }
struct PaceSleepSummary { let coverage7:Int; let mostRecent7AverageMinutes:Int? }

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
        let calm=PaceLongitudinalSnapshot(comparisonPercent:nil)
        let noSleep=PaceSleepSummary(coverage7:0,mostRecent7AverageMinutes:nil)
        func evaluate(_ action:String="easier",_ note:PaceSessionNote?=nil,
                      _ trend:PaceLongitudinalSnapshot=calm,_ sleep:PaceSleepSummary=noSleep,
                      _ target:PaceDay?=nil,_ already:Bool=false,
                      _ lastRun:WorkoutPayload?=nil) -> PaceAutopilotGuard.Decision {
            PaceAutopilotGuard.assess(action:action,target:target ?? day,
                                     lastRun:lastRun ?? run,lastNote:note,
                                     trend:trend,sleep:sleep,
                                     hasPriorAdjustment:already,now:now)
        }
        require(!evaluate("maintain",PaceSessionNote(effort:9,pain:2)).allowed,"never change on maintain")
        require(!evaluate("review",PaceSessionNote(effort:9,pain:2)).allowed,"review is never unattended")
        require(!evaluate("easier",nil).allowed,"no inference from absent data")
        require(!evaluate("easier",PaceSessionNote(effort:9,pain:0)).allowed,"one sign is not enough")
        require(!evaluate("easier",PaceSessionNote(effort:3,pain:4),
                          PaceLongitudinalSnapshot(comparisonPercent:50)).allowed,"pain blocks automation")
        let two=evaluate("easier",PaceSessionNote(effort:9,pain:2))
        require(two.allowed && two.minutes==36,"two signals permit 20 pct conservative reduction")
        require(!evaluate("easier",PaceSessionNote(effort:9,pain:2),calm,noSleep,nil,true).allowed,"no repeated edits")
        let shortSleep=PaceSleepSummary(coverage7:5,mostRecent7AverageMinutes:330)
        require(evaluate("easier",PaceSessionNote(effort:9,pain:nil),calm,shortSleep).allowed,
                "low multi-night sleep + high effort")
        require(!evaluate("easier",PaceSessionNote(effort:9,pain:nil),calm,
                          PaceSleepSummary(coverage7:2,mostRecent7AverageMinutes:330)).allowed,
                "sleep cannot support low-quality evidence")
        require(!evaluate("easier",PaceSessionNote(effort:9,pain:2),calm,noSleep,
                          PaceDay(date:day.date,type:"Musculation",minutes:45)).allowed,
                "never auto-mutate strength")
        require(!evaluate("easier",PaceSessionNote(effort:9,pain:2),calm,noSleep,
                          PaceDay(date:day.date,type:"Course",minutes:15)).allowed,
                "never reduce a short run")
        print("PASS: autonomous safety gate, missing data, no-load-increase, serious pain, duplicate prevention, sleep coverage")
    }
}
