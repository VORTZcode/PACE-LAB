import SwiftUI
import Charts

private struct MonthBucket: Identifiable {
    var id: Int { month }
    let month: Int
    let distance: Double
}
private struct CardioPoint: Identifiable {
    let id: String
    let date: Date
    let bpm: Double
}

struct ProgressScreen: View {
    @EnvironmentObject var engine: HealthSyncEngine
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    private var years: [Int] {
        Array(Set(engine.runHistory.map { Calendar.current.component(.year, from: $0.startDate) }))
            .sorted(by: >)
    }
    private var yearRuns: [WorkoutPayload] { engine.runs(year: selectedYear) }
    private var monthSeries: [MonthBucket] {
        (1...12).map { month in
            MonthBucket(month: month,
                distance: yearRuns.filter { Calendar.current.component(.month, from: $0.startDate) == month }
                    .reduce(0) { $0 + $1.kilometers })
        }
    }
    private var cardio: [CardioPoint] {
        Array(yearRuns.filter { $0.hr_average_bpm != nil }.prefix(30).reversed())
            .compactMap { w in
                guard let bpm = w.hr_average_bpm else { return nil }
                return CardioPoint(id: w.source_uuid, date: w.startDate, bpm: bpm)
            }
    }
    var body: some View {
        NavigationStack {
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
                BodyMetricsSection()
                PaceSectionTitle(title: "Volume mensuel", subtitle: String(selectedYear))
                PaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Kilomètres de course à pied")
                            .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                        Chart(monthSeries) { item in
                            BarMark(x: .value("Mois", item.month), y: .value("Distance", item.distance))
                                .foregroundStyle(PaceColors.teal.gradient)
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
                        .chartYAxisLabel("km")
                        .chartYScale(domain: .automatic(includesZero: true))
                        .frame(height: 205)
                    }
                }
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
                PaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Analyse en construction", systemImage: "waveform.path.ecg")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(PaceColors.teal)
                        Text("Les prochains indicateurs croiseront allure, puissance, fréquence cardiaque et récupération pour comparer des séances réellement comparables.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
