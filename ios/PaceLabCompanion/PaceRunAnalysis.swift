import SwiftUI
import Charts

private struct RunChartPoint: Identifiable, Sendable {
    let id: Int
    let minute: Double
    let value: Double
    let segment: Int
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
    var explanation: String {
        switch self {
        case .heart: "Battements du cœur par minute pendant l’effort. À interpréter avec votre allure, la température et votre fatigue."
        case .speed: "Le temps nécessaire pour parcourir un kilomètre. Un chiffre plus faible signifie une allure plus rapide."
        case .power: "Effort mécanique de course, exprimé en watts. À comparer surtout entre séances similaires."
        case .stride: "Distance parcourue à chaque pas. Plus long n’est pas forcément meilleur."
        case .contact: "Temps passé au sol à chaque pas, en millisecondes. Dépend notamment de la vitesse."
        case .vertical: "Amplitude du mouvement vertical lors de la course. Une valeur isolée ne détermine pas la qualité de la foulée."
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
        guard let start = PaceHeartTimeline.decodeDate(workout.started_at),
              let finish = PaceHeartTimeline.decodeDate(workout.ended_at) else { return [] }
        let sorted: [(source:Int,minute:Double,value:Double)] = selected.enumerated().compactMap { index, point in
            guard let date = PaceHeartTimeline.decodeDate(point.timestamp),
                  date >= start, date <= finish, point.value.isFinite else { return nil }
            let value: Double
            switch metric {
            case .speed:
                guard point.value > 0.7 else { return nil }
                value = 1000 / (point.value * 60)
                guard (2...25).contains(value) else { return nil }
            case .heart:
                guard (25...245).contains(point.value) else { return nil }
                value = point.value
            case .power:
                guard (1...1800).contains(point.value) else { return nil }
                value = point.value
            case .stride:
                guard (0.2...3.5).contains(point.value) else { return nil }
                value = point.value
            case .contact:
                guard (70...1000).contains(point.value) else { return nil }
                value = point.value
            case .vertical:
                guard (1...40).contains(point.value) else { return nil }
                value = point.value
            }
            return (source:index,minute:date.timeIntervalSince(start)/60,value:value)
        }.sorted { $0.minute < $1.minute }
        guard !sorted.isEmpty else { return [] }

        var segment = 0
        var full: [RunChartPoint] = []
        for (index,item) in sorted.enumerated() {
            // A break in the underlying measurements must remain a break after reduction.
            if index > 0, item.minute - sorted[index-1].minute > 2 {
                segment += 1
            }
            full.append(.init(id:item.source,minute:item.minute,value:item.value,segment:segment))
        }
        guard full.count > 320 else { return full }

        // Retain both extrema of each time-ordered bucket rather than every Nth raw
        // point. This preserves short-lived HR/power peaks and lows on long workouts.
        let window = max(2,Int(ceil(Double(full.count)/160)))
        var chosen = Set([0,full.count-1])
        for lower in stride(from:0,to:full.count,by:window) {
            let upper = min(full.count,lower+window)
            let slice = lower..<upper
            if let low = slice.min(by:{ full[$0].value < full[$1].value }),
               let high = slice.max(by:{ full[$0].value < full[$1].value }) {
                chosen.insert(low)
                chosen.insert(high)
            }
        }
        return chosen.sorted().map { full[$0] }
    }
}

struct RunDynamicsSection: View {
    @EnvironmentObject private var engine: HealthSyncEngine
    let original: WorkoutPayload

    @State private var metric: RunChartMetric = .heart
    @State private var selectedMinute: Double?
    // All series are prepared once. Switching metrics never clears the chart or triggers a spinner.
    @State private var prepared: [RunChartMetric: [RunChartPoint]] = [:]
    @State private var preparedKey: String?
    @State private var showAdvanced = false
    @State private var showExplanation = false

