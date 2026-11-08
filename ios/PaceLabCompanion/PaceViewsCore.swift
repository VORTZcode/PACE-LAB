import SwiftUI
import Charts

/// PACE-LAB / ATHLETIC PRECISION — shared spacing, type and surfaces.
enum PaceDesign {
    static let screenInset: CGFloat = 19
    static let sectionSpacing: CGFloat = 24
    static let cardRadius: CGFloat = 20
    static let compactRadius: CGFloat = 16
    static let cardInset: CGFloat = 19
    static let rowMinHeight: CGFloat = 52
}

/// The brand monogram is deliberately vector-native: sharp P motion mark,
/// consistent on every device size, without adding external font dependencies.
struct PaceBrandMark: View {
    var side: CGFloat = 34
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.25, style: .continuous)
                .fill(PaceColors.volt)
            Text("P")
                .font(.system(size: side * 0.75, weight: .black, design: .rounded))
                .italic()
                .foregroundStyle(PaceColors.onVolt)
                .offset(x: -side * 0.015, y: -side * 0.02)
        }
        .frame(width: side, height: side)
        .accessibilityLabel("PACE-LAB")
    }
}

struct PaceBrandLine: View {
    var subtitle: String = "PRECISION / PERFORMANCE / PROGRESSION"
    var body: some View {
        HStack(spacing: 10) {
            PaceBrandMark(side: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text("PACE—LAB")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .tracking(-0.45)
                    .foregroundStyle(PaceColors.porcelain)
                Text(subtitle)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(PaceColors.titanium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Distinctive athletic headline used only on the home screen.
/// It contains no synthetic performance metrics or training promises.
struct PaceAthleticHero: View {
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("RUN")
                    .foregroundStyle(PaceColors.porcelain)
                Text("BEYOND.")
                    .foregroundStyle(PaceColors.volt)
            }
            .font(.system(size: 38, weight: .black, design: .rounded))
            .italic()
            .tracking(-2.1)
            .minimumScaleFactor(0.8)
            .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "figure.run")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(PaceColors.volt)
                .frame(width: 58, height: 58)
                .background(PaceColors.volt.opacity(0.095),
                            in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("RUN BEYOND. PACE-LAB, performance sportive")
    }
}

/// Actual seven-day distances, not decorative graph data. A connected,
/// destination-backed performance stage replaces the former decorative motto.
struct PacePerformanceStage: View {
    let runs: [WorkoutPayload]
    private var calendar: Calendar { .current }
    private var weekStart: Date {
        calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .now
    }
    private var weekRuns: [WorkoutPayload] {
        runs.filter { $0.startDate >= weekStart && $0.startDate <= .now }
    }
    private var weekDistance: Double { weekRuns.reduce(0) { $0 + $1.kilometers } }
    private var weekDuration: Double { weekRuns.reduce(0) { $0 + $1.duration_seconds } }
    private var dailyBars: [Double] {
        (0..<7).map { day in
            guard let start = calendar.date(byAdding: .day, value: day, to: weekStart) else { return 0 }
            return weekRuns.filter { calendar.isDate($0.startDate, inSameDayAs: start) }
                .reduce(0) { $0 + $1.kilometers }
        }
    }
    var body: some View {
        NavigationLink {
            PaceInsightScreen(kind: .week)
        } label: {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ATHLETE / 7 JOURS")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(2.0)
                            .foregroundStyle(PaceColors.volt)
                        Text("LE MOUVEMENT\nEN CHIFFRES.")
                            .font(.system(size: 29, weight: .black, design: .rounded))
                            .italic()
                            .tracking(-1.15)
                            .foregroundStyle(PaceColors.porcelain)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PaceColors.volt)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.08), in: Circle())
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(PaceFormat.distance(weekDistance, places: 2))
                        .font(.system(size: 57, weight: .black, design: .rounded))
                        .tracking(-2.8)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                        .foregroundStyle(PaceColors.porcelain)
                    Text("KM")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(PaceColors.volt)
                }
                HStack(alignment: .bottom, spacing: 7) {
                    let distances = dailyBars
                    let largest = max(distances.max() ?? 0, 0.1)
                    ForEach(0..<7, id: \.self) { index in
                        VStack(spacing: 8) {
                            GeometryReader { geo in
                                VStack {
                                    Spacer(minLength: 0)
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(distances[index] > 0 ? PaceColors.volt : .white.opacity(0.11))
                                        .frame(height: max(5, geo.size.height * distances[index] / largest))
                                }
                            }
                            .frame(height: 57)
                            Text(calendar.date(byAdding: .day, value: index, to: weekStart)?
                                .formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "fr_FR"))) ?? "")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(PaceColors.titanium)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                HStack(spacing: 14) {
                    Label("\(weekRuns.count) sorties", systemImage: "figure.run")
                    Text("•")
                    Label(PaceFormat.duration(weekDuration), systemImage: "clock")
                    Spacer(minLength: 0)
                    Text("ANALYSER")
                        .tracking(1)
                        .foregroundStyle(PaceColors.volt)
                }
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(PaceColors.titanium)
            }
            .padding(21)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(PaceColors.surface)
                    .overlay(alignment: .topTrailing) {
                        Circle().fill(PaceColors.volt.opacity(0.09))
                            .frame(width: 185, height: 185)
                            .blur(radius: 45)
                            .offset(x: 65, y: -65)
                            .clipped()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(PaceColors.volt.opacity(0.15), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Performance des sept derniers jours : \(PaceFormat.distance(weekDistance, places: 2)) kilomètres, \(weekRuns.count) sorties. Voir le détail.")
    }
}

struct PaceEyebrow: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .tracking(1.6)
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
            Text(title).font(.system(.title3, design: .rounded, weight: .bold))
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
                Text(value).font(.system(.title2, design: .rounded, weight: .black))
                    .monospacedDigit()
                    + Text(" " + suffix).font(.subheadline.weight(.regular)).foregroundStyle(.secondary)
                Text(caption).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal:false,vertical:true)
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
                PaceBrandLine()
                    .padding(.bottom, 3)
                content
            }
            .padding(.horizontal, PaceDesign.screenInset)
            .padding(.top, 12)
            .padding(.bottom, 95)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .background(PaceColors.base)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Quiet Liquid Glass for reading surfaces. It intentionally has no interactive
