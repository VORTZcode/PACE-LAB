import SwiftUI
import Charts

struct ActivitiesScreen: View {
    @EnvironmentObject var engine: HealthSyncEngine
    @State private var kind = 0
    @State private var shown = 25
    @State private var selectedYear = 0
    private var availableYears: [Int] {
        Array(Set(engine.snapshot.map { Calendar.current.component(.year, from: $0.startDate) }))
            .sorted(by: >)
    }
    private var all: [WorkoutPayload] {
        engine.snapshot.filter { workout in
            let kindMatches = kind == 0 ? workout.isRun :
                (kind == 1 ? workout.activity_kind == "walking" : true)
            return kindMatches && (selectedYear == 0 ||
                    Calendar.current.component(.year, from: workout.startDate) == selectedYear)
        }
    }
    private var year: Int { Calendar.current.component(.year, from: .now) }
    private var statYear: Int { selectedYear == 0 ? year : selectedYear }
    var body: some View {
        NavigationStack {
            PaceScreen(title: "Activités") {
                Picker("Type d’activité", selection: $kind) {
                    Text("Course").tag(0)
                    Text("Marche").tag(1)
                    Text("Toutes").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: kind) { _, _ in shown = 25 }

                HStack {
                    Text("Période").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Button("Toutes les années") { selectedYear = 0; shown = 25 }
                        Divider()
                        ForEach(availableYears, id: \.self) { year in
                            Button(String(year)) { selectedYear = year; shown = 25 }
                        }
                    } label: {
                        Label(selectedYear == 0 ? "Toutes les années" : String(selectedYear),
                              systemImage: "line.3.horizontal.decrease")
                            .font(.subheadline.weight(.medium))
                    }
                    .modifier(PaceGlassTreatment())
                    .tint(.primary)
                }
                if kind == 0 {
                    HStack(spacing: 10) {
                        PaceMetric(caption: "Courses \(statYear)", value: "\(engine.runs(year: statYear).count)", suffix: "", symbol: "figure.run")
                        PaceMetric(caption: "Distance \(statYear)", value: PaceFormat.distance(engine.totalDistance(year: statYear)), suffix: "km", symbol: "point.topleft.down.curvedto.point.bottomright.up")
                    }
                }
                PaceSectionTitle(title: "Historique", subtitle: "\(all.count) activités")
                LazyVStack(spacing: 0) {
                    ForEach(Array(all.prefix(shown))) { workout in
                        NavigationLink { WorkoutDetailScreen(workout: workout) } label: {
                            ActivityRow(workout: workout)
                        }
                        .buttonStyle(.plain)
                        if workout.id != all.prefix(shown).last?.id { Divider().padding(.leading, 54) }
                    }
                }
                .padding(.horizontal, 16)
                .background(PaceColors.surface, in: RoundedRectangle(cornerRadius: 22))
                if shown < all.count {
                    Button("Afficher plus de séances") { shown += 25 }
                        .font(.subheadline.weight(.medium)).tint(PaceColors.teal)
                        .frame(maxWidth: .infinity)
                }
                if all.isEmpty {
                    ContentUnavailableView("Aucune activité", systemImage: "figure.run", description: Text("Les activités autorisées apparaîtront après synchronisation avec Apple Santé."))
                }
            }
        }
    }
}

