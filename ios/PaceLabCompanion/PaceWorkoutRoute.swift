import SwiftUI
import HealthKit
import MapKit
import CoreLocation

// GPS stays in HealthKit / the iPhone process. It is never included in Coach prompts.
struct PaceRouteFix {
    let location: CLLocationCoordinate2D
    let timestamp: Date
    let elevation: CLLocationDistance
}

struct PaceRouteFrame {
    let coordinate: CLLocationCoordinate2D
    let heading: CLLocationDirection
    let elapsedSeconds: TimeInterval
    let distanceMeters: CLLocationDistance
    let elevation: CLLocationDistance
}

struct PaceRouteTrack {
    let fixes: [PaceRouteFix]
    let distances: [CLLocationDistance]
    let duration: TimeInterval
    var totalDistance: CLLocationDistance { distances.last ?? 0 }

    /// Physical footprint of the actual route (not kilometres accumulated).
    /// A looping 7 km course may cover a square of only 1–2 km: using total
    /// distance for the introduction made the map look like an orbit shot.
    var footprintMeters: CLLocationDistance {
        guard let first = fixes.first else { return 0 }
        var north = first.location.latitude, south = north
        var east = first.location.longitude, west = east
        for point in fixes {
            north = max(north, point.location.latitude)
            south = min(south, point.location.latitude)
            east = max(east, point.location.longitude)
            west = min(west, point.location.longitude)
        }
        return CLLocation(latitude: north, longitude: east)
            .distance(from: CLLocation(latitude: south, longitude: west))
    }

    init?(locations: [CLLocation]) {
        let ordered = locations
            .filter { CLLocationCoordinate2DIsValid($0.coordinate) &&
                $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 150 }
            .sorted { $0.timestamp < $1.timestamp }
        guard ordered.count >= 2 else { return nil }
        // Keep the full sequence in memory up to 2800 points, with both endpoints.
        let step = max(1, Int(ceil(Double(ordered.count - 1) / 2799)))
        var indices = Array(stride(from: 0, to: ordered.count, by: step))
        if indices.last != ordered.count - 1 { indices.append(ordered.count - 1) }
        fixes = indices.map {
            PaceRouteFix(location: ordered[$0].coordinate,
                         timestamp: ordered[$0].timestamp,
                         elevation: ordered[$0].altitude)
        }
        var cumulative: [Double] = [0]
        for index in fixes.indices.dropFirst() {
            let a = fixes[index - 1].location
            let b = fixes[index].location
            let measured = CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            cumulative.append(cumulative.last! + min(measured, 500))
        }
        distances = cumulative
        duration = max(1, fixes.last!.timestamp.timeIntervalSince(fixes.first!.timestamp))
    }

    /// Stable direction across a section of real track, not between adjacent
    /// noisy points. GPS itself is left untouched.
    func cameraCourse(at fraction: Double) -> CLLocationDirection? {
        let window = min(18.0, max(8.0, duration / 240))
        let left = frame(at: max(0, fraction - window / duration)).coordinate
        let right = frame(at: min(1, fraction + window / duration)).coordinate
        return PaceFlightMotion.bearing(from: left, to: right)
    }

    func frame(at fraction: Double) -> PaceRouteFrame {
        let p = min(1, max(0, fraction))
        let elapsed = duration * p
        let time = fixes[0].timestamp.addingTimeInterval(elapsed)
        var low = 0
        var high = fixes.count - 1
        while low < high {
            let mid = (low + high) / 2
            if fixes[mid].timestamp < time { low = mid + 1 } else { high = mid }
        }
        let upper = min(max(1, low), fixes.count - 1)
        let lower = upper - 1
        let a = fixes[lower], b = fixes[upper]
        let span = max(0.001, b.timestamp.timeIntervalSince(a.timestamp))
        let part = min(1, max(0, time.timeIntervalSince(a.timestamp) / span))
        let latitude = a.location.latitude + (b.location.latitude - a.location.latitude) * part
        let longitude = a.location.longitude + (b.location.longitude - a.location.longitude) * part
        let deltaLon = (b.location.longitude - a.location.longitude) * .pi / 180
        let latA = a.location.latitude * .pi / 180
        let latB = b.location.latitude * .pi / 180
        let y = sin(deltaLon) * cos(latB)
        let x = cos(latA) * sin(latB) - sin(latA) * cos(latB) * cos(deltaLon)
        let bearing = (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        return PaceRouteFrame(
            coordinate: .init(latitude: latitude, longitude: longitude),
            heading: bearing, elapsedSeconds: elapsed,
            distanceMeters: distances[lower] + (distances[upper] - distances[lower]) * part,
            elevation: a.elevation + (b.elevation - a.elevation) * part)
    }
}

@MainActor final class PaceWorkoutRouteReader: ObservableObject {
    enum State: Equatable { case idle, loading, unavailable, ready, error(String) }
    @Published private(set) var state: State = .idle
    @Published private(set) var track: PaceRouteTrack?
    private let store = HKHealthStore()
    private var loadedWorkoutID: String?

