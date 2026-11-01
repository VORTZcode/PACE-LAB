import SwiftUI
import Charts

private struct RunChartPoint: Identifiable, Sendable {
    let id: Int
    let minute: Double
    let value: Double
}

private enum RunChartMetric: String, CaseIterable, Identifiable, Sendable {
    case heart = "Cardio"
    case speed = "Allure"
    case power = "Puissance"
    case stride = "Foulée"
    case contact = "Contact"
    case vertical = "Vertical"
    var id: String { rawValue }
    var unit: String {
        switch self {
        case .heart: "bpm"
        case .speed: "min/km"
        case .power: "W"
        case .stride: "m"
        case .contact: "ms"
        case .vertical: "cm"
        }
    }
    var detail: String {
        switch self {
        case .heart: "Fréquence cardiaque pendant l’effort"
        case .speed: "Allure issue de la vitesse mesurée par Apple Watch"
        case .power: "Puissance de course enregistrée"
        case .stride: "Longueur d’un pas de course"
        case .contact: "Temps de contact avec le sol"
        case .vertical: "Oscillation verticale du bassin"
        }
    }
    var symbol: String {
        switch self {
        case .heart: "heart"
        case .speed: "speedometer"
        case .power: "bolt"
        case .stride: "figure.run"
        case .contact: "shoeprints.fill"
        case .vertical: "arrow.up.and.down"
        }
    }
}

private enum RunChartCalculator {
    nonisolated static func build(_ workout: WorkoutPayload, metric: RunChartMetric) -> [RunChartPoint] {
        let selected: [PaceSensorPoint]
        switch metric {
        case .heart:
            selected = workout.heart_rate_series.map {
                PaceSensorPoint(timestamp: $0.timestamp, value: $0.bpm)
            }
        case .speed: selected = workout.speed_series ?? []
        case .power: selected = workout.power_series ?? []
        case .stride: selected = workout.stride_series ?? []
        case .contact: selected = workout.ground_contact_series ?? []
        case .vertical: selected = workout.vertical_series ?? []
        }
        let clock = ISO8601DateFormatter()
        guard let start = clock.date(from: workout.started_at),
              let finish = clock.date(from: workout.ended_at) else { return [] }
        let step = max(1, Int(ceil(Double(selected.count) / 550)))
        return selected.enumerated().compactMap { i, point in
            guard i % step == 0,
                  let date = clock.date(from: point.timestamp),
                  date >= start, date <= finish,
                  point.value.isFinite else { return nil }
            let value: Double
            switch metric {
            case .speed:
                guard point.value > 0.7 else { return nil }
                value = 1000 / (point.value * 60)
                guard (2...25).contains(value) else { return nil }
            case .heart:
                guard (25...245).contains(point.value) else { return nil }
                value = point.value
            default:
                guard point.value > 0 else { return nil }
                value = point.value
            }
            return RunChartPoint(id: i, minute: date.timeIntervalSince(start)/60, value: value)
        }
    }
}

struct RunDynamicsSection: View {
    @EnvironmentObject private var engine: HealthSyncEngine
    let original: WorkoutPayload
    @State private var metric: RunChartMetric = .heart
    @State private var selectedMinute: Double?
    @State private var chartData: [RunChartPoint] = []
    @State private var isChartLoading = false

