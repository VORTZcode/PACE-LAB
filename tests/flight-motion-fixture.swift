import Foundation
import CoreLocation

@main struct PaceFlightFixture {
    static func main() {
        func close(_ actual: Double, _ expected: Double, tolerance: Double = 0.001) {
            precondition(abs(actual - expected) < tolerance, "\(actual) != \(expected)")
        }
        close(PaceFlightMotion.wrap(-5), 355)
        close(PaceFlightMotion.shortestTurn(from: 359, to: 1), 2)
        close(PaceFlightMotion.shortestTurn(from: 1, to: 359), -2)
        close(PaceFlightMotion.heading(previous: nil, desired: 92, seconds: 0.1), 92)
        let east = CLLocationCoordinate2D(latitude: 49, longitude: 1)
        let eastward = CLLocationCoordinate2D(latitude: 49, longitude: 1.002)
        let northward = CLLocationCoordinate2D(latitude: 49.001, longitude: 1)
        let tiny = CLLocationCoordinate2D(latitude: 49, longitude: 1.0000002)
        let dueEast = PaceFlightMotion.bearing(from: east, to: eastward)!
        let dueNorth = PaceFlightMotion.bearing(from: east, to: northward)!
        precondition((88...92).contains(dueEast))
        precondition((0...2).contains(dueNorth) || (358...360).contains(dueNorth))
        precondition(PaceFlightMotion.bearing(from: east, to: tiny) == nil, "Ignore GPS jitter")
        var heading = 350.0
        var last = heading
        for _ in 0..<100 {
            heading = PaceFlightMotion.heading(previous: heading, desired: 20, seconds: 0.1)
            precondition(abs(PaceFlightMotion.shortestTurn(from: last, to: heading)) <= 7.801)
            precondition(PaceFlightMotion.shortestTurn(from: last, to: heading) >= 0)
            last = heading
        }
        precondition(abs(PaceFlightMotion.shortestTurn(from: heading, to: 20)) < 0.1)
        let snapped = PaceFlightMotion.heading(previous: 350, desired: 20, seconds: 0.1, snap: true)
        close(snapped, 20)
        let center = PaceFlightMotion.center(previous: east, desired: eastward, seconds: 0.1)
        precondition(center.longitude > east.longitude && center.longitude < eastward.longitude)
        let centering = PaceFlightMotion.center(previous: east, desired: eastward, seconds: 0.1, snap: true)
        close(centering.longitude, eastward.longitude)
        print("PASS: camera heading wraps, ignores jitter, limits turn speed, follows smoothly, and snaps on user seek.")
    }
}