    private var w: WorkoutPayload { engine.workout(id: original.source_uuid) ?? original }
    private var sensorAvailable: Bool {
        (w.speed_series?.isEmpty == false) || (w.power_series?.isEmpty == false) ||
        (w.stride_series?.isEmpty == false)
    }
    private var preparationKey: String {
        let item = w
        return "\(item.source_uuid)|\(item.heart_rate_series.count)|\(item.speed_series?.count ?? 0)|\(item.power_series?.count ?? 0)|\(item.stride_series?.count ?? 0)|\(item.ground_contact_series?.count ?? 0)|\(item.vertical_series?.count ?? 0)"
    }
    private var points: [RunChartPoint] { prepared[metric] ?? [] }
    private var heartBaseline: Double {
        max(25, floor(((points.map(\.value).min() ?? 70) - 12) / 10) * 10)
    }
    private var selectedPoint: RunChartPoint? {
        guard let selectedMinute else { return nil }
        return points.min { abs($0.minute - selectedMinute) < abs($1.minute - selectedMinute) }
    }
    private var displayMean: String {
        switch metric {
        case .heart: return PaceFormat.heart(w.hr_average_bpm)
        case .speed:
            if let speed = w.mean_speed_mps, speed > 0 { return PaceFormat.pace(1000 / speed / 60) }
            return "—"
        case .power: return w.mean_power_w.map { String(Int($0.rounded())) } ?? "—"
        case .stride: return w.mean_stride_m.map { PaceFormat.distance($0, places: 2) } ?? "—"
        case .contact: return w.mean_ground_contact_ms.map { String(Int($0.rounded())) } ?? "—"
        case .vertical: return w.mean_vertical_oscillation_cm.map { PaceFormat.distance($0, places: 1) } ?? "—"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaceSectionTitle(title: showAdvanced ? "Analyse de l’effort" : "Fréquence cardiaque")
            if w.isRun && showAdvanced {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(RunChartMetric.allCases) { item in
                            Button {
                                guard metric != item else { return }
                                selectedMinute = nil
                                // Animate the selector, but not hundreds of Swift Charts marks.
                                withAnimation(.easeOut(duration: 0.16)) { metric = item }
                            } label: {
                                Label(item.rawValue, systemImage: item.symbol)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 11)
                                    .foregroundStyle(metric == item ? .white : .primary)
                                    .background(metric == item ? PaceColors.teal : PaceColors.surface, in: Capsule())
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(metric == item ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 3)
                }
                .contentMargins(.horizontal, 1)
            }
            PaceCard(padding: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(metric.detail)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                                .frame(height: 39, alignment: .topLeading)
                            Text(metric == .heart
                                 ? "Moyenne : \(displayMean) bpm"
                                 : "Moyenne : \(displayMean) \(metric.unit)")
                                .font(.caption).foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Spacer(minLength: 4)
                        Button { showExplanation = true } label: {
                            Image(systemName: "info.circle")
                                .font(.body.weight(.medium))
                                .foregroundStyle(PaceColors.teal)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Comprendre \(metric.rawValue)")
                    }
                    ZStack {
                        if preparedKey == preparationKey {
                            if points.count >= 2 {
                                Chart {
                                    if metric == .heart {
                                        ForEach(points) { point in
                                            AreaMark(x: .value("Minute", point.minute),
                                                     yStart: .value("Base", heartBaseline),
                                                     yEnd: .value("Battements/min", point.value),
                                                     series: .value("Segment de mesure", point.segment))
                                                .foregroundStyle(.linearGradient(
                                                    colors: [Color.red.opacity(0.16), Color.red.opacity(0.015)],
                                                    startPoint: .top, endPoint: .bottom))
                                                .interpolationMethod(.linear)
                                        }
                                    }
                                    ForEach(points) { point in
                                        LineMark(x: .value("Minute", point.minute),
                                                 y: .value(metric.unit, point.value),
                                                 series: .value("Segment de mesure", point.segment))
                                            .foregroundStyle(metric == .heart ? .red : PaceColors.teal)
                                            .lineStyle(StrokeStyle(lineWidth: metric == .heart ? 2.6 : 2, lineCap: .round))
                                            .interpolationMethod(.linear)
                                    }
                                    if let picked = selectedPoint {
                                        RuleMark(x: .value("Minute choisie", picked.minute))
                                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                            .foregroundStyle(.secondary)
                                        PointMark(x: .value("Minute choisie", picked.minute),
                                                  y: .value(metric.unit, picked.value))
                                            .symbolSize(48)
                                            .foregroundStyle(PaceColors.teal)
                                    }
                                }
                                .chartXSelection(value: $selectedMinute)
                                .chartXAxisLabel("Minutes écoulées")
                                .chartYAxisLabel(metric.unit)
                                .transaction { transaction in transaction.animation = nil }
                                .accessibilityLabel("\(metric.rawValue) — \(points.count) mesures enregistrées")
                            } else {
                                ContentUnavailableView("Aucune donnée", systemImage: metric.symbol,
                                    description: Text("L’Apple Watch n’a pas enregistré cette mesure pour cette séance."))
                            }
                        } else {
                            ProgressView("Préparation des graphiques")
                                .controlSize(.small)
                        }
                    }
                    .frame(height: 238)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    HStack(alignment: .firstTextBaseline) {
                        Text("Touchez la courbe pour voir une valeur")
                            .font(.caption2).foregroundStyle(.secondary)
                        Spacer(minLength: 3)
                        if let selectedPoint {
                            Text(metric == .speed
                                 ? "\(PaceFormat.pace(selectedPoint.value)) /km"
                                 : "\(selectedPoint.value.formatted(.number.precision(.fractionLength(1)))) \(metric.unit)")
                                .font(.caption.weight(.semibold)).monospacedDigit()
                        }
                    }
                    .frame(height: 21, alignment: .top)
                    if metric == .speed {
                        Text("Allure : une valeur plus faible correspond à une vitesse plus élevée.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if Set(points.map(\.segment)).count > 1 {
                        Text("Courbe interrompue lorsque l’Apple Watch ne dispose plus de mesures.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            if w.isRun {
                Button {
                    withAnimation(.easeOut(duration: 0.20)) {
                        showAdvanced.toggle()
                        if !showAdvanced { metric = .heart }
                        selectedMinute = nil
                    }
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text(showAdvanced ? "Masquer les mesures avancées" : "Découvrir les mesures avancées")
                        Spacer()
                        Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PaceColors.teal)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Afficher ou masquer les indicateurs Apple Watch détaillés")
            }
            if w.isRun && showAdvanced {
                PaceSectionTitle(title: "Dynamique de course")
                if !engine.advancedEnabled {
                    PaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Mesures Apple Watch supplémentaires", systemImage: "applewatch")
                                .font(.subheadline.weight(.semibold))
                            Text("Autorisez la puissance, la vitesse et la dynamique de course dans Apple Santé. Les mesures indisponibles ne seront pas inventées.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button { engine.requestAdvancedPermission() } label: {
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
                        Text("Cadence estimée")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(w.cadence_estimated_spm.map { "\(Int($0.rounded())) pas/min (est.)" } ?? "Indisponible")
                            .font(.caption.weight(.semibold)).monospacedDigit()
                    }
                    Text("La cadence est seulement une estimation calculée à partir des mesures disponibles.")
                        .font(.caption2).foregroundStyle(.secondary)
                    if w.advanced_loaded == true && !sensorAvailable {
                        Text("Cette séance ne contient pas de mesures de course supplémentaires accessibles.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .alert(metric.rawValue, isPresented: $showExplanation) {
            Button("Compris", role: .cancel) {}
        } message: {
            Text(metric.explanation)
        }
        .task(id: preparationKey) {
            let input = w
            let expectedKey = preparationKey
            let result = await Task.detached(priority: .userInitiated) {
                var output: [RunChartMetric: [RunChartPoint]] = [:]
                for item in RunChartMetric.allCases {
                    if Task.isCancelled { return output }
                    output[item] = RunChartCalculator.build(input, metric: item)
                }
                return output
            }.value
            guard !Task.isCancelled else { return }
            prepared = result
            preparedKey = expectedKey
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
