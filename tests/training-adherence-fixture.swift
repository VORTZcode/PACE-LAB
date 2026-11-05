import Foundation

@main struct PaceTrainingAdherenceFixture {
    static func main() {
        let plan: [PaceTrainingPlanEntry] = [
            .init(date:"2026-11-02",type:"Course",minutes:30),
            .init(date:"2026-11-03",type:"Musculation",minutes:35),
            .init(date:"2026-11-04",type:"Course",minutes:35),
            .init(date:"2026-11-05",type:"Course",minutes:40),
            .init(date:"2026-11-06",type:"Musculation",minutes:30),
            .init(date:"2026-11-07",type:"Repos",minutes:0)
        ]
        let workouts: [PaceTrainingWorkoutEntry] = [
            .init(uuid:"run-monday",day:"2026-11-02",kind:"running",seconds:1810),
            .init(uuid:"strength-tuesday",day:"2026-11-03",kind:"strength",seconds:2300),
            .init(uuid:"run-thu-am",day:"2026-11-05",kind:"running",seconds:2000),
            .init(uuid:"run-thu-pm",day:"2026-11-05",kind:"running",seconds:1450),
            .init(uuid:"strength-friday",day:"2026-11-06",kind:"strength",seconds:1500)
        ]
        let result = PaceTrainingAdherence.calculate(
            planned: plan, workouts: workouts,
            confirmedUUIDByDay: ["2026-11-02":"run-monday"],
            completed: Set(["2026-11-02","2026-11-03"]),
            missed: Set(["2026-11-04"]))
        precondition(result.plannedTrainingCount == 5)
        precondition(result.confirmed == 1)
        precondition(result.selfReported == 1)
        precondition(result.missed == 1)
        precondition(result.ambiguous == 1)
        precondition(result.unconfirmedCandidates == 1)
        precondition(result.entries[0].workoutUUID == "run-monday")
        precondition(result.entries[0].actualMinutes! > 30)
        precondition(result.entries[1].workoutUUID == nil)
        precondition(result.entries[2].state == .missed)
        precondition(result.entries[3].state == .ambiguous)
        precondition(result.entries[4].state == .candidate)
        precondition(result.entries[5].state == .recoveryDay)

        // Wrong-type or missing UUID cannot become a confirmed performance.
        let wrong = PaceTrainingAdherence.calculate(
            planned: [plan[0]], workouts: workouts,
            confirmedUUIDByDay: ["2026-11-02":"strength-tuesday"],
            completed: [], missed: [])
        precondition(wrong.confirmed == 0 && wrong.unconfirmedCandidates == 1)

        let missing = PaceTrainingAdherence.calculate(
            planned: [plan[0]], workouts: [],
            confirmedUUIDByDay: [:], completed: ["2026-11-02"], missed: [])
        precondition(missing.selfReported == 1 && missing.confirmed == 0)
        print("PASS: plan adherence distinguishes confirmed HealthKit workout, self-report, missed, ambiguous, candidate and rest.")
    }
}
