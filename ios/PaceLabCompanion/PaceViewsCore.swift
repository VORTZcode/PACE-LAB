import SwiftUI
import Charts

/// PACE LAB 4.0 design tokens: a single visual rhythm across all major screens.
enum PaceDesign {
    static let screenInset: CGFloat = 19
    static let sectionSpacing: CGFloat = 23
    static let cardRadius: CGFloat = 24
    static let compactRadius: CGFloat = 18
    static let cardInset: CGFloat = 19
    static let rowMinHeight: CGFloat = 52
}

struct PaceEyebrow: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .tracking(1.25)
            .foregroundStyle(PaceColors.teal)
            .accessibilityAddTraits(.isHeader)
    }
}

struct PaceCard<Content: View>: View {
    var padding: CGFloat = PaceDesign.cardInset
    @ViewBuilder let content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .modifier(PaceGlassCardSurface(cornerRadius: PaceDesign.cardRadius))
    }
}
struct PaceSectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(.title3, design: .rounded, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
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
            LazyVStack(alignment: .leading, spacing: PaceDesign.sectionSpacing) {
                content
            }
            .padding(.horizontal, PaceDesign.screenInset)
            .padding(.top, 12)
            .padding(.bottom, 36)
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
    @EnvironmentObject var living: PaceLivingCoach
    @EnvironmentObject var adaptiveMonitor: PaceAdaptiveMonitor
    @EnvironmentObject var engine: HealthSyncEngine
    @EnvironmentObject var library: PaceLibrary
    @EnvironmentObject var strengthTracker: PaceStrengthTracker
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
                // One clear hero instead of competing cards: the next actionable workout.
                if let day = library.nextDay {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            PaceEyebrow(title: "Votre prochaine séance")
                            Spacer()
                            Text(day.day.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(day.title)
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            PacePill(label: day.type, symbol: day.type == "Course"
                                     ? "figure.run" : day.type == "Musculation" ? "dumbbell" : "leaf")
                            PacePill(label: "\(Int(day.minutes)) min", symbol: "clock")
                        }
                        Text(day.objective)
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if day.type == "Musculation" && library.activeCoachDraft == nil {
                            let planned = library.programme.force.filter { $0.day == day.day }
                            let done = strengthTracker.completedSets(day: day.date, exercises: planned)
                            let total = strengthTracker.totalSets(exercises: planned)
                            HStack {
                                Text("Progression")
                                    .font(.caption.weight(.medium))
                                Spacer()
                                Text("\(done)/\(total) séries")
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                            }
                            ProgressView(value: Double(done), total: Double(max(total, 1)))
                                .tint(PaceColors.teal)
                        }
                        Button {
                            trainingNavigationPath.append(day.date)
                        } label: {
                            HStack {
                                Text("Ouvrir ma séance").fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PaceColors.teal)
                        .controlSize(.large)
                    }
                    .padding(22)
                    .modifier(PaceGlassCardSurface(cornerRadius: 28))
                } else {
                    PaceCard {
                        Label("Programme de la semaine terminé", systemImage: "checkmark.seal.fill")
                            .font(.headline).foregroundStyle(PaceColors.teal)
                    }
                }

                PaceLivingCoachCard { showCoach = true }
                PaceSectionTitle(title: "Votre activité")
                if let latest = engine.snapshot.first {
                    NavigationLink {
                        if latest.activity_kind == "strength" {
                            StrengthWorkoutDetailScreen(workout: latest)
                        } else {
                            WorkoutDetailScreen(workout: latest)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: latest.symbol)
                                .font(.title2)
                                .foregroundStyle(PaceColors.teal)
                                .frame(width: 45)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Dernière activité")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(latest.cadenceLabel)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(PaceFormat.fullDate(latest.startDate).capitalized)
                                    .font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            Text(PaceFormat.duration(latest.duration_seconds))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Image(systemName:"chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PaceColors.teal)
                        }
                        .padding(16)
                        .modifier(PaceGlassCardSurface(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 10) {
                    NavigationLink {
                        PaceInsightScreen(kind: .week)
                    } label: {
                        PaceMetric(caption: "7 derniers jours",
                                   value: PaceFormat.distance(sevenKm),
                                   suffix: "km", symbol: "calendar")
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        PaceInsightScreen(kind: .month)
                    } label: {
                        PaceMetric(caption: "Ce mois-ci",
                                   value: PaceFormat.distance(engine.runHistory.filter {
                                       Calendar.current.isDate($0.startDate, equalTo: .now, toGranularity: .month)
                                   }.reduce(0) { $0 + $1.kilometers }),
                                   suffix: "km", symbol: "figure.run")
                    }
                    .buttonStyle(.plain)
                }
                Button { showCoach = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName:"sparkles")
                            .font(.title3).foregroundStyle(PaceColors.teal)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Votre coach")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(adaptiveMonitor.visible == nil
                                 ? "Bilan et recommandations" : "Une recommandation vous attend")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName:"arrow.up.right")
                            .foregroundStyle(PaceColors.teal)
                    }
                    .padding(17)
                    .modifier(PaceGlassCardSurface(cornerRadius: 20))
                }
                .buttonStyle(.plain)
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
