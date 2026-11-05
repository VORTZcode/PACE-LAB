import Foundation

@main struct PaceHealthCoverageFixture {
    static func main() {
        let entries = PaceHealthCoverageCatalog.all
        precondition(entries.count >= 15)
        precondition(Set(entries.map(\.id)).count == entries.count,
                     "Capability identifiers must be unique")
        for domain in PaceHealthDataDomain.allCases {
            precondition(!PaceHealthCoverageCatalog.grouped(domain).isEmpty)
        }
        precondition(entries.first(where: { $0.id == "workout-routes" })?.neverShareRawByDefault == true)
        precondition(entries.first(where: { $0.id == "hrv-sdnn" })?.stage == .partialPipeline)
        precondition(entries.first(where: { $0.id == "vo2max" })?.stage == .planned)
        precondition(entries.first(where: { $0.id == "body-fat-percentage" })?.stage == .planned)
        precondition(entries.first(where: { $0.id == "sleep" })?.stage == .partialPipeline)
        precondition(PaceHealthCoverageCatalog.planned.count >= 4)
        print("PASS: unique capability IDs, per-domain inventory, no false HRV/VO2/body-composition support, GPS privacy.")
    }
}
