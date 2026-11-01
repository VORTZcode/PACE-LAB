import SwiftUI
import Charts

struct PaceCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder let content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(PaceColors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
struct PaceSectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 2)
    }
}
struct PaceMetric: View {
    let caption: String
    let value: String
    let suffix: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(PaceColors.teal)
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.system(size: 29, weight: .semibold, design: .rounded)).monospacedDigit()
                    + Text(" " + suffix).font(.subheadline.weight(.regular)).foregroundStyle(.secondary)
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(PaceColors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
struct PacePill: View {
    let label: String
    let symbol: String
    var color: Color = PaceColors.teal
    var body: some View {
        Label(label, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(color.opacity(0.09), in: Capsule())
    }
}
struct PaceGlassButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { Label(title, systemImage: symbol).font(.subheadline.weight(.semibold)) }
            .modifier(PaceGlassTreatment())
    }
}
struct PaceGlassTreatment: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(.horizontal, 18).padding(.vertical, 12)
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(.thinMaterial, in: Capsule())
        }
    }
}
struct PaceScreen<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 32)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .background(PaceColors.base)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct TodayScreen: View {
    @EnvironmentObject var engine: HealthSyncEngine
    @EnvironmentObject var library: PaceLibrary
    @State private var showSettings = false

    private var last: WorkoutPayload? { engine.runHistory.first }
    private var year: Int { Calendar.current.component(.year, from: .now) }

    var body: some View {
        NavigationStack {
            PaceScreen(title: "Aujourd’hui") {
                HStack {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR"))))
                        .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Spacer()
                    Label("Apple Santé", systemImage: "heart.text.square")
                        .font(.caption.weight(.medium)).foregroundStyle(PaceColors.teal)
                }
                if let day = library.nextDay {
                    VStack(alignment: .leading, spacing: 17) {
                        HStack {
                            Text("PROCHAINE SÉANCE").font(.caption2.weight(.bold)).tracking(1.35)
                                .foregroundStyle(.secondary)
                            Spacer()
                            PacePill(label: day.type, symbol: day.type == "Course" ? "figure.run" : day.type == "Musculation" ? "dumbbell" : "figure.cooldown")
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            Text(day.title).font(.system(size: 27, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                            Text("\(day.day) · \(Int(day.minutes)) min").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(day.objective).font(.subheadline)
                        NavigationLink {
                            DayDetailScreen(day: day)
                        } label: {
                            HStack {
                                Text("Voir ma séance").fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.subheadline)
                        }
                        .tint(PaceColors.teal)
                        .padding(.top, 2)
                    }
                    .padding(20)
                    .background(PaceColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    PaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Cycle terminé", systemImage: "checkmark.circle")
                                .font(.headline).foregroundStyle(PaceColors.teal)
                            Text("Le programme de cette semaine est terminé. Le prochain cycle sera établi à partir de vos données.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    PaceSectionTitle(title: "En un regard")
                    HStack(spacing: 10) {
                        PaceMetric(caption: "Distance \(year)", value: PaceFormat.distance(engine.totalDistance(year: year)), suffix: "km", symbol: "figure.run")
                        PaceMetric(caption: "Sorties \(year)", value: "\(engine.runs(year: year).count)", suffix: "", symbol: "calendar")
                    }
                    HStack(spacing: 10) {
                        PaceMetric(caption: "Dernière sortie", value: last.map { PaceFormat.distance($0.kilometers, places: 2) } ?? "—", suffix: "km", symbol: "figure.run.circle")
                        PaceMetric(caption: "FC moyenne", value: last.map { PaceFormat.heart($0.hr_average_bpm) } ?? "—", suffix: "bpm", symbol: "heart")
                    }
                }
                if let last {
                    VStack(alignment: .leading, spacing: 12) {
                        PaceSectionTitle(title: "Dernière activité")
                        NavigationLink {
                            WorkoutDetailScreen(workout: last)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "figure.run")
                                    .font(.title2).foregroundStyle(PaceColors.teal)
                                    .frame(width: 46, height: 46)
                                    .background(PaceColors.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Course à pied").font(.headline).foregroundStyle(.primary)
                                    Text(PaceFormat.fullDate(last.startDate).capitalized)
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(PaceFormat.distance(last.kilometers, places: 2)) km")
                                        .font(.headline).foregroundStyle(.primary)
                                    Text("\(PaceFormat.pace(last.paceMinutes)) /km")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(16)
                            .background(PaceColors.surface, in: RoundedRectangle(cornerRadius: 19))
                        }
                        .buttonStyle(.plain)
                    }
                }
                PaceCard {
                    HStack(alignment: .center, spacing: 16) {
                        Image(systemName: "checkmark.shield")
                            .font(.title3).foregroundStyle(PaceColors.teal)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Vos données restent sur l’iPhone").font(.subheadline.weight(.semibold))
                            Text("Synchronisation directe avec Apple Santé. Aucun serveur.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape").font(.body)
                    }
                    .accessibilityLabel("Réglages")
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { PaceSettingsScreen() }
            }
        }
    }
}