/// glass response: only buttons and controls should react to touch.
/// V18: opaque athletic data surfaces. Transparent glass belongs to
/// floating actions, not every scrollable information card.
struct PaceGlassCardSurface: ViewModifier {
    var cornerRadius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .background(PaceColors.surface,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(PaceColors.porcelain.opacity(0.075), lineWidth: 0.75)
                    .allowsHitTesting(false)
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
    @EnvironmentObject var autopilot: PaceAutopilot
    @EnvironmentObject var tabs: PaceTabRouter
    @EnvironmentObject var engine: HealthSyncEngine
    @EnvironmentObject var library: PaceLibrary
    @EnvironmentObject var strengthTracker: PaceStrengthTracker
    @State private var showSettings = false
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
                PacePerformanceStage(runs: engine.runHistory)
                // One clear actionable workout after a real, clickable performance stage.
                PaceSectionTitle(title: "À toi de jouer", subtitle: "Prochaine étape")
                if let day = library.nextDay {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            PaceEyebrow(title: "Votre prochaine séance")
                            Spacer()
                            Text(day.day.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(day.title)
                            .font(.system(.title2, design: .rounded, weight: .semibold))
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
                        .tint(PaceColors.volt)
                        .foregroundStyle(PaceColors.onVolt)
                        .controlSize(.large)
                    }
                    .padding(17)
                    .modifier(PaceGlassCardSurface(cornerRadius: 26))
                } else {
                    PaceCard {
                        VStack(alignment:.leading,spacing:12) {
                            let allDone = !library.currentPlan.isEmpty &&
                                library.completedCount == library.currentPlan.count
                            Label(allDone ? "Cycle terminé" : "Programme arrivé à échéance",
                                  systemImage:allDone ? "checkmark.seal.fill" : "calendar.badge.exclamationmark")
                                .font(.headline)
                                .foregroundStyle(PaceColors.teal)
                            Text(allDone
                                 ? "Tu as validé toutes les journées du programme. Prépare le cycle suivant avec ton coach."
                                 : "Aucune séance future n'est encore programmée. Le coach peut préparer une nouvelle semaine à partir de tes données.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button {
                                tabs.openCoach(.programme)
                            } label: {
                                Label("Préparer la prochaine semaine", systemImage:"brain.head.profile")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(PaceColors.teal)
                        }
                    }
                }

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
                            VStack(alignment: .trailing, spacing: 3) {
                                if latest.kilometers > 0.1 {
                                    Text("\(PaceFormat.distance(latest.kilometers, places: 2)) km")
                                        .font(.subheadline.weight(.semibold))
                                }
                                Text(PaceFormat.duration(latest.duration_seconds))
                                    .font(latest.kilometers > 0.1 ? .caption : .subheadline.weight(.semibold))
                                    .foregroundStyle(latest.kilometers > 0.1 ? .secondary : .primary)
                            }
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
                PaceLivingCoachCard { destination in
                    switch destination {
                    case "programme": tabs.selected = .programme
                    case "plan": tabs.openCoach(.programme)
                    case "bilans": tabs.openCoach(.bilans)
                    case "settings": tabs.openCoach(.settings)
                    default: tabs.openCoach(.discussion)
                    }
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
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { tabs.selected = .coach } label: {
                        Image(systemName:"brain.head.profile")
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