    func load(workoutID: String, retry: Bool = false) async {
        if !retry && loadedWorkoutID == workoutID { return }
        loadedWorkoutID = workoutID
        track = nil
        state = .loading
        guard let uuid = UUID(uuidString: workoutID), HKHealthStore.isHealthDataAvailable()
        else { state = .unavailable; return }
        do {
            // Never prompt for GPS access when opening an activity. The iOS 27
            // exception in a previous route-only authorization request crashed
            // the entire activity screen. First try a normal read: HealthKit
            // returns an empty result when access has not been granted.
            // Explicit user action (retry) is required before asking for GPS.
            if retry {
                // Routes are child samples of HKWorkout: request parent and
                // child read types together, never any write permission.
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    let reads: Set<HKObjectType> = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
                    store.requestAuthorization(toShare: [], read: reads) { _, error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume() }
                    }
                }
            }
            let workout: HKWorkout? = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: .workoutType(),
                                          predicate: HKQuery.predicateForObject(with: uuid),
                                          limit: 1, sortDescriptors: nil) { _, samples, _ in
                    continuation.resume(returning: (samples as? [HKWorkout])?.first)
                }
                store.execute(query)
            }
            guard let workout else { state = .unavailable; return }
            let samples: [HKWorkoutRoute] = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: HKSeriesType.workoutRoute(),
                                          predicate: HKQuery.predicateForObjects(from: workout),
                                          limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                    continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
                }
                store.execute(query)
            }
            guard !samples.isEmpty else { state = .unavailable; return }
            var locations: [CLLocation] = []
            for sample in samples {
                let batch: [CLLocation] = try await withCheckedThrowingContinuation { continuation in
                    var entries: [CLLocation] = []
                    var completed = false
                    let query = HKWorkoutRouteQuery(route: sample) { _, update, done, error in
                        guard !completed else { return }
                        if let error {
                            completed = true
                            continuation.resume(throwing: error)
                            return
                        }
                        entries.append(contentsOf: update ?? [])
                        if done {
                            completed = true
                            continuation.resume(returning: entries)
                        }
                    }
                    store.execute(query)
                }
                locations.append(contentsOf: batch)
            }
            track = PaceRouteTrack(locations: locations)
            state = track == nil ? .unavailable : .ready
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

final class PaceRouteMarker: MKPointAnnotation {}

struct PaceRouteMap: UIViewRepresentable {
    let track: PaceRouteTrack
    var progress: Double? = nil
    var followCamera = false
    var recenterToken = 0
    var introProgress: Double? = nil
    var outroProgress: Double? = nil
    var cameraMode: PaceFlyoverCameraMode = .follow

