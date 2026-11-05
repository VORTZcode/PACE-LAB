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
    @EnvironmentObject var athleteProfile: PaceAthleteProfileStore
    @State private var selectedYear = Calendar.current.component(.year, from: .now)
    private var years: [Int] {
        Array(Set(engine.runHistory.map { Calendar.current.component(.year, from: $0.startDate) }))
            .sorted(by: >)
    }
    private var yearRuns: [WorkoutPayload] { engine.runs(year: selectedYear) }
    private var evidence: PaceProgressSnapshot { PaceProgressEvidence.snapshot(engine.runHistory) }
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
                            Text("\\(km(snapshot.current28.distanceKm)) km")
                                .font(.title2.weight(.semibold)).monospacedDigit()
                            Text("\\(snapshot.current28.runCount) courses · \\(snapshot.current28.activeWeeks)/4 semaines actives")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 2)
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("28 jours précédents").font(.caption).foregroundStyle(.secondary)
                            Text("\\(km(snapshot.previous28.distanceKm)) km")
                                .font(.headline.weight(.semibold)).monospacedDigit()
                            Text("\\(snapshot.previous28.runCount) courses")
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
                        Text("\\(label) de \\(magnitude) s/km")
                            .font(.title3.weight(.semibold))
                        Text("Comparaison avec une course de \\(km(comparison.priorKm)) km du \\(comparison.priorDate.formatted(date: .abbreviated, time: .omitted)).")
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
        }
    }
}
