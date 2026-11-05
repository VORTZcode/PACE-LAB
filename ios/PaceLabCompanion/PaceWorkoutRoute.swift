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

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            if let played = completedRoute, let line = overlay as? MKPolyline, played === line {
                renderer.strokeColor = UIColor(red: 0.06, green: 0.61, blue: 0.52, alpha: 1)
                renderer.lineWidth = 7
            } else {
                renderer.strokeColor = UIColor(red: 0.06, green: 0.59, blue: 0.52,
                    alpha: isPlayback ? 0.32 : 0.94)
                renderer.lineWidth = isPlayback ? 4 : 5.5
            }
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is PaceRouteMarker else { return nil }
            let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "pace-route-position")
            view.frame = CGRect(x: 0, y: 0, width: 18, height: 18)
            view.layer.cornerRadius = 9
            view.layer.backgroundColor = UIColor.systemTeal.cgColor
            view.layer.borderColor = UIColor.white.cgColor
            view.layer.borderWidth = 3
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOpacity = 0.25
            view.layer.shadowRadius = 4
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
        if shouldMove || shouldReset {
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
                let targetCenter = track.frame(
                    at: min(1, fraction + lookAhead / track.duration)).coordinate
                let desiredHeading = track.cameraCourse(at: fraction) ??
                    coordinator.cameraHeading ?? current.heading
                coordinator.cameraHeading = PaceFlightMotion.heading(
                    previous: coordinator.cameraHeading,
                    desired: desiredHeading, seconds: dt, snap: seek)
                coordinator.cameraCenter = PaceFlightMotion.center(
                    previous: coordinator.cameraCenter, desired: targetCenter,
                    seconds: dt, snap: seek)
                let camera = MKMapCamera(
                    lookingAtCenter: coordinator.cameraCenter ?? current.coordinate,
                    fromDistance: max(870, min(1700, track.totalDistance / 3)),
                    pitch: 52, heading: coordinator.cameraHeading ?? desiredHeading)
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
struct PaceFlyoverSpeedControl: View {
    @Binding var selection: Double
    private let values: [Double] = [0.5, 1, 2, 4]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(values, id: \.self) { value in
                Button {
                    selection = value
                } label: {
                    Text(String(format: "%g×", value))
                        .font(.system(size: 13, weight: selection == value ? .bold : .medium,
                                      design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(selection == value ? .black : .white.opacity(0.78))
                        .frame(minWidth: 35, minHeight: 43)
                        .background {
                            if selection == value {
                                Capsule().fill(Color.white)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Vitesse \(String(format: "%g", value)) fois")
                .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.black.opacity(0.44), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Vitesse du survol")
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

    private var current: PaceRouteFrame { track.frame(at: fraction) }
    private var playbackSeconds: Double { 75 / playbackSpeed }
    private var progressDistance: String {
        PaceFormat.distance(current.distanceMeters / 1000, places: 2)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PaceRouteMap(track: track, progress: fraction,
                         followCamera: true, recenterToken: recenterToken)
                .ignoresSafeArea()

            // Optical depth without hiding the photographic surroundings.
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.61), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 220)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.72)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 240)
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

                Spacer()

                VStack(spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(progressDistance)
                                .font(.system(size: 38, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            Text("km")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("SUR LE PARCOURS")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(.white.opacity(0.66))
                            Text(PaceFormat.duration(current.elapsedSeconds))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                    }
                    .foregroundStyle(.white)

                    Slider(value: $fraction, in: 0...1, onEditingChanged: { editing in
                        if editing { isPlaying = false }
                    })
                    .tint(.white)
                    .accessibilityLabel("Position dans le parcours")
                    .accessibilityValue("\(Int((fraction * 100).rounded())) pour cent")

                    HStack(spacing: 12) {
                        Button {
                            if fraction >= 1 { fraction = 0 }
                            isPlaying.toggle()
                            lastTick = .now
                        } label: {
                            Label(isPlaying ? "Pause" : "Lire",
                                  systemImage: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .frame(minWidth: 91, minHeight: 43)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(.black)

                        Spacer(minLength: 0)

                        PaceFlyoverSpeedControl(selection: $playbackSpeed)

                        Spacer(minLength: 0)
                        Button { recenterToken += 1 } label: {
                            Image(systemName: "location.north.line.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 43, height: 43)
                                .background(.black.opacity(0.44), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Recentrer la caméra")
                    }
                    Text("Imagerie Apple Plans · détails 3D selon couverture")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .padding(.horizontal, 17)
                .padding(.top, 18)
                .padding(.bottom, 13)
                .background(.black.opacity(0.68),
                            in: RoundedRectangle(cornerRadius: 27, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 27)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 0.7)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { now in
            defer { lastTick = now }
            guard isPlaying else { return }
            let elapsed = min(0.25, max(0, now.timeIntervalSince(lastTick ?? now)))
            fraction = min(1, fraction + elapsed / playbackSeconds)
            if fraction >= 1 { isPlaying = false }
        }
    }
}