    final class Coordinator: NSObject, MKMapViewDelegate {
        var marker = PaceRouteMarker()
        var route: MKPolyline?
        var completedRoute: MKPolyline?
        var trackID: Date?
        var previousProgress = -1.0
        var lastDrawnProgress = -1.0
        var recenterToken = -1
        var isPlayback = false
        var cameraHeading: Double?
        var cameraCenter: CLLocationCoordinate2D?
        var lastCameraTick: TimeInterval?
        var cameraDistance: Double?
        var cameraPitch: Double?
        var lastIntroProgress: Double?
        var lastOutroProgress: Double?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            if let played = completedRoute, let line = overlay as? MKPolyline, played === line {
                renderer.strokeColor = UIColor(red: 0.16, green: 0.93, blue: 0.79, alpha: 0.97)
                renderer.lineWidth = isPlayback ? 3.4 : 4.1
            } else {
                renderer.strokeColor = UIColor(red: 0.45, green: 0.91, blue: 0.80,
                    alpha: isPlayback ? 0.38 : 0.90)
                renderer.lineWidth = isPlayback ? 1.6 : 3.3
            }
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is PaceRouteMarker else { return nil }
            let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "pace-route-position")
            view.frame = CGRect(x: 0, y: 0, width: 13, height: 13)
            view.layer.cornerRadius = 6.5
            view.layer.backgroundColor = UIColor.systemTeal.cgColor
            view.layer.borderColor = UIColor.white.cgColor
            view.layer.borderWidth = 2
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOpacity = 0.35
            view.layer.shadowRadius = 7
            view.layer.shadowOffset = .zero
            return view
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        // Photographic map imagery, including real 3D terrain and buildings
        // wherever Apple Maps has compatible coverage.
        map.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
        map.isPitchEnabled = true
        map.isRotateEnabled = true
        map.showsCompass = !followCamera
        map.isScrollEnabled = !followCamera
        map.isZoomEnabled = !followCamera
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.isPlayback = progress != nil
        map.isScrollEnabled = !followCamera
        map.isZoomEnabled = !followCamera
        if coordinator.trackID != track.fixes.first?.timestamp {
            coordinator.trackID = track.fixes.first?.timestamp
            let coordinates = track.fixes.map(\.location)
            if let old = coordinator.route { map.removeOverlay(old) }
            if let old = coordinator.completedRoute { map.removeOverlay(old) }
            coordinator.completedRoute = nil
            coordinator.lastDrawnProgress = -1
            coordinator.cameraHeading = nil
            coordinator.cameraCenter = nil
            coordinator.lastCameraTick = nil
            coordinator.cameraDistance = nil
            coordinator.cameraPitch = nil
            map.removeAnnotations(map.annotations)
            let line = MKPolyline(coordinates: coordinates, count: coordinates.count)
            map.addOverlay(line)
            coordinator.route = line
            coordinator.previousProgress = -1
            coordinator.marker.coordinate = coordinates[0]
            map.addAnnotation(coordinator.marker)
            map.setVisibleMapRect(line.boundingMapRect,
                                  edgePadding: UIEdgeInsets(top: 35, left: 32, bottom: 35, right: 32),
                                  animated: false)
        }
        let fraction = progress ?? 0
        let previousFraction = coordinator.previousProgress
        let shouldMove = previousFraction != fraction
        let shouldReset = coordinator.recenterToken != recenterToken
        let sceneMoved = coordinator.lastIntroProgress != introProgress ||
            coordinator.lastOutroProgress != outroProgress
        if shouldMove || shouldReset || sceneMoved {
            coordinator.lastIntroProgress = introProgress
            coordinator.lastOutroProgress = outroProgress
            coordinator.recenterToken = recenterToken
            coordinator.previousProgress = fraction
            let current = track.frame(at: fraction)
            coordinator.marker.coordinate = current.coordinate
            if progress != nil,
               abs(fraction - coordinator.lastDrawnProgress) >= 0.006 ||
               (fraction >= 1 && coordinator.lastDrawnProgress < 1) {
                if let previous = coordinator.completedRoute { map.removeOverlay(previous) }
                let elapsedDate = track.fixes[0].timestamp.addingTimeInterval(current.elapsedSeconds)
                var visited = track.fixes.prefix { $0.timestamp <= elapsedDate }.map(\.location)
                visited.append(current.coordinate)
                if visited.count >= 2 {
                    let played = MKPolyline(coordinates: visited, count: visited.count)
                    coordinator.completedRoute = played
                    map.addOverlay(played)
                }
                coordinator.lastDrawnProgress = fraction
            }
            if followCamera {
                if let scene = introProgress ?? outroProgress {
                    let approaching = introProgress != nil
                    let t = min(1, max(0, scene))
                    let easing = PaceFlightMotion.minimumJerk(t)
                    let startFrame = track.frame(at: approaching ? 0 : 1)
                    let rectangle = coordinator.route?.boundingMapRect ?? .world
                    let routeCenter = MKMapPoint(x: rectangle.midX, y: rectangle.midY).coordinate
                    let start = approaching ? routeCenter : startFrame.coordinate
                    let end = approaching ? startFrame.coordinate : routeCenter
                    let center = CLLocationCoordinate2D(
                        latitude: start.latitude + (end.latitude - start.latitude) * easing,
                        longitude: start.longitude + (end.longitude - start.longitude) * easing)
                    // Fit the route's spatial footprint, not kilometres run.
                    let wideDistance = max(1400.0, min(7600.0, track.footprintMeters * 2.6))
                    let closeDistance = max(500.0, min(940.0, track.totalDistance / 7))
                    let zoom = approaching
                        ? wideDistance * pow(closeDistance / wideDistance, easing)
                        : closeDistance * pow(wideDistance / closeDistance, easing)
                    let direction = track.cameraCourse(at: approaching ? 0 : 1) ?? startFrame.heading
                    let heading = PaceFlightMotion.wrap(direction + (approaching ? 26 * (1 - easing) : 24 * easing))
                    let pitch = approaching ? 28 + 27 * easing : 55 - 30 * easing
                    let camera = MKMapCamera(lookingAtCenter: center,
                                             fromDistance: zoom, pitch: pitch, heading: heading)
                    map.setCamera(camera, animated: false)
                    coordinator.cameraCenter = approaching ? end : nil
                    coordinator.cameraHeading = heading
                    coordinator.lastCameraTick = nil
                    coordinator.cameraDistance = zoom
                    coordinator.cameraPitch = pitch
                    return
                }
                let uptime = ProcessInfo.processInfo.systemUptime
                let dt = coordinator.lastCameraTick.map {
                    min(0.25, max(0.012, uptime - $0))
                } ?? 0.1
                coordinator.lastCameraTick = uptime
                // A deliberate scrub jumps directly to the chosen location.
                // Normal playback gently follows the track without abrupt yaw.
                let seek = shouldReset || previousFraction < 0 ||
                    abs(fraction - previousFraction) > 0.024
                let lookAhead = min(6, track.duration * 0.003)
                let targetFraction = min(1, fraction + lookAhead / track.duration)
                // Sample a short, symmetric temporal window of the recorded
                // track: the virtual camera no longer reacts to each noisy fix.
                let window = min(4 / track.duration, 0.008)
                let targetCenter = PaceFlightMotion.cinematicTarget([
                    track.frame(at: max(0, targetFraction - window)).coordinate,
                    track.frame(at: targetFraction).coordinate,
                    track.frame(at: min(1, targetFraction + window)).coordinate
                ]) ?? track.frame(at: targetFraction).coordinate
                // Anticipate the next section, avoiding tiny per-fix GPS wiggles.
                let aheadFraction = min(1, fraction + min(25 / track.duration, 0.035))
                let desiredHeading = track.cameraCourse(at: aheadFraction) ??
                    coordinator.cameraHeading ?? current.heading
                coordinator.cameraHeading = PaceFlightMotion.heading(
                    previous: coordinator.cameraHeading,
                    desired: desiredHeading, seconds: dt, snap: seek)
                coordinator.cameraCenter = PaceFlightMotion.center(
                    previous: coordinator.cameraCenter, desired: targetCenter,
                    seconds: dt, snap: seek)
                // A close but restrained aerial perspective. Pull back gently
                // before a bend so the runner remains readable in context.
                let defaultDistance = max(500.0, min(940.0, track.totalDistance / 7))
                let nearHeading = track.cameraCourse(at: fraction) ?? desiredHeading
                let turn = abs(PaceFlightMotion.shortestTurn(from: nearHeading, to: desiredHeading))
                let bend = min(1, turn / 75)
                let followDistance = defaultDistance * (1 + 0.30 * bend)
                let adaptivePitch = max(20, cameraMode.pitch - CGFloat(bend * 7))
                let smoothedDistance = PaceFlightMotion.scalar(
                    previous: coordinator.cameraDistance,
                    desired: followDistance * cameraMode.distanceMultiplier,
                    seconds: dt, response: 1.05, snap: seek)
                let smoothedPitch = PaceFlightMotion.scalar(
                    previous: coordinator.cameraPitch,
                    desired: Double(adaptivePitch),
                    seconds: dt, response: 1.15, snap: seek)
                coordinator.cameraDistance = smoothedDistance
                coordinator.cameraPitch = smoothedPitch
                let camera = MKMapCamera(
                    lookingAtCenter: coordinator.cameraCenter ?? current.coordinate,
                    fromDistance: smoothedDistance,
                    pitch: smoothedPitch, heading: coordinator.cameraHeading ?? desiredHeading)
                map.setCamera(camera, animated: false)
            } else if shouldReset, let route = coordinator.route {
                map.setVisibleMapRect(route.boundingMapRect,
                                      edgePadding: UIEdgeInsets(top: 35, left: 32, bottom: 35, right: 32),
                                      animated: true)
            }
        }
    }
}

