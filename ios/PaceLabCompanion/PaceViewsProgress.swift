import SwiftUI
import Charts

private struct MonthBucket: Identifiable {
    var id: Int { month }
    let month: Int
    let distance: Double
    let durationHours: Double
    let count: Int
}
private struct CardioPoint: Identifiable {
    let id: String
    let date: Date
    let bpm: Double
}

struct ProgressScreen: View {
    @EnvironmentObject var engine: HealthSyncEngine
    @EnvironmentObject var athleteProfile: PaceAthleteProfileStore
    @EnvironmentObject var healthSignals: PaceHealthSignals
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    @State private var selectedMonth: Int?
    @State private var monthMetric = 0
    private var years: [Int] {
        Array(Set(engine.runHistory.map { Calendar.current.component(.year, from: $0.startDate) }))
            .sorted(by: >)
    }
    private var yearRuns: [WorkoutPayload] { engine.runs(year: selectedYear) }
    private var evidence: PaceProgressSnapshot { PaceProgressEvidence.snapshot(engine.runHistory) }
    private var monthSeries: [MonthBucket] {
        (1...12).map { month in
            let runs = yearRuns.filter {
                Calendar.current.component(.month, from: $0.startDate) == month
            }
            return MonthBucket(month: month,
                               distance: runs.reduce(0) { $0 + $1.kilometers },
                               durationHours: runs.reduce(0) {
                                   $0 + $1.duration_seconds / 3600
                               },
                               count: runs.count)
        }
    }
    private var selectedMonthRuns: [WorkoutPayload] {
        guard let selectedMonth, (1...12).contains(selectedMonth) else { return [] }
        return yearRuns.filter {
            Calendar.current.component(.month, from: $0.startDate) == selectedMonth
        }.sorted { $0.startDate > $1.startDate }
    }
    private func monthValue(_ month: MonthBucket) -> Double {
        switch monthMetric {
        case 1: return month.durationHours
        case 2: return Double(month.count)
        default: return month.distance
        }
    }
    private var metricUnit: String {
        switch monthMetric {
        case 1: return "h"
        case 2: return "courses"
        default: return "km"
        }
    }
    private var selectedMonthName: String {
        guard let selectedMonth, (1...12).contains(selectedMonth) else { return "" }
        return Calendar.current.monthSymbols[selectedMonth - 1].capitalized
    }
    private var cardio: [CardioPoint] {
        Array(yearRuns.filter { $0.hr_average_bpm != nil }.prefix(30).reversed())
            .compactMap { w in
                guard let bpm = w.hr_average_bpm else { return nil }
                return CardioPoint(id: w.source_uuid, date: w.startDate, bpm: bpm)
            }
    }
    var body: some View {
            PaceScreen(title: "Progression") {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("UNE ANNÉE DE COURSE")
                            .font(.caption2.weight(.bold)).tracking(1.25).foregroundStyle(PaceColors.teal)
                        Text("Distance et régularité")
                            .font(.title3.weight(.semibold))
                    }
                    Spacer()
                    Menu {
                        ForEach(years, id: \.self) { year in
                            Button(String(year)) { selectedYear = year }
                        }
                    } label: {
                        Label(String(selectedYear), systemImage: "chevron.down")
                            .font(.subheadline.weight(.medium))
                    }
                    .modifier(PaceGlassTreatment())
                }
                HStack(spacing: 10) {
                    PaceMetric(caption: "Distance totale", value: PaceFormat.distance(engine.totalDistance(year: selectedYear)), suffix: "km", symbol: "figure.run")
                    PaceMetric(caption: "Courses", value: "\(yearRuns.count)", suffix: "", symbol: "calendar")
                }
                PaceProgressEvidencePanel(snapshot: evidence,
                                          runningGoal: athleteProfile.profile?.runningGoal)
                PaceTrainingTimeline()
                BodyMetricsSection()
                PaceStrengthProgressSection()
                if healthSignals.accessRequested {
                    PaceCard {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 13) {
                                Text("Mesures récupérées depuis Apple Santé, sans diagnostic automatique.")
                                    .font(.caption).foregroundStyle(.secondary)
                                ForEach(PaceHealthSignalTypes.definitions, id: \.id) { signal in
                                    if let latest = healthSignals.latest(signal.id) {
                                        HStack(alignment: .top) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(signal.name).font(.subheadline.weight(.medium))
                                                Text(latest.date.formatted(date: .abbreviated, time: .omitted))
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Text("\(String(format:"%.1f",latest.value)) \(signal.unitLabel)")
                                                .font(.subheadline.weight(.semibold))
                                                .monospacedDigit()
                                        }
                                    }
                                }
                                Text("L'absence de ligne ne prouve pas un refus : la donnée peut ne pas exister. Ces mesures ne sont envoyées à ChatGPT qu'avec ton accord séparé.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.top, 9)
                        } label: {
                            Label("Mesures complémentaires Santé", systemImage: "heart.text.clipboard")
                                .font(.subheadline.weight(.semibold))
                        }
                        .tint(PaceColors.teal)
                    }
                }
                PaceSectionTitle(title: "Volume mensuel", subtitle: String(selectedYear))
                PaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Touchez un mois pour retrouver les activités qui composent son total.")
                            .font(.caption).foregroundStyle(.secondary)
                        Picker("Indicateur mensuel", selection: $monthMetric) {
                            Text("Distance").tag(0)
                            Text("Temps").tag(1)
                            Text("Courses").tag(2)
                        }
                        .pickerStyle(.segmented)
                        Chart(monthSeries) { item in
                            BarMark(x: .value("Mois", item.month),
                                    y: .value(metricUnit, monthValue(item)))
                                .foregroundStyle(PaceColors.teal)
                                .opacity(selectedMonth == nil || selectedMonth == item.month ? 1 : 0.28)
                                .cornerRadius(4)
                        }
                        .chartXAxis {
                            AxisMarks(values: [1,3,5,7,9,11]) { value in
                                AxisValueLabel {
                                    if let month = value.as(Int.self) {
                                        Text(["","Jan","Fév","Mar","Avr","Mai","Jun","Jul","Aoû","Sep","Oct","Nov","Déc"][month])
                                    }
                                }
                            }
                        }
                        .chartYAxisLabel(metricUnit)
                        .chartYScale(domain: .automatic(includesZero: true))
                        .chartXSelection(value: $selectedMonth)
                        .frame(height: 205)
                        .accessibilityLabel("Histogramme mensuel des \(metricUnit)")
                        if let month = monthSeries.first(where: { $0.month == selectedMonth }) {
                            Divider()
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(selectedMonthName) \(selectedYear)")
                                    .font(.headline)
                                Spacer()
                                Text("\(month.count) courses · \(String(format: "%.1f", month.distance)) km · \(String(format: "%.1f", month.durationHours)) h")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if selectedMonthRuns.isEmpty {
                                Text("Aucune activité pour ce mois.")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                ForEach(selectedMonthRuns) { workout in
                                    NavigationLink {
                                        WorkoutDetailScreen(workout: workout)
                                    } label: {
                                        ActivityRow(workout: workout)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityHint("Ouvre la fiche de cette séance")
                                }
                            }
                        } else {
                            Text("Sélectionnez une barre pour ouvrir les séances de ce mois.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: selectedYear) { _, _ in selectedMonth = nil }
                PaceSectionTitle(title: "Fréquence cardiaque")
                PaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FC moyenne · \(cardio.count) dernières courses mesurées en \(selectedYear)")
                            .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                        if cardio.count > 1 {
                            Chart(cardio) { item in
                                LineMark(x: .value("Date", item.date), y: .value("FC", item.bpm))
                                    .foregroundStyle(PaceColors.teal)
                                    .lineStyle(StrokeStyle(lineWidth: 2.3))
                                PointMark(x: .value("Date", item.date), y: .value("FC", item.bpm))
                                    .symbolSize(18)
                                    .foregroundStyle(PaceColors.teal)
                            }
                            .chartYAxisLabel("bpm")
                            .frame(height: 195)
                        } else {
                            ContentUnavailableView("Données insuffisantes", systemImage: "heart")
                        }
                        Text("La FC moyenne seule ne mesure pas un progrès : l’allure, le dénivelé et l’effort doivent aussi être comparés.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("Les mesures sont descriptives : une fréquence cardiaque plus basse n’indique un progrès que dans des conditions d’effort comparables.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 3)
            }
    }
}