    private var w: WorkoutPayload {
        engine.workout(id: original.source_uuid) ?? original
    }
    private var sensorAvailable: Bool {
        (w.speed_series?.isEmpty == false) || (w.power_series?.isEmpty == false) ||
        (w.stride_series?.isEmpty == false)
    }
    private var chartKey: String {
        let value = w
        let length: Int
        switch metric {
        case .heart: length = value.heart_rate_series.count
        case .speed: length = value.speed_series?.count ?? 0
        case .power: length = value.power_series?.count ?? 0
        case .stride: length = value.stride_series?.count ?? 0
        case .contact: length = value.ground_contact_series?.count ?? 0
        case .vertical: length = value.vertical_series?.count ?? 0
        }
        return "\(metric.rawValue)|\(value.source_uuid)|\(length)"
    }
    private var selectedPoint: RunChartPoint? {
        guard let selectedMinute else { return nil }
        return chartData.min { abs($0.minute - selectedMinute) < abs($1.minute - selectedMinute) }
    }
    private var displayMean: String {
        switch metric {
        case .heart: PaceFormat.heart(w.hr_average_bpm)
        case .speed:
            if let speed = w.mean_speed_mps, speed > 0 { PaceFormat.pace(1000 / speed / 60) } else { "—" }
        case .power: w.mean_power_w.map { String(Int($0.rounded())) } ?? "—"
        case .stride: w.mean_stride_m.map { PaceFormat.distance($0, places: 2) } ?? "—"
        case .contact: w.mean_ground_contact_ms.map { String(Int($0.rounded())) } ?? "—"
        case .vertical: w.mean_vertical_oscillation_cm.map { PaceFormat.distance($0, places: 1) } ?? "—"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            PaceSectionTitle(title: "Analyse de l’effort")
            if w.isRun {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(RunChartMetric.allCases) { item in
                            Button {
                                metric = item
                                selectedMinute = nil
                            } label: {
                                Label(item.rawValue, systemImage: item.symbol)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 11).padding(.vertical, 10)
                                    .foregroundStyle(metric == item ? Color.white : Color.primary)
                                    .background(metric == item ? PaceColors.teal : PaceColors.surface, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            PaceCard {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(metric.detail).font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Moyenne des échantillons : \(displayMean) \(metric.unit)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let selectedPoint {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(String(format: metric == .heart || metric == .power || metric == .contact ? "%.0f %@" : "%.1f %@", selectedPoint.value, metric.unit))
                                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                                Text(String(format: "%.1f min", selectedPoint.minute))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if isChartLoading && chartData.isEmpty {
                        ProgressView("Préparation de la courbe")
                            .frame(maxWidth: .infinity).frame(height: 180)
                    } else if chartData.count >= 2 {
                        Chart {
                            ForEach(chartData) { point in
                                LineMark(x: .value("Minute", point.minute),
                                         y: .value(metric.unit, point.value))
                                    .foregroundStyle(PaceColors.teal)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                    .interpolationMethod(.linear)
                            }
                            if let point = selectedPoint {
                                RuleMark(x: .value("Minute choisie", point.minute))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4,4]))
                                    .foregroundStyle(.secondary)
                                PointMark(x: .value("Minute choisie", point.minute), y: .value(metric.unit, point.value))
                                    .symbolSize(45)
                                    .foregroundStyle(PaceColors.teal)
                            }
                        }
                        .chartXSelection(value: $selectedMinute)
                        .chartXAxisLabel("Minutes d’effort")
                        .frame(height: 220)
                        .accessibilityLabel("Courbe \(metric.rawValue), \(chartData.count) mesures disponibles")
                    } else {
                        ContentUnavailableView(
                            "Aucune courbe disponible",
                            systemImage: metric.symbol,
                            description: Text(metric == .heart ?
                                "Aucune série cardiaque enregistrée pour cette séance." :
                                "Aucun échantillon Apple Santé pour cette métrique.")
                        )
                        .frame(height: 155)
                    }
                    Text("Touchez la courbe pour examiner une mesure. Les points manquants ne sont pas interpolés.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            if w.isRun {
                PaceSectionTitle(title: "Dynamique de course")
                if !engine.advancedEnabled {
                    PaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Activer la télémétrie Apple Watch", systemImage: "applewatch")
                                .font(.subheadline.weight(.semibold))
                            Text("Autorisez la lecture de la puissance, de la vitesse et de la dynamique de course dans Santé. Les données absentes resteront indiquées comme indisponibles.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button {
                                engine.requestAdvancedPermission()
                            } label: {
                                Label("Autoriser les mesures", systemImage: "heart.text.square")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(PaceColors.teal)
                        }
                    }
                } else {
                    if !sensorAvailable && w.advanced_loaded != true {
                        Label("Recherche des données de course…", systemImage: "clock.arrow.circlepath")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                        PaceMetric(caption: "Puissance moyenne", value: w.mean_power_w.map { String(Int($0.rounded())) } ?? "—", suffix: "W", symbol: "bolt.fill")
                        PaceMetric(caption: "Longueur de pas", value: w.mean_stride_m.map { PaceFormat.distance($0, places: 2) } ?? "—", suffix: "m", symbol: "figure.run")
                        PaceMetric(caption: "Contact au sol", value: w.mean_ground_contact_ms.map { String(Int($0.rounded())) } ?? "—", suffix: "ms", symbol: "shoeprints.fill")
                        PaceMetric(caption: "Oscillation verticale", value: w.mean_vertical_oscillation_cm.map { PaceFormat.distance($0, places: 1) } ?? "—", suffix: "cm", symbol: "arrow.up.and.down")
                    }
                    HStack {
                        Text("Cadence dérivée vitesse / longueur de pas :")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(w.cadence_estimated_spm.map { "\(Int($0.rounded())) pas/min (est.)" } ?? "indisponible")
                            .font(.caption.weight(.semibold)).monospacedDigit()
                    }
                    Text("Les moyennes correspondent aux échantillons disponibles. La cadence dérivée est indicative, sans équivalence avec une mesure native de cadence.")
                        .font(.caption2).foregroundStyle(.secondary)
                    if w.advanced_loaded == true && !sensorAvailable {
                        Text("Cette séance ne contient pas de télémétrie supplémentaire accessible à PACE LAB.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task(id: chartKey) {
            let input = w
            let selected = metric
            chartData = []
            isChartLoading = true
            let points = await Task.detached(priority: .userInitiated) {
                RunChartCalculator.build(input, metric: selected)
            }.value
            guard !Task.isCancelled else { return }
            chartData = points
            isChartLoading = false
        }
    }
}

/// Descriptive comparison, never claims that a difference proves fitness improvement.
struct SimilarRunComparison: View {
    @EnvironmentObject private var engine: HealthSyncEngine
    @EnvironmentObject private var journal: PaceSessionJournal
    let workout: WorkoutPayload

    private var previous: WorkoutPayload? {
        guard workout.isRun, workout.kilometers > 0.8 else { return nil }
        return engine.runHistory
            .filter {
                $0.startDate < workout.startDate &&
                $0.kilometers > 0.8 &&
                abs($0.kilometers - workout.kilometers) / workout.kilometers <= 0.15
            }
            .first
    }
    var body: some View {
        if let previous {
            VStack(alignment: .leading, spacing: 12) {
                PaceSectionTitle(title: "Comparer cette sortie")
                PaceCard {
                    VStack(alignment: .leading, spacing: 13) {
                        Text("Course précédente de distance similaire (±15 %)")
                            .font(.subheadline.weight(.semibold))
                        Text(PaceFormat.fullDate(previous.startDate).capitalized)
                            .font(.caption).foregroundStyle(.secondary)
                        Divider()
                        comparison("Distance", current: "\(PaceFormat.distance(workout.kilometers, places: 2)) km",
                                   past: "\(PaceFormat.distance(previous.kilometers, places: 2)) km")
                        comparison("Allure moyenne", current: "\(PaceFormat.pace(workout.paceMinutes)) /km",
                                   past: "\(PaceFormat.pace(previous.paceMinutes)) /km")
                        comparison("FC moyenne", current: "\(PaceFormat.heart(workout.hr_average_bpm)) bpm",
                                   past: "\(PaceFormat.heart(previous.hr_average_bpm)) bpm")
                        if let effort = journal.note(for: workout.source_uuid).effort,
                           let other = journal.note(for: previous.source_uuid).effort {
                            comparison("Difficulté ressentie", current: "\(effort)/10", past: "\(other)/10")
                        }
                        Divider()
                        Text("Comparaison descriptive : ni la pente, ni la météo, ni le profil d’effort n’ont été neutralisés. Une meilleure allure seule ne prouve pas une amélioration physiologique.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    private func comparison(_ title: String, current: String, past: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(current).font(.subheadline.weight(.semibold)).monospacedDigit()
                Text("Avant : " + past).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