struct PaceRouteSection: View {
    let workout: WorkoutPayload
    @StateObject private var reader = PaceWorkoutRouteReader()
    @State private var showReplay = false
    @State private var showFullMap = false

    private var readableDistance: String {
        guard let track = reader.track else { return "" }
        return String(format: "%.2f", track.totalDistance / 1000)
            .replacingOccurrences(of: ".", with: ",")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            switch reader.state {
            case .idle, .loading:
                RoundedRectangle(cornerRadius: 26)
                    .fill(PaceColors.surface)
                    .frame(height: 190)
                    .overlay {
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Chargement du tracé Apple Santé")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
            case .unavailable:
                PaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Parcours GPS indisponible", systemImage: "map")
                            .font(.subheadline.weight(.semibold))
                        Text("Aucun itinéraire n’est accessible pour cette séance. L’accès Apple Santé est peut-être à autoriser.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Autoriser les itinéraires GPS") {
                            Task { await reader.load(workoutID: workout.source_uuid, retry: true) }
                        }
                        .font(.footnote.weight(.medium))
                    }
                }
            case .error(let message):
                PaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Impossible de charger le parcours", systemImage: "exclamationmark.triangle")
                            .font(.subheadline.weight(.semibold))
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                        Button("Réessayer") {
                            Task { await reader.load(workoutID: workout.source_uuid, retry: true) }
                        }
                    }
                }
            case .ready:
                if let route = reader.track {
                    PaceRouteMap(track: route)
                        .frame(height: 360)
                        .overlay(alignment: .topLeading) {
                            Label("ITINÉRAIRE · SATELLITE", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                                .font(.caption2.weight(.bold))
                                .tracking(0.65)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(.regularMaterial, in: Capsule())
                                .padding(15)
                                .allowsHitTesting(false)
                        }
                        .overlay(alignment: .topTrailing) {
                            Button { showFullMap = true } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(width: 43, height: 43)
                                    .background(.regularMaterial, in: Circle())
                            }
                            .tint(.primary)
                            .accessibilityLabel("Agrandir la carte du parcours")
                            .padding(15)
                        }
                        .overlay(alignment: .bottom) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Ton itinéraire")
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(readableDistance) km GPS")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Button { showReplay = true } label: {
                                    Label("Survol 3D", systemImage: "play.fill")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(PaceColors.teal)
                                .accessibilityLabel("Lancer le survol 3D de cette activité")
                            }
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 19))
                            .padding(13)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal, -PaceDesign.screenInset)
                        .accessibilityLabel("Vue satellite du parcours de la séance")
                        .fullScreenCover(isPresented: $showReplay) {
                            PaceRouteFlyoverScreen(track: route, workout: workout)
                        }
                        .sheet(isPresented: $showFullMap) {
                            NavigationStack {
                                PaceRouteFullMapScreen(track: route, workout: workout)
                            }
                        }
                }
            }
        }
        .task(id: workout.source_uuid) {
            await reader.load(workoutID: workout.source_uuid)
        }
    }
}

