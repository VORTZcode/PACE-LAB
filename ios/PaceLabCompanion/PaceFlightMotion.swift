import Foundation
import CoreLocation

/// Camera-only filtering. Recorded GPS fixes remain unchanged for display,
/// distance, and any future physiology calculations.
enum PaceFlightMotion {
    static func wrap(_ heading: Double) -> Double {
        (heading.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
    }

    static func shortestTurn(from: Double, to: Double) -> Double {
        let delta = wrap(to - from)
        return delta > 180 ? delta - 360 : delta
    }

    static func bearing(from start: CLLocationCoordinate2D,
                        to finish: CLLocationCoordinate2D,
                        minimumDistance: Double = 8) -> Double? {
        guard CLLocationCoordinate2DIsValid(start),
              CLLocationCoordinate2DIsValid(finish) else { return nil }
        let distance = CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: finish.latitude, longitude: finish.longitude))
        guard distance >= minimumDistance else { return nil }
        let a = start.latitude * .pi / 180
        let b = finish.latitude * .pi / 180
        let deltaLongitude = (finish.longitude - start.longitude) * .pi / 180
        let east = sin(deltaLongitude) * cos(b)
        let north = cos(a) * sin(b) - sin(a) * cos(b) * cos(deltaLongitude)
        return wrap(atan2(east, north) * 180 / .pi)
    }

    /// Circular exponential smoothing avoids a 359° -> 1° camera spin.
    /// Angular velocity is also bounded to prevent sharp MapKit yaw changes.
    static func heading(previous: Double?, desired: Double,
                        seconds: TimeInterval, snap: Bool = false) -> Double {
        guard let previous, !snap else { return wrap(desired) }
        let dt = min(0.3, max(0.01, seconds))
        let alpha = 1 - exp(-dt / 0.65)
        let delta = shortestTurn(from: previous, to: desired)
        let change = max(-78 * dt, min(78 * dt, delta * alpha))
        return wrap(previous + change)
    }

    /// Critically simple exponential camera easing: applied only to virtual
    /// camera height/pitch. Scrubbing is immediate, normal playback is smooth.
    static func scalar(previous: Double?, desired: Double,
                       seconds: TimeInterval, response: Double = 0.75,
                       snap: Bool = false) -> Double {
        guard desired.isFinite else { return previous ?? 0 }
        guard let previous, previous.isFinite, !snap else { return desired }
        let dt = min(0.3, max(0.01, seconds))
        let alpha = 1 - exp(-dt / max(0.05, response))
        return previous + (desired - previous) * alpha
    }

    /// Low-pass the virtual camera *position*, not the athlete's GPS trace.
    static func center(previous: CLLocationCoordinate2D?,
                       desired: CLLocationCoordinate2D,
                       seconds: TimeInterval, snap: Bool = false) -> CLLocationCoordinate2D {
        guard let previous, !snap else { return desired }
        let dt = min(0.3, max(0.01, seconds))
        let alpha = 1 - exp(-dt / 0.55)
        let a = MKProjectedPoint(previous)
        let b = MKProjectedPoint(desired)
        let x = a.x + (b.x - a.x) * alpha
        let y = a.y + (b.y - a.y) * alpha
        return MKProjectedPoint.coordinate(x: x, y: y)
    }
}

/// Compact Mercator projection keeps interpolation continuous near longitude wrap.
/// Used only in the camera filter. No GPS location is persisted or uploaded.
private struct MKProjectedPoint {
    let x: Double
    let y: Double

    init(_ location: CLLocationCoordinate2D) {
        x = (location.longitude + 180) / 360
        let lat = min(85, max(-85, location.latitude)) * .pi / 180
        y = (1 - log(tan(lat) + 1 / cos(lat)) / .pi) / 2
    }

    static func coordinate(x: Double, y: Double) -> CLLocationCoordinate2D {
        let normalized = (x.truncatingRemainder(dividingBy: 1) + 1)
            .truncatingRemainder(dividingBy: 1)
        let latitude = atan(sinh(.pi * (1 - 2 * y))) * 180 / .pi
        return CLLocationCoordinate2D(latitude: latitude,
                                      longitude: normalized * 360 - 180)
    }
}
