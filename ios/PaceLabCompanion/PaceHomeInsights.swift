import SwiftUI
import Charts

enum PaceInsight: String, CaseIterable {
    case year, month, heart, week
    var title: String {
        switch self {
        case .year: return "Bilan annuel"
        case .month: return "Ce mois-ci"
        case .heart: return "Fréquence cardiaque"
        case .week: return "Les 7 derniers jours"
        }
    }
    var symbol: String {
        switch self {
        case .year: return "chart.bar.fill"
        case .month: return "calendar"
        case .heart: return "heart"
        case .week: return "calendar.badge.clock"
        }
    }
    var description: String {
        switch self {
        case .year: return "Votre volume de course depuis le début de l’année."
        case .month: return "Vos kilomètres de course de ce mois."
        case .heart: return "Le cardio mesuré sur votre dernière course et les sorties précédentes."
        case .week: return "Les courses enregistrées pendant les sept derniers jours."
        }
    }
}

private struct PaceVolumeBar: Identifiable {
    let date: Date
    let distance: Double
    var id: Date { date }
}

struct PaceInsightScreen: View {
    @EnvironmentObject private var engine: HealthSyncEngine
    let kind: PaceInsight
    @State private var showAll = false

    private var calendar: Calendar { .current }
    private var lastRun: WorkoutPayload? { engine.runHistory.first }
    private var selectedRuns: [WorkoutPayload] {
        let now = Date.now
        return engine.runHistory.filter { item in
            switch kind {
            case .year: return calendar.isDate(item.startDate, equalTo: now, toGranularity: .year)
            case .month: return calendar.isDate(item.startDate, equalTo: now, toGranularity: .month)
            case .week: return item.startDate >= calendar.date(byAdding: .day, value: -6,
                        to: calendar.startOfDay(for: now)) ?? .distantPast && item.startDate <= now
            case .heart: return item.hr_average_bpm != nil
            }
        }
    }
    private var kilometers: Double {
        selectedRuns.reduce(0) { $0 + $1.kilometers }
    }
    private var volumeBars: [PaceVolumeBar] {
        let now = Date.now
        let beginnings: [Date]
        switch kind {
        case .year:
            let year = calendar.component(.year, from: now)
            beginnings = (1...12).compactMap { calendar.date(from: DateComponents(year: year, month: $0, day: 1)) }
        case .month:
            let current = calendar.dateComponents([.year,.month], from: now)
            let length = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
            beginnings = (1...length).compactMap {
                calendar.date(from: DateComponents(year: current.year, month: current.month, day: $0))
            }
        case .week:
            let today = calendar.startOfDay(for: now)
            beginnings = (-6...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        case .heart: return []
        }
        return beginnings.map { start in
            let component: Calendar.Component = kind == .year ? .month : .day
            return PaceVolumeBar(date: start, distance: selectedRuns
                .filter { calendar.isDate($0.startDate, equalTo: start, toGranularity: component) }
                .reduce(0) { $0 + $1.kilometers })
        }
    }
    private var recent: [WorkoutPayload] {
        Array(selectedRuns.prefix(showAll ? 60 : 8))
    }
    var body: some View {
        PaceScreen(title: kind.title) {
            HStack(spacing: 10) {
                Image(systemName: kind.symbol)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(PaceColors.teal)
                    .frame(width: 45, height: 45)
                    .background(PaceColors.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                Text(kind.description)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if kind == .heart {
                VStack(alignment: .leading, spacing: 11) {
                    PaceSectionTitle(title: "Dernière course")
                    if let lastRun {
                        HStack(spacing: 10) {
                            PaceMetric(caption: "FC moyenne", value: PaceFormat.heart(lastRun.hr_average_bpm), suffix: "bpm", symbol: "heart")
                            PaceMetric(caption: "FC maximale", value: PaceFormat.heart(lastRun.hr_max_bpm), suffix: "bpm", symbol: "heart.fill")
                        }
                        NavigationLink {
                            WorkoutDetailScreen(workout: lastRun)
                        } label: {
                            Label("Voir le graphique de cette course", systemImage: "waveform.path.ecg")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(17)
                                .background(PaceColors.surface, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .tint(PaceColors.teal)
                        .buttonStyle(.plain)
                    } else {
                        ContentUnavailableView("Pas encore de course", systemImage: "heart")
                    }
                }
                Text("La fréquence cardiaque dépend aussi de l’intensité, du terrain et des conditions. Elle ne suffit pas seule à évaluer les progrès.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                PaceCard(padding: 22) {
                    VStack(alignment: .leading, spacing: 13) {
                        Text("DISTANCE PARCOURUE")
                            .font(.caption2.weight(.bold)).tracking(1.2)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text(PaceFormat.distance(kilometers))
                                .font(.system(size: 43, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            Text("km").font(.title3).foregroundStyle(.secondary)
                        }
                        Text("\(selectedRuns.count) courses enregistrées")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 13) {
                    PaceSectionTitle(title: kind == .year ? "Mois par mois" : "Jour par jour")
                    PaceCard {
                        Chart(volumeBars) { bar in
                            BarMark(x: .value("Date", bar.date), y: .value("Distance", bar.distance))
                                .foregroundStyle(PaceColors.teal.gradient)
                                .cornerRadius(3)
                        }
                        .chartYAxisLabel("km")
                        .frame(height: 200)
                        .accessibilityLabel("Volume de course pour la période sélectionnée")
                    }
                }
            }
            PaceSectionTitle(title: kind == .heart ? "Mesures récentes" : "Courses de cette période",
                             subtitle: "\(selectedRuns.count)")
            if selectedRuns.isEmpty {
                ContentUnavailableView("Aucune course disponible", systemImage: "figure.run",
                    description: Text("Les entraînements enregistrés dans Santé apparaîtront ici."))
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(recent) { workout in
                        NavigationLink {
                            WorkoutDetailScreen(workout: workout)
                        } label: {
                            ActivityRow(workout: workout)
                        }
                        .buttonStyle(.plain)
                        if workout.source_uuid != recent.last?.source_uuid {
                            Divider().padding(.leading, 55)
                        }
                    }
                }
                .padding(.horizontal, 15)
                .background(PaceColors.surface, in: RoundedRectangle(cornerRadius: 22))
                if selectedRuns.count > recent.count {
                    Button("Afficher plus de courses") { showAll = true }
                        .font(.subheadline.weight(.semibold))
                        .tint(PaceColors.teal)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
