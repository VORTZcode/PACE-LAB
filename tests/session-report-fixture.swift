import Foundation

// Standalone fixture: swiftc ios/PaceLabCompanion/PaceCoachReport.swift
// tests/session-report-fixture.swift -o /tmp/pace-report-fixture && /tmp/pace-report-fixture
enum PaceChatError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

@main struct SessionReportFixture {
    static func main() throws {
        let valid = """
        {"title":"Sortie facile","summary":"Les données montrent une sortie enregistrée.","observations":["Durée enregistrée : 32 min"],"recommendations":["Conserver une intensité facile"],"uncertainties":["Ressenti non renseigné"],"trainingImpact":"Ne pas modifier la semaine sur cette seule séance."}
        """
        let report = try PaceCoachSessionReport.extract(valid,workoutID:"synthetic")
        precondition(report.workoutID == "synthetic")
        precondition(report.observations.count == 1)

        func expectMissing(_ payload:String,_ section:String) {
            do {
                _ = try PaceCoachSessionReport.extract(payload,workoutID:"synthetic")
                fatalError("A report without \(section) was accepted")
            } catch {
                precondition(error.localizedDescription.contains(section),
                             "Wrong diagnostic: \(error.localizedDescription)")
            }
        }
        expectMissing(valid.replacingOccurrences(of:
            "\"uncertainties\":[\"Ressenti non renseigné\"]",
            with:"\"uncertainties\":[]"),"limites ou données inconnues")
        expectMissing(valid.replacingOccurrences(of:
            "\"observations\":[\"Durée enregistrée : 32 min\"]",
            with:"\"observations\":[]"),"observations étayées")
        expectMissing(valid.replacingOccurrences(of:
            "\"trainingImpact\":\"Ne pas modifier la semaine sur cette seule séance.\"",
            with:"\"trainingImpact\":\" \""),"conséquence justifiée")
        expectMissing("not valid JSON","format exploitable")
        print("PASS: full report accepted; empty evidence, limits and impact rejected with precise diagnostics")
    }
}