/// Strava-like map focus without sacrificing native pan, zoom, or replay.
struct PaceRouteFullMapScreen: View {
    let track: PaceRouteTrack
    let workout: WorkoutPayload
    @Environment(\.dismiss) private var dismiss
    @State private var showReplay = false

    var body: some View {
        PaceRouteMap(track: track)
            .ignoresSafeArea(edges: .bottom)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ton parcours").font(.subheadline.weight(.semibold))
                        Text("\(PaceFormat.distance(workout.kilometers, places: 2)) km · \(PaceFormat.duration(workout.duration_seconds))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { showReplay = true } label: {
                        Label("Survol 3D", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PaceColors.teal)
                }
                .padding(17)
                .background(.regularMaterial)
            }
            .navigationTitle("Parcours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showReplay) {
                PaceRouteFlyoverScreen(track: track, workout: workout)
            }
    }
}

/// Always-visible speed choices: avoids the iOS context menu that was
/// visible but intermittently unselectable over the updating MapKit view.
enum PaceFlyoverCameraMode: String, CaseIterable {
    case follow = "Suivi"
    case panorama = "Panorama"
    case overhead = "Verticale"

    var distanceMultiplier: Double {
        switch self { case .follow: 1; case .panorama: 2.0; case .overhead: 1.45 }
    }
    var pitch: CGFloat {
        switch self { case .follow: 55; case .panorama: 64; case .overhead: 15 }
    }
}