/// Local, reproducible measurements: GPT descriptions are never presented as measurements.
private struct PaceProgressEvidencePanel: View {
    let snapshot: PaceProgressSnapshot
    let runningGoal: String?

    private func km(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaceSectionTitle(title: "Évolution mesurée", subtitle: "Deux périodes de 28 jours")
            PaceCard {
                VStack(alignment: .leading, spacing: 15) {
                    if let runningGoal, !runningGoal.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("OBJECTIF PERSONNEL")
                                .font(.caption2.weight(.bold))
                                .tracking(0.8)
                                .foregroundStyle(PaceColors.teal)
                            Text(runningGoal)
                                .font(.subheadline.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Divider()
                    }
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("28 derniers jours").font(.caption).foregroundStyle(.secondary)
                            Text("\(km(snapshot.current28.distanceKm)) km")
                                .font(.title2.weight(.semibold)).monospacedDigit()
                            Text("\(snapshot.current28.runCount) courses · \(snapshot.current28.activeWeeks)/4 semaines actives")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 2)
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("28 jours précédents").font(.caption).foregroundStyle(.secondary)
                            Text("\(km(snapshot.previous28.distanceKm)) km")
                                .font(.headline.weight(.semibold)).monospacedDigit()
                            Text("\(snapshot.previous28.runCount) courses")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !snapshot.hasTwoPeriods {
                        Label("Pas encore assez de séances dans les deux périodes pour comparer le volume.",
                              systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Il s'agit du volume réalisé, pas d'une mesure directe de forme ou de progression physiologique.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            PaceCard {
                VStack(alignment: .leading, spacing: 11) {
                    Label("Repère de performance", systemImage: "arrow.left.arrow.right")
                        .font(.headline)
                        .foregroundStyle(PaceColors.teal)
                    if let comparison = snapshot.comparison {
                        let change = comparison.paceDifferenceSecondsPerKm
                        let magnitude = Int(abs(change).rounded())
                        let label = magnitude < 3 ? "Allure proche" :
                            change < 0 ? "Allure plus rapide" : "Allure plus lente"
                        Text("\(label) de \(magnitude) s/km")
                            .font(.title3.weight(.semibold))
                        Text("Comparaison avec une course de \(km(comparison.priorKm)) km du \(comparison.priorDate.formatted(date: .abbreviated, time: .omitted)).")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(comparison.evidenceLabel)
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Pas encore de course suffisamment comparable.")
                            .font(.subheadline.weight(.medium))
                        Text("Une comparaison sera proposée après une autre sortie de distance proche, espacée d'au moins sept jours. Aucune progression n'est supposée.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if !snapshot.milestones.isEmpty {
                PaceCard {
                    VStack(alignment: .leading, spacing: 13) {
                        Label("Repères par distance", systemImage: "flag.checkered")
                            .font(.headline)
                            .foregroundStyle(PaceColors.teal)
                        ForEach(snapshot.milestones) { record in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Autour de \(record.targetKm) km")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Sortie complète de \(String(format: "%.2f", record.distanceKm)) km · \(record.date.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Text(PaceFormat.pace(record.paceSecondsPerKm / 60) + " /km")
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                            }
                            if record.targetKm != snapshot.milestones.last?.targetKm { Divider() }
                        }
                        Text("Ces allures correspondent à des activités complètes de distance proche (±3 %), pas à des chronos exacts de segments ou des records officiels.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}


/// Strava-inspired exploration, without social scoring or fabricated physiological trends.
/// The chart and its drill-down use the identical validated HealthKit sample set.
private struct PaceTrainingTimeline: View {
    @EnvironmentObject private var engine: HealthSyncEngine
    @State private var weekCount = 12
    @State private var metric = 0
    @State private var selectedWeekDate: Date?

    private var weeks: [PaceTrainingTrendWeek] {
        PaceProgressEvidence.trainingWeeks(engine.runHistory, weeks: weekCount)
    }
    private var highlighted: PaceTrainingTrendWeek? {
        guard let date = selectedWeekDate,
              let weekStart = Calendar.current.dateInterval(of: .weekOfYear,
                                                              for: date)?.start else { return nil }
        return weeks.first { $0.start == weekStart }
    }
    private var runsForSelection: [WorkoutPayload] {
        guard let week = highlighted,
              let end = Calendar.current.date(byAdding: .weekOfYear, value: 1,
                                               to: week.start) else { return [] }
        return PaceProgressEvidence.validatedRuns(engine.runHistory,
                                                   from: week.start, to: end)
    }
    private var unit: String {
        switch metric {
        case 1: return "h"
        case 2: return "séances"
        default: return "km"
        }
    }
    private func value(_ week: PaceTrainingTrendWeek) -> Double {
        switch metric {
        case 1: return week.durationHours
        case 2: return Double(week.runCount)
        default: return week.distanceKm
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaceSectionTitle(title: "Rythme d’entraînement", subtitle: "Vos semaines réelles")
            PaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Évolution hebdomadaire")
                            .font(.headline)
                        Spacer()
                        Menu {
                            Button("12 semaines") { weekCount = 12; selectedWeekDate = nil }
                            Button("26 semaines") { weekCount = 26; selectedWeekDate = nil }
                            Button("52 semaines") { weekCount = 52; selectedWeekDate = nil }
                        } label: {
                            Label("\(weekCount) sem.", systemImage: "chevron.down")
                                .font(.subheadline.weight(.medium))
                        }
                        .tint(PaceColors.teal)
                    }
                    Picker("Indicateur hebdomadaire", selection: $metric) {
                        Text("Distance").tag(0)
                        Text("Temps").tag(1)
                        Text("Courses").tag(2)
                    }
                    .pickerStyle(.segmented)
                    Chart(weeks) { week in
                        BarMark(x: .value("Semaine", week.start, unit: .weekOfYear),
                                y: .value(unit, value(week)))
                            .foregroundStyle(PaceColors.teal)
                            .opacity(highlighted == nil || highlighted?.id == week.id ? 1 : 0.28)
                            .cornerRadius(3)
                    }
                    .chartYAxisLabel(unit)
                    .chartYScale(domain: .automatic(includesZero: true))
                    .chartXSelection(value: $selectedWeekDate)
                    .frame(height: 205)
                    .accessibilityLabel("Volume de course par semaine, en \(unit)")
                    Menu {
                        ForEach(weeks.reversed()) { week in
                            Button("Semaine du \(week.start.formatted(date: .abbreviated, time: .omitted))") {
                                selectedWeekDate = week.start
                            }
                        }
                    } label: {
                        Label("Choisir une semaine à consulter",
                              systemImage: "calendar.badge.clock")
                            .font(.caption.weight(.medium))
                    }
                    .tint(PaceColors.teal)
                    if let week = highlighted {
                        Divider()
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Semaine du \(week.start.formatted(date: .abbreviated, time: .omitted))")
                                .font(.headline)
                            Text("\(week.runCount) courses · \(String(format: "%.1f", week.distanceKm)) km · \(String(format: "%.1f", week.durationHours)) h")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        if runsForSelection.isEmpty {
                            Text("Aucune sortie enregistrée sur cette semaine.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            ForEach(runsForSelection) { workout in
                                NavigationLink {
                                    WorkoutDetailScreen(workout: workout)
                                } label: {
                                    ActivityRow(workout: workout)
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Ouvre le détail de la séance")
                            }
                        }
                    } else {
                        Text("Touchez une barre ou choisissez une semaine pour retrouver ses sorties.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Volumes enregistrés depuis Apple Santé. Les semaines sans séance restent visibles ; le volume seul ne mesure pas la forme.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}