struct ActivityRow: View {
    let workout: WorkoutPayload
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: workout.symbol)
                .font(.system(size: 19))
                .foregroundStyle(PaceColors.teal)
                .frame(width: 40, height: 42)
            VStack(alignment: .leading, spacing: 5) {
                Text(workout.cadenceLabel).font(.subheadline.weight(.semibold))
                Text(PaceFormat.fullDate(workout.startDate).capitalized)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 5)
            VStack(alignment: .trailing, spacing: 4) {
                Text(workout.kilometers > 0.1 ? "\(PaceFormat.distance(workout.kilometers, places: 2)) km" : PaceFormat.duration(workout.duration_seconds))
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                Text(workout.isRun ? "\(PaceFormat.pace(workout.paceMinutes)) /km" : PaceFormat.duration(workout.duration_seconds))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                .padding(.leading, 2)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
struct WorkoutDetailScreen: View {
    @EnvironmentObject private var journal: PaceSessionJournal
    @State private var showJournal = false
    @State private var showIntervals = false
    @State private var showComparison = false
    let workout: WorkoutPayload
    var body: some View {
        ScrollViewReader { navigator in
        PaceScreen(title: "Séance") {
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.cadenceLabel.uppercased())
                    .font(.caption2.weight(.bold)).tracking(1.3).foregroundStyle(PaceColors.teal)
                Text(PaceFormat.fullDate(workout.startDate).capitalized)
                    .font(.title2.weight(.semibold))
                Text(workout.endDate.formatted(.dateTime.hour().minute()))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(PaceFormat.distance(workout.kilometers, places: 2))
                        .font(.system(size: 54, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text("km").font(.title3).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    PacePill(label: PaceFormat.duration(workout.duration_seconds), symbol: "clock")
                    if workout.isRun { PacePill(label: "\(PaceFormat.pace(workout.paceMinutes)) /km", symbol: "speedometer") }
                }
            }
            RunDynamicsSection(original: workout)
                .id("heart-chart")
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showIntervals.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "list.number")
                            .foregroundStyle(PaceColors.teal)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Voir les intervalles").font(.subheadline.weight(.semibold))
                            Text("Allure, fréquence cardiaque et puissance par 5 minutes")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: showIntervals ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PaceColors.surface, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                if showIntervals {
                    RunIntervalsSection(workout: workout)
                }
            }
            .id("run-intervals")
            PaceSectionTitle(title: "Après l’effort").id("recovery")
            PaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Récupération cardiaque").font(.subheadline.weight(.semibold))
                        Spacer()
                        if workout.recovery_state == "complete" {
                            PacePill(label: "Mesurée", symbol: "checkmark.circle")
                        }
                    }
                    HStack(spacing: 0) {
                        recoveryValue("Arrêt", value: workout.hr_at_end_bpm)
                        Spacer()
                        recoveryValue("1 min", value: workout.recovery_hr_1min)
                        Spacer()
                        recoveryValue("2 min", value: workout.recovery_hr_2min)
                        Spacer()
                        recoveryValue("3 min", value: workout.recovery_hr_3min)
                    }
                    if let end = workout.hr_at_end_bpm, let one = workout.recovery_hr_1min {
                        HStack {
                            Label("Variation après 1 min", systemImage: "heart.text.square")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int((end - one).rounded())) bpm")
                                .font(.subheadline.weight(.semibold)).monospacedDigit()
                        }
                    }
                    Divider()
                    Text("Mesures réelles disponibles autour de chaque instant. Le suivi peut être incomplet et n’est pas un diagnostic médical.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showComparison.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.split.2x1").foregroundStyle(PaceColors.teal)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Comparer avec une autre sortie").font(.subheadline.weight(.semibold))
                            Text("Distances similaires, sans conclusion automatique")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: showComparison ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PaceColors.surface, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                if showComparison {
                    SimilarRunComparison(workout: workout)
                }
            }
            .id("comparison")
            PaceSectionTitle(title: "Mon journal").id("journal")
            PaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    let entry = journal.note(for: workout.source_uuid)
                    HStack(spacing: 12) {
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.title3).foregroundStyle(PaceColors.teal)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.effort.map { "Effort ressenti : \($0)/10" } ?? "Ajouter mon ressenti")
                                .font(.subheadline.weight(.semibold))
                            Text(entry.comment.isEmpty ? "Note, sensations, fatigue et difficulté perçue" : entry.comment)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    Button {
                        showJournal = true
                    } label: {
                        Label(entry.effort == nil && entry.comment.isEmpty ? "Renseigner ma séance" : "Modifier mon journal", systemImage: "square.and.pencil")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(PaceColors.teal)
                }
            }
            Label("Mesures enregistrées par Apple Santé", systemImage: "applewatch")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Graphiques", systemImage: "waveform.path.ecg") {
                        withAnimation(.easeInOut(duration: 0.22)) { navigator.scrollTo("heart-chart", anchor: .top) }
                    }
                    Button("Intervalles de 5 minutes", systemImage: "list.number") {
                        showIntervals = true
                        withAnimation(.easeInOut(duration: 0.22)) { navigator.scrollTo("run-intervals", anchor: .top) }
                    }
                    Button("Récupération", systemImage: "heart.text.square") {
                        withAnimation(.easeInOut(duration: 0.22)) { navigator.scrollTo("recovery", anchor: .top) }
                    }
                    Button("Comparer", systemImage: "rectangle.split.2x1") {
                        showComparison = true
                        withAnimation(.easeInOut(duration: 0.22)) { navigator.scrollTo("comparison", anchor: .top) }
                    }
                    Button("Mon journal", systemImage: "square.and.pencil") {
                        withAnimation(.easeInOut(duration: 0.22)) { navigator.scrollTo("journal", anchor: .top) }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Aller directement à une section")
            }
        }
        .sheet(isPresented: $showJournal) {
            PaceEffortEditor(uuid: workout.source_uuid)
                .environmentObject(journal)
        }
        }
    }
    private func recoveryValue(_ label: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(PaceFormat.heart(value)).font(.title2.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