/// One calm, tactile speed control; no four-button strip over the landscape.
struct PaceFlyoverSpeedControl: View {
    @Binding var selection: Double
    private let values: [Double] = [0.5, 1, 2, 4]

    var body: some View {
        Button {
            let current = values.firstIndex(of: selection) ?? 1
            selection = values[(current + 1) % values.count]
        } label: {
            Text(String(format: "%g×", selection))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(minWidth: 54, minHeight: 44)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Vitesse du survol : \(String(format: "%g", selection)) fois. Toucher pour modifier")
    }
}

struct PaceRouteFlyoverScreen: View {
    let track: PaceRouteTrack
    let workout: WorkoutPayload
    @Environment(\.dismiss) private var dismiss
    @State private var fraction = 0.0
    @State private var isPlaying = true
    @State private var playbackSpeed = 1.0
    @State private var lastTick: Date?
    @State private var recenterToken = 0
    @State private var stage: PaceFlightScene = .intro
    @State private var sceneProgress = 0.0
    @State private var cameraMode: PaceFlyoverCameraMode = .follow
    @State private var freeCamera = false
    @State private var showTelemetry = true
    @State private var cinemaMode = false

    private enum PaceFlightScene { case intro, chase, outro, finished }

    private var current: PaceRouteFrame { track.frame(at: fraction) }
    private var playbackSeconds: Double { 75 / playbackSpeed }
    private var progressDistance: String {
        PaceFormat.distance(current.distanceMeters / 1000, places: 2)
    }
    /// Moving 45-second window of the recorded GPS route, not an inferred
    /// physiological threshold and not a claim of instantaneous speed.
    private var routePace: String {
        guard current.elapsedSeconds >= 45 else { return "—" }
        let before = track.frame(at: max(0, fraction - 45 / track.duration))
        let deltaKm = (current.distanceMeters - before.distanceMeters) / 1000
        guard deltaKm >= 0.025 else { return "—" }
        let minutesPerKm = 0.75 / deltaKm
        guard minutesPerKm >= 2 && minutesPerKm <= 30 else { return "—" }
        return PaceFormat.pace(minutesPerKm)
    }
    private var gpsAltitude: String {
        guard current.elevation.isFinite, (-400...8000).contains(current.elevation) else { return "—" }
        return "\(Int(current.elevation.rounded())) m"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PaceRouteMap(track: track, progress: fraction,
                         followCamera: !freeCamera, recenterToken: recenterToken,
                         introProgress: stage == .intro ? sceneProgress : nil,
                         outroProgress: stage == .outro ? sceneProgress : (stage == .finished ? 1 : nil),
                         cameraMode: cameraMode)
                .ignoresSafeArea()

            // Optical depth without hiding the photographic surroundings.
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.47), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 175)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.38)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 185)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("PACE LAB  /  FLYOVER", systemImage: "location.north.circle.fill")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.45)
                            .foregroundStyle(.white.opacity(0.88))
                        Text(workout.cadenceLabel)
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 45, height: 45)
                            .background(.black.opacity(0.49), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fermer le survol")
                }
                .padding(.horizontal, 19)
                .padding(.top, 14)
                HStack(spacing: 10) {
                    Menu {
                        Section("Caméra") {
                            ForEach(PaceFlyoverCameraMode.allCases, id: \.self) { mode in
                                Button(mode.rawValue, systemImage: mode == cameraMode ? "checkmark" : "video") {
                                    cameraMode = mode
                                    freeCamera = false
                                    recenterToken += 1
                                }
                            }
                        }
                        Section("Affichage") {
                            Button(showTelemetry ? "Masquer les statistiques" : "Afficher les statistiques",
                                   systemImage: "chart.bar") { showTelemetry.toggle() }
                            Button(freeCamera ? "Reprendre le suivi" : "Explorer la carte",
                                   systemImage: "hand.draw") {
                                freeCamera.toggle()
                                if !freeCamera { recenterToken += 1 }
                            }
                        }
                    } label: {
                        Label(cameraMode.rawValue, systemImage: "camera.aperture")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .padding(.horizontal, 13)
                            .frame(height: 42)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .accessibilityLabel("Options de caméra et d'affichage")
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { cinemaMode.toggle() }
                    } label: {
                        Label(cinemaMode ? "Commandes" : "Cinéma",
                              systemImage: cinemaMode ? "rectangle.expand.vertical" : "viewfinder")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .accessibilityLabel(cinemaMode ? "Afficher les commandes" : "Mode cinéma sans commandes")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 19)
                .padding(.top, 12)
                Spacer()
                if stage == .intro || stage == .outro || stage == .finished {
                    Text(stage == .intro ? "REDÉCOUVRIR LE PARCOURS" : "LE PARCOURS EN ENTIER")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1.7)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .shadow(color: .black.opacity(0.8), radius: 8)
                }
                if !cinemaMode {
                VStack(alignment: .leading, spacing: 12) {
                    if showTelemetry {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(progressDistance)
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("km")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.74))
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("TEMPS ÉCOULÉ")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .tracking(1)
                                    .foregroundStyle(.white.opacity(0.65))
                                Text(PaceFormat.duration(current.elapsedSeconds))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                            }
                        }
                        .foregroundStyle(.white)
                        HStack(spacing: 8) {
                            Label(routePace == "—" ? "Allure —" : routePace + " /km",
                                  systemImage: "speedometer")
                            Spacer()
                            Label(gpsAltitude, systemImage: "mountain.2")
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.79))
                    }
                    Slider(value: $fraction, in: 0...1, onEditingChanged: { editing in
                        if editing {
                            isPlaying = false
                            stage = .chase
                            sceneProgress = 0
                        }
                    })
                    .tint(.white)
                    .accessibilityLabel("Position dans le parcours")
                    .accessibilityValue("\(Int((fraction * 100).rounded())) pour cent")
                    HStack(spacing: 11) {
                        Button {
                            if fraction >= 1 {
                                fraction = 0
                                stage = .intro
                                sceneProgress = 0
                                freeCamera = false
                            }
                            isPlaying.toggle()
                            lastTick = .now
                        } label: {
                            Label(isPlaying ? "Pause" : "Lire",
                                  systemImage: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .frame(minWidth: 87, minHeight: 41)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(.black)
                        Spacer(minLength: 0)
                        PaceFlyoverSpeedControl(selection: $playbackSpeed)

                    }
                }
                .padding(.horizontal, 17)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial.opacity(0.75),
                            in: RoundedRectangle(cornerRadius: 23, style: .continuous))
                .environment(\.colorScheme, .dark)
                .overlay {
                    RoundedRectangle(cornerRadius: 23)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.75)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                } else {
                    HStack(spacing: 12) {
                        Text(progressDistance + " km")
                            .font(.system(size: 21, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Spacer()
                        Button { isPlaying.toggle(); lastTick = .now } label: {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel(isPlaying ? "Mettre en pause" : "Reprendre la lecture")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { now in
            defer { lastTick = now }
            guard isPlaying else { return }
            let elapsed = min(0.25, max(0, now.timeIntervalSince(lastTick ?? now)))
            switch stage {
            case .intro:
                sceneProgress = min(1, sceneProgress + elapsed / 4.5)
                if sceneProgress >= 1 {
                    stage = .chase
                    sceneProgress = 0
                }
            case .chase:
                fraction = min(1, fraction + elapsed / playbackSeconds)
                if fraction >= 1 {
                    stage = .outro
                    sceneProgress = 0
                }
            case .outro:
                sceneProgress = min(1, sceneProgress + elapsed / 5)
                if sceneProgress >= 1 { stage = .finished; isPlaying = false }
            case .finished:
                isPlaying = false
            }
        }
    }
}
