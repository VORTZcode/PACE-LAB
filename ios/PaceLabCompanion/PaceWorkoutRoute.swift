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
            // HealthKit may silently return no route if read permission was denied.
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                store.requestAuthorization(toShare: [], read: [HKSeriesType.workoutRoute()]) { _, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
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

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            if let played = completedRoute, let line = overlay as? MKPolyline, played === line {
                renderer.strokeColor = UIColor(red: 0.06, green: 0.61, blue: 0.52, alpha: 1)
                renderer.lineWidth = 7
            } else {
                renderer.strokeColor = UIColor(red: 0.10, green: 0.51, blue: 0.46, alpha: 0.33)
                renderer.lineWidth = 4.5
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
        let configuration = MKStandardMapConfiguration()
        configuration.elevationStyle = .realistic
        configuration.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = configuration
        map.isPitchEnabled = true
        map.isRotateEnabled = true
        map.showsCompass = true
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.trackID != track.fixes.first?.timestamp {
            coordinator.trackID = track.fixes.first?.timestamp
            let coordinates = track.fixes.map(\.location)
            if let old = coordinator.route { map.removeOverlay(old) }
            if let old = coordinator.completedRoute { map.removeOverlay(old) }
            coordinator.completedRoute = nil
            coordinator.lastDrawnProgress = -1
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
        let shouldMove = coordinator.previousProgress != fraction
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
                let camera = MKMapCamera(lookingAtCenter: current.coordinate,
                                         fromDistance: max(800, min(1900, track.totalDistance / 3)),
                                         pitch: 54, heading: current.heading)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaceSectionTitle(title: "Parcours", subtitle: "Apple Santé")
            switch reader.state {
            case .idle, .loading:
                PaceCard { HStack { ProgressView(); Text("Chargement du parcours GPS…").font(.subheadline) } }
            case .unavailable:
                PaceCard {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("Aucun tracé GPS accessible", systemImage: "map")
                            .font(.subheadline.weight(.semibold))
                        Text("Certaines séances n'enregistrent pas de parcours. Tu peux vérifier l'accès aux itinéraires dans Santé.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Actualiser l'accès au parcours") {
                            Task { await reader.load(workoutID: workout.source_uuid, retry: true) }
                        }
                        .font(.footnote.weight(.medium))
                    }
                }
            case .error(let message):
                PaceCard {
                    Text("Parcours indisponible : \(message)")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Réessayer") {
                        Task { await reader.load(workoutID: workout.source_uuid, retry: true) }
                    }
                }
            case .ready:
                if let route = reader.track {
                    VStack(alignment: .leading, spacing: 0) {
                        PaceRouteMap(track: route)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 19))
                            .accessibilityLabel("Carte de l'itinéraire de la séance")
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Itinéraire enregistré")
                                    .font(.subheadline.weight(.semibold))
                                Text("Parcours GPS · \(String(format: "%.2f", route.totalDistance / 1000).replacingOccurrences(of: ".", with: ",")) km")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { showReplay = true } label: {
                                Label("Survol 3D", systemImage: "play.fill")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(PaceColors.teal)
                        }
                        .padding(.top, 13)
                    }
                    .padding(13)
                    .modifier(PaceGlassCardSurface(cornerRadius: 24))
                    .sheet(isPresented: $showReplay) {
                        NavigationStack {
                            PaceRouteFlyoverScreen(track: route, workout: workout)
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

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                PaceRouteMap(track: track, progress: fraction,
                             followCamera: true, recenterToken: recenterToken)
                    .ignoresSafeArea(edges: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.cadenceLabel).font(.subheadline.weight(.semibold))
                    Text("\(String(format: "%.2f", current.distanceMeters / 1000)) km")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("Parcours parcouru · \(PaceFormat.duration(current.elapsedSeconds))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding(16)
            }
            VStack(spacing: 14) {
                Slider(value: $fraction, in: 0...1, onEditingChanged: { editing in
                    if editing { isPlaying = false }
                })
                .tint(PaceColors.teal)
                .accessibilityLabel("Position dans le parcours")
                HStack {
                    Button {
                        if fraction >= 1 { fraction = 0 }
                        isPlaying.toggle()
                        lastTick = .now
                    } label: {
                        Label(isPlaying ? "Pause" : "Lire",
                              systemImage: isPlaying ? "pause.fill" : "play.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PaceColors.teal)
                    Spacer()
                    Menu {
                        ForEach([0.5, 1.0, 2.0, 4.0], id: \.self) { speed in
                            Button("\(String(format: "%g", speed))×") { playbackSpeed = speed }
                        }
                    } label: {
                        Label("\(String(format: "%g", playbackSpeed))×",
                              systemImage: "speedometer")
                    }
                    .tint(PaceColors.teal)
                    Button {
                        recenterToken += 1
                    } label: {
                        Label("Recentrer", systemImage: "location.north.line.fill")
                    }
                    .tint(PaceColors.teal)
                }
                Text("Survol animé dans Plans · durée de lecture réglable · GPS non transmis au Coach IA")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(.regularMaterial)
        }
        .background(PaceColors.base)
        .navigationTitle("Survol du parcours")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fermer") { dismiss() }
            }
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { now in
            defer { lastTick = now }
            guard isPlaying else { return }
            let elapsed = min(0.25, max(0, now.timeIntervalSince(lastTick ?? now)))
            fraction = min(1, fraction + elapsed / playbackSeconds)
            if fraction >= 1 { isPlaying = false }
        }
    }
}
