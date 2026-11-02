import SwiftUI
import Charts

struct PaceCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder let content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .modifier(PaceGlassCardSurface(cornerRadius: 22))
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
        .modifier(PaceGlassCardSurface(cornerRadius: 20))
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
            LazyVStack(alignment: .leading, spacing: 24) {
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

/// Quiet Liquid Glass for reading surfaces. It intentionally has no interactive
/// glass response: only buttons and controls should react to touch.
struct PaceGlassCardSurface: ViewModifier {
    var cornerRadius: CGFloat = 22

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(.regularMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

struct PaceHomeGlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 24
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(.regularMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

struct TodayScreen: View {
    @EnvironmentObject var adaptiveMonitor: PaceAdaptiveMonitor
    @EnvironmentObject var engine: HealthSyncEngine
    @EnvironmentObject var library: PaceLibrary
    @State private var showSettings = false
    @State private var showCoach = false
    @State private var trainingNavigationPath: [String] = []

    private var last: WorkoutPayload? { engine.runHistory.first }
    private var year: Int { Calendar.current.component(.year, from: .now) }
    private var lastSeven: [WorkoutPayload] {
        let beginning = Date.now.addingTimeInterval(-7 * 86400)
        return engine.runHistory.filter { $0.startDate >= beginning && $0.startDate <= .now }
    }
    private var sevenKm: Double { lastSeven.reduce(0) { $0 + $1.kilometers } }

    var body: some View {
        NavigationStack(path: $trainingNavigationPath) {
            PaceScreen(title: "Aujourd’hui") {
                HStack {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR"))))
                        .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Spacer()
                    Label("Apple Santé", systemImage: "heart.text.square")
                        .font(.caption.weight(.medium)).foregroundStyle(PaceColors.teal)
                }
                if let last {
                    VStack(alignment: .leading, spacing: 12) {
                        PaceSectionTitle(title: "Dernière course")
                        NavigationLink {
                            WorkoutDetailScreen(workout: last)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "figure.run")
                                    .font(.title2).foregroundStyle(PaceColors.teal)
                                    .frame(width: 46, height: 46)
                                    .background(PaceColors.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Voir les statistiques").font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.8)
                                    Text(last.startDate.formatted(.dateTime.day().month().year()))
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(PaceFormat.distance(last.kilometers, places: 2)) km")
                                        .font(.headline).foregroundStyle(.primary)
                                    Text("\(PaceFormat.pace(last.paceMinutes)) /km")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Image(systemName: "arrow.up.right.circle.fill").font(.title3).foregroundStyle(PaceColors.teal)
                            }
                            .padding(17)
                            .modifier(PaceHomeGlassSurface(cornerRadius: 19))
                        }
                        .buttonStyle(.plain)
                    }
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
                        Button {
                            trainingNavigationPath.append(day.date)
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
                    .modifier(PaceGlassCardSurface(cornerRadius: 24))
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
                Button { showCoach = true } label: {
                    HStack(spacing:13) {
                        Image(systemName:"waveform.path.ecg")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(PaceColors.teal)
                            .frame(width:43,height:43)
                            .background(PaceColors.teal.opacity(0.10),
                                        in:RoundedRectangle(cornerRadius:14))
                        VStack(alignment:.leading,spacing:4) {
                            Text("Mon coach").font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(adaptiveMonitor.visible == nil
                                 ? "Bilan de séance · Mes objectifs"
                                 : "Un point après séance t'attend")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength:6)
                        Image(systemName:"chevron.right")
                            .font(.caption.weight(.semibold)).foregroundStyle(PaceColors.teal)
                    }
                    .padding(15)
                    .modifier(PaceGlassCardSurface(cornerRadius: 19))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Ouvrir le suivi sportif personnalisé")
                VStack(alignment: .leading, spacing: 12) {
                    PaceSectionTitle(title: "Ma progression")
                    NavigationLink {
                        PaceInsightScreen(kind: .year)
                    } label: {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Label("Distance parcourue en \(year)", systemImage: "figure.run")
                                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundStyle(PaceColors.teal)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(PaceFormat.distance(engine.totalDistance(year: year)))
                                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                                    .minimumScaleFactor(0.75)
                                    .lineLimit(1)
                                    .monospacedDigit()
                                Text("km").font(.headline).foregroundStyle(.secondary)
                            }
                            Divider()
                            HStack {
                                Text("\(engine.runs(year: year).count) courses cette année")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PaceColors.teal)
                            }
                        }
                        .padding(22)
                        .modifier(PaceHomeGlassSurface(cornerRadius: 26))
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 10) {
                        NavigationLink {
                            PaceInsightScreen(kind: .month)
                        } label: {
                            PaceMetric(caption: "Distance ce mois", value: PaceFormat.distance(engine.runHistory.filter {
                                Calendar.current.isDate($0.startDate, equalTo: .now, toGranularity: .month)
                            }.reduce(0) { $0 + $1.kilometers }), suffix: "km", symbol: "calendar")
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(PaceColors.teal)
                                        .padding(15)
                                }
                        }
                        .buttonStyle(.plain)
                        NavigationLink {
                            PaceInsightScreen(kind: .heart)
                        } label: {
                            PaceMetric(caption: "FC dernière course",
                                       value: last.map { PaceFormat.heart($0.hr_average_bpm) } ?? "—",
                                       suffix: "bpm", symbol: "heart")
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(PaceColors.teal)
                                        .padding(15)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    NavigationLink {
                        PaceInsightScreen(kind: .week)
                    } label: {
                        HStack(alignment: .center, spacing: 15) {
                            Image(systemName: "calendar")
                                .font(.title3)
                                .foregroundStyle(PaceColors.teal)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sur les 7 derniers jours")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(lastSeven.count) courses enregistrées")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(PaceFormat.distance(sevenKm))
                                    .font(.title3.weight(.semibold)).monospacedDigit()
                                Text("km").font(.caption).foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PaceColors.teal)
                        }
                        .padding(18)
                        .modifier(PaceGlassCardSurface(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }
                Label("Données Apple Santé conservées uniquement sur cet iPhone",
                      systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showCoach = true } label: {
                        Image(systemName:"sparkles")
                    }
                    .accessibilityLabel("Coach ChatGPT")
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape").font(.body)
                    }
                    .accessibilityLabel("Réglages")
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { PaceSettingsScreen() }
            }
            .sheet(isPresented: $showCoach) {
                PaceCoachScreen()
            }
            // A stable date-based route is not replaced when validating the current day
            // causes nextDay to change to Tuesday while its detail is still visible.
            .navigationDestination(for: String.self) { selectedDate in
                if let selected = library.currentPlan.first(where: { $0.date == selectedDate }) {
                    DayDetailScreen(day: selected)
                } else {
                    ContentUnavailableView("Séance introuvable",
                        systemImage: "calendar.badge.exclamationmark")
                }
            }
        }
    }
}
