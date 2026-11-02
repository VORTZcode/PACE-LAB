import Foundation

@main struct SleepFixture {
    static func expect(_ value:Bool,_ message:String) {
        if !value { fputs("FAIL: "+message+"\n",stderr); exit(1) }
    }
    static func main() {
        var calendar=Calendar(identifier:.gregorian)
        calendar.timeZone=TimeZone(secondsFromGMT:0)!
        let iso=ISO8601DateFormatter()
        let now=iso.date(from:"2026-11-15T11:00:00Z")!
        func entry(_ day:Int, _ start:String,_ end:String,_ stage:Int,
                   source:String="watch")->PaceSleepInterval {
            let prefix="2026-11-"
            return PaceSleepInterval(source:source,start:iso.date(from:prefix+start)!,
                                     end:iso.date(from:prefix+end)!,stage:stage)
        }
        // Nov 13 22:00 through Nov 14 06:00 belongs to Nov 13 night,
        // including two staged samples and one overlapping duplicate.
        let night=[
            entry(13,"13T22:00:00Z","13T23:00:00Z",3),
            entry(13,"13T22:30:00Z","13T23:00:00Z",3),
            entry(14,"14T00:00:00Z","14T06:00:00Z",5),
            entry(13,"13T22:00:00Z","14T06:00:00Z",0),
            entry(14,"14T02:00:00Z","14T02:30:00Z",2),
            entry(14,"14T00:00:00Z","14T06:00:00Z",3,source:"imported")
        ]
        let info=PaceSleepRules.summarize(night,now:now,calendar:calendar)
        expect(info.nights.count==1,"one night not two")
        expect(info.nights[0].minutesAsleep==420,"union 60+360 min; no duplicated source/stage")
        expect(info.nights[0].source=="watch","source selection stable")
        expect(info.coverage7==1 && info.mostRecent7AverageMinutes==nil,"missing 7-day nights not a valid mean")
        let inBed=PaceSleepRules.summarize(night.filter{$0.stage==0 || $0.stage==2},now:now,calendar:calendar)
        expect(inBed.nights.isEmpty,"in-bed and awake are not asleep")
        // Overlapping intervals combine into a union, not a sum.
        let base=iso.date(from:"2026-11-10T01:00:00Z")!
        let joined=PaceSleepRules.mergeDuration([
            (base,base.addingTimeInterval(3600)),
            (base.addingTimeInterval(1800),base.addingTimeInterval(7200)),
            (base.addingTimeInterval(10800),base.addingTimeInterval(12600))])
        expect(joined==150,"two hours plus half an hour")
        var many:[PaceSleepInterval]=[]
        for day in 1...14 {
            let date=String(format:"%02d",day)
            let next=String(format:"%02d",day+1)
            many.append(entry(day,date+"T22:00:00Z",next+"T05:00:00Z",3))
        }
        let full=PaceSleepRules.summarize(many,now:now,calendar:calendar)
        expect(full.coverage14==14 && full.coverage7==7,"14 covered nights")
        expect(full.mostRecent7AverageMinutes==420 && full.previous7AverageMinutes==420,"seven-day means")
        expect(full.shortNights7==0,"adequate nights not short")
        expect(!full.promptContext.contains("22:00"),"AI summary contains no raw sleep timestamps")
        print("PASS sleep 14 nights, overlap union, no double source, skip in-bed, no invented mean, prompt privacy")
    }
}