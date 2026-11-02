import SwiftUI

struct ProgrammeScreen: View {
    @EnvironmentObject var library: PaceLibrary
    @EnvironmentObject var strengthTracker: PaceStrengthTracker
    @State private var showCoach = false

    var body: some View {
        NavigationStack {
            PaceScreen(title: "Programme") {
                VStack(alignment: .leading, spacing: 8) {
                    PaceEyebrow(title: "Votre parcours")
                    Text(library.activeCoachDraft == nil ? "Cette semaine" : "Programme coach")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                    Text(library.activeCoachDraft == nil
                    ? "Course, renforcement et récupération · \(library.currentPlan.count) jours"
                    : "Programme proposé par le coach et validé sur cet iPhone.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                PaceCard {
                    HStack(alignment: .center, spacing: 18) {
                        ZStack {
                            Circle().stroke(PaceColors.teal.opacity(0.13), lineWidth: 7)
                            Circle()
                                .trim(from: 0, to: CGFloat(library.completedCount) / CGFloat(max(library.currentPlan.count, 1)))
                                .stroke(PaceColors.teal, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(library.completedCount)/\(max(library.currentPlan.count, 1))")
                                .font(.subheadline.weight(.bold)).monospacedDigit()
                        }
                        .frame(width: 68, height: 68)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Progression hebdomadaire").font(.headline)
                            Text("\(library.completedCount) séances ou journées validées")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                if !library.approvedAdjustments.isEmpty {
                    PaceCard {
                        VStack(alignment:.leading,spacing:11) {
                            Label("Adaptation validée",systemImage:"checkmark.shield")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PaceColors.teal)
                            Text("Une séance a été ajustée à partir de ton ressenti. Les autres jours du programme restent inchangés.")
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach(library.approvedAdjustments.values.sorted(by:{$0.sessionDate < $1.sessionDate})) { adjustment in
                                HStack(alignment:.center,spacing:10) {
                                    VStack(alignment:.leading,spacing:4) {
                                        Text(adjustment.sessionDate)
                                            .font(.caption.weight(.medium))
                                        Text(adjustment.recommendation == .pause ? "Repos" : "\(adjustment.minutes) min faciles")
                                            .font(.subheadline)
                                    }
                                    Spacer()
                                    Button("Annuler l'adaptation") {
                                        library.undoAdaptation(on:adjustment.sessionDate)
                                    }
                                    .font(.caption.weight(.semibold))
                                }
                                .tint(PaceColors.teal)
                            }
                        }
                    }
                }

                PaceSectionTitle(title: "Les prochains jours", subtitle: "Choisissez une séance")
                if let draft = library.activeCoachDraft {
                    PaceCard {
                        VStack(alignment: .leading, spacing: 9) {
                            Label("Programme personnalisé", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(PaceColors.teal)
                            Text(draft.summary)
                                .font(.footnote).foregroundStyle(.secondary).lineLimit(5)
                            Button("Revenir au programme initial") { library.revertCoachPlan() }
                                .font(.caption.weight(.medium)).tint(PaceColors.teal)
                        }
                    }
                }
                LazyVStack(spacing: 10) {
                    ForEach(library.currentPlan) { day in
                        let isCurrent = Calendar.current.isDateInToday({
                            let parser = DateFormatter()
                            parser.locale = Locale(identifier: "en_US_POSIX")
                            parser.dateFormat = "yyyy-MM-dd"
                            return parser.date(from: day.date) ?? .distantPast
                        }())
                        NavigationLink { DayDetailScreen(day: day) } label: {
                            HStack(spacing: 14) {
                                VStack(spacing: 3) {
                                    Text(String(day.day.prefix(3)).uppercased())
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text(String(day.date.suffix(2)))
                                        .font(.title3.weight(.bold)).monospacedDigit()
                                }
                                .frame(width: 42)
                                Image(systemName: day.type == "Course" ? "figure.run" : day.type == "Musculation" ? "dumbbell" : "figure.cooldown")
                                    .font(.title3)
                                    .frame(width: 35)
                                    .foregroundStyle(PaceColors.teal)
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 7) {
                                        Text(day.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                        if isCurrent {
                                            Text("AUJ.").font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(PaceColors.teal)
                                        }
                                    }
                                    Text("\(day.type) · \(Int(day.minutes)) min")
                                        .font(.caption).foregroundStyle(.secondary)
                                    if day.type == "Musculation" && library.activeCoachDraft == nil {
                                        let exercises = library.programme.force.filter { $0.day == day.day }
                                        Text("\(strengthTracker.completedSets(day: day.date, exercises: exercises)) / \(strengthTracker.totalSets(exercises: exercises)) séries validées")
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(PaceColors.teal)
                                            .monospacedDigit()
                                    }
                                }
                                Spacer(minLength: 4)
                                Image(systemName: library.completed.contains(day.date) ? "checkmark.circle.fill" : "chevron.right")
                                    .foregroundStyle(library.completed.contains(day.date) ? PaceColors.teal : Color.secondary)
                            }
                            .padding(16)
                            .modifier(PaceGlassCardSurface(cornerRadius: isCurrent ? 23 : 19))
                            .overlay {
                                if isCurrent {
                                    RoundedRectangle(cornerRadius: 23)
                                        .strokeBorder(PaceColors.teal.opacity(0.55), lineWidth: 1.5)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Le cycle suivant sera proposé après analyse des séances et de la récupération. Aucun entraînement futur n’est inventé.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 3)
            }
        }
        .toolbar {
            ToolbarItem(placement:.topBarTrailing) {
                Button { showCoach = true } label: { Image(systemName:"sparkles") }
                    .accessibilityLabel("Adapter mon programme avec ChatGPT")
            }
        }
        .sheet(isPresented:$showCoach) { PaceCoachScreen() }
    }
}

struct DayDetailScreen: View {
    @EnvironmentObject var engine: HealthSyncEngine
    @EnvironmentObject var library: PaceLibrary
    @EnvironmentObject var strengthTracker: PaceStrengthTracker
    @EnvironmentObject var strengthLinks: PaceStrengthWorkoutLinks
    let day: PaceDay
    @State private var showVariants = false
    @State private var confirmFinish = false
    @State private var presentedExerciseID: String?
    @State private var expandedExerciseID: String?
    @State private var restEnd: Date?
    @State private var restExerciseID: String?
    @State private var restSetNumber: Int?
    @FocusState private var focusedStrengthInput: PaceStrengthInput?

    private var exerciseCompletionSignature: [Bool] {
        exercises.map { strengthTracker.completedSets(day: day.date, exercise: $0) >= $0.sets }
    }

    private func advanceAfterCompletion(from old: [Bool], to new: [Bool]) {
        guard let currentIndex = exercises.firstIndex(where: { $0.id == expandedExerciseID }),
              old.indices.contains(currentIndex), new.indices.contains(currentIndex),
              !old[currentIndex], new[currentIndex] else { return }
        let next = exercises.indices.first { $0 > currentIndex && !new[$0] }
        withAnimation(.easeInOut(duration: 0.22)) {
            expandedExerciseID = next.map { exercises[$0].id }
        }
        focusedStrengthInput = nil
    }

    private func onStrengthSetChanged(exercise: PaceExercise, index: Int, completed: Bool) {
        focusedStrengthInput = nil
        if completed && index < exercise.sets {
            restExerciseID = exercise.id
            restSetNumber = index
            restEnd = Date().addingTimeInterval(max(0,exercise.rest))
        } else {
            restEnd = nil
            restExerciseID = nil
            restSetNumber = nil
        }
    }

    private var exercises: [PaceExercise] {
        guard library.activeCoachDraft == nil else { return [] }
        return library.programme.force.filter { $0.day == day.day }
    }
    private var matchingActivity: WorkoutPayload? {
        let expected: String
        switch day.type {
        case "Course": expected = "running"
        case "Musculation": expected = "strength"
        case "Récupération": expected = "walking"
        default: return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: day.date) else { return nil }
        let candidates = engine.snapshot.filter {
            $0.activity_kind == expected && Calendar.current.isDate($0.startDate, inSameDayAs: date)
        }
        // Do not silently associate the wrong strength activity on days with multiple workouts.
        return expected == "strength" ? (candidates.count == 1 ? candidates.first : nil) : candidates.first
    }


    var body: some View {
        PaceScreen(title: day.day) {
            VStack(alignment: .leading, spacing: 7) {
                Text(day.type.uppercased())
                    .font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(PaceColors.teal)
                Text(day.title).font(.system(size: 30, weight: .semibold))
                Text(day.objective).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    PacePill(label: "\(Int(day.minutes)) minutes", symbol: "clock")
                    PacePill(label: day.type, symbol: "figure.run")
                }
                .padding(.top, 5)
            }
            if exercises.isEmpty {
                PaceEffortGuide(day: day)
            }
            if !exercises.isEmpty {
                let done = strengthTracker.completedSets(day: day.date, exercises: exercises)
                let total = strengthTracker.totalSets(exercises: exercises)
                PaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Ta progression")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(done) / \(total) séries")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(PaceColors.teal)
                        }
                        ProgressView(value: Double(done), total: Double(max(total, 1)))
                            .tint(PaceColors.teal)
                        Text("Avance à ton rythme. Chaque série est enregistrée dès sa validation.")
                            .font(.caption).foregroundStyle(.secondary)
                        DisclosureGroup("Comprendre RPE 6–7 et RIR 2–3") {
                            PaceStrengthIntensityGuide().padding(.top, 8)
                        }
                        .font(.footnote.weight(.medium)).tint(PaceColors.teal)
                    }
                }
                PaceSectionTitle(title: "Exercices", subtitle: "\(exercises.count) mouvements")
                ForEach(exercises.indices, id: \.self) { index in
                    let ex = exercises[index]
                    let finished = strengthTracker.completedSets(day: day.date, exercise: ex)
                    let expanded = expandedExerciseID == ex.id
                    PaceCard {
                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                focusedStrengthInput = nil
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    presentedExerciseID = ex.id
                                }
                            } label: {
                                HStack(spacing: 13) {
                                    Text("\(index + 1)")
                                        .font(.subheadline.weight(.bold))
                                        .monospacedDigit()
                                        .foregroundStyle(finished == ex.sets ? .white : PaceColors.teal)
                                        .frame(width: 36, height: 36)
                                        .background(finished == ex.sets ? PaceColors.teal :
                                            PaceColors.teal.opacity(0.10), in: Circle())
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(ex.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                        Text("\(ex.reps) · \(finished)/\(ex.sets) séries")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                    Spacer(minLength: 4)
                                    if finished == ex.sets {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(PaceColors.teal)
                                    }
                                    Image(systemName: "chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .rotationEffect(.degrees(expanded ? 180 : 0))
                                }
                                .frame(minHeight: 52)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(ex.name), \(finished) séries validées sur \(ex.sets)")
                            .accessibilityHint(expanded ? "Replier l'exercice" : "Déplier l'exercice")

                            if false {
                                Divider().padding(.vertical, 12)
                                let technique = PaceMovementGuide.forExercise(ex)
                                Text(technique.check)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.bottom, 18)
                                HStack {
                                    Text("SÉRIES")
                                        .font(.caption2.weight(.bold))
                                        .tracking(1.4)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(finished) sur \(ex.sets) terminées")
                                        .font(.caption.weight(.medium))
                                        .monospacedDigit()
                                        .foregroundStyle(PaceColors.teal)
                                }
                                .padding(.bottom, 8)
                                ForEach(1...max(ex.sets, 1), id: \.self) { setNumber in
                                    PaceStrengthSetRow(dayDate: day.date, exercise: ex,
                                                       setNumber: setNumber, focus: $focusedStrengthInput,
                                                       didToggle: { completed in
                                                           onStrengthSetChanged(exercise: ex, index: setNumber,
                                                                               completed: completed)
                                                       })
                                        .padding(.bottom, 9)
                                }
                                if restExerciseID == ex.id, let end = restEnd {
                                    PaceRestCountdown(end: end, seconds: Int(ex.rest),
                                                      afterSet: restSetNumber ?? 0) {
                                        restEnd = nil
                                        restExerciseID = nil
                                        restSetNumber = nil
                                    }
                                    .padding(.top, 12)
                                }
                                DisclosureGroup("Technique et démonstration") {
                                    PaceExerciseCoaching(exercise: ex)
                                        .padding(.top, 12)
                                }
                                .font(.subheadline.weight(.semibold))
                                .tint(PaceColors.teal)
                                .padding(.top, 16)
                                DisclosureGroup("Consignes et intensité") {
                                    VStack(alignment: .leading, spacing: 9) {
                                        Text(day.instructions)
                                        Text(day.intensity)
                                        PaceStrengthIntensityGuide()
                                    }
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                }
                                .font(.footnote.weight(.medium))
                                .tint(PaceColors.teal)
                                .padding(.top, 10)
                                DisclosureGroup("Variantes et progression") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Plus facile : " + ex.easier)
                                        Text("Plus difficile : " + ex.harder)
                                    }
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                }
                                .font(.footnote.weight(.medium))
                                .tint(PaceColors.teal)
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            }

            if let found = matchingActivity,
               !library.completed.contains(day.date) ||
                (day.type == "Musculation" &&
                 strengthLinks.confirmedWorkoutUUID(for: day.date) != found.source_uuid) {
                PaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Activité trouvée dans Apple Santé", systemImage: "applewatch")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PaceColors.teal)
                        Text("\(found.cadenceLabel) · \(PaceFormat.duration(found.duration_seconds))")
                            .font(.subheadline)
                        Text("Est-ce bien la séance prévue ? L’application ne peut pas vérifier toutes les consignes, ni les exercices réalisés.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button {
                            if day.type == "Musculation" {
                                strengthLinks.confirm(day: day.date, workoutUUID: found.source_uuid)
                                if strengthLinks.confirmedWorkoutUUID(for: day.date) == found.source_uuid {
                                    library.markDayCompleted(day.date)
                                }
                            } else {
                                library.markDayCompleted(day.date)
                            }
                        } label: {
                            Label(day.type == "Musculation"
                                  ? "Associer à ma séance et valider"
                                  : "Oui, valider cette séance", systemImage: "checkmark.circle")
                        }
                        .font(.subheadline.weight(.semibold))
                        .tint(PaceColors.teal)
                    }
                }
            }

            if let error = strengthLinks.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.orange)
            }
            if let error = strengthTracker.saveError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            Button {
                if day.type == "Musculation", !library.completed.contains(day.date),
                   strengthTracker.totalSets(exercises: exercises) >
                   strengthTracker.completedSets(day: day.date, exercises: exercises) {
                    confirmFinish = true
                } else {
                    library.toggleDay(day.date)
                }
            } label: {
                Label(library.completed.contains(day.date) ? "Journée validée" : "Terminer la séance",
                      systemImage: library.completed.contains(day.date) ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(PaceColors.teal)
        }
        .fullScreenCover(isPresented: Binding(
            get: { presentedExerciseID != nil },
            set: { if !$0 { presentedExerciseID = nil } }
        )) {
            if let ex = exercises.first(where: { $0.id == presentedExerciseID }) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text("MOUVEMENT · \(day.day.uppercased())")
                                        .font(.caption2.weight(.bold)).tracking(1.5)
                                        .foregroundStyle(PaceColors.teal)
                                    Text(ex.name)
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("\(ex.sets) séries · \(ex.reps) · Repos \(Int(ex.rest)) s")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            PaceExerciseVisual(figure: PaceMovementGuide.forExercise(ex).figure)
                            VStack(alignment: .leading, spacing: 9) {
                                Text("Séries")
                                    .font(.title2.weight(.bold))
                                Text("Répétitions et charge réelles, puis coche pour valider.")
                                    .font(.caption).foregroundStyle(.secondary)
                                ForEach(1...max(ex.sets, 1), id: \.self) { setNumber in
                                    PaceStrengthSetRow(dayDate: day.date, exercise: ex,
                                                       setNumber: setNumber, focus: $focusedStrengthInput,
                                                       didToggle: { completed in
                                        onStrengthSetChanged(exercise: ex, index: setNumber,
                                                             completed: completed)
                                    })
                                    if setNumber < max(ex.sets, 1) {
                                        Divider().opacity(0.35)
                                    }
                                }
                            }
                            .padding(16)
                            .background(PaceColors.surface, in: RoundedRectangle(cornerRadius: 22))
                            if restExerciseID == ex.id, let end = restEnd {
                                PaceRestCountdown(end: end, seconds: Int(ex.rest),
                                                  afterSet: restSetNumber ?? 0) {
                                    restEnd = nil
                                    restExerciseID = nil
                                    restSetNumber = nil
                                }
                            }
                            DisclosureGroup("Exécution et technique") {
                                PaceExerciseCoaching(exercise: ex).padding(.top, 10)
                            }
                            .tint(PaceColors.teal)
                            DisclosureGroup("Variantes et progression") {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Plus facile : " + ex.easier)
                                    Text("Plus difficile : " + ex.harder)
                                }
                                .font(.subheadline).padding(.top, 8)
                            }
                            .tint(PaceColors.teal)
                        }
                        .padding(20)
                    }
                    .background(PaceColors.base.ignoresSafeArea())
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Fermer", systemImage: "xmark") {
                                focusedStrengthInput = nil
                                presentedExerciseID = nil
                            }
                        }
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Terminé") { focusedStrengthInput = nil }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if expandedExerciseID == nil {
                expandedExerciseID = exercises.first {
                    strengthTracker.completedSets(day: day.date, exercise: $0) < $0.sets
                }?.id
            }
        }
        .onChange(of: exerciseCompletionSignature) { old, new in
            advanceAfterCompletion(from: old, to: new)
        }
        .background {
            Color.clear.contentShape(Rectangle())
                .onTapGesture { focusedStrengthInput = nil }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Terminé") { focusedStrengthInput = nil }
                    .font(.body.weight(.semibold))
                    .tint(PaceColors.teal)
            }
        }
        .confirmationDialog("Toutes les séries ne sont pas cochées.",
                            isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Terminer la séance malgré tout") {
                library.toggleDay(day.date)
            }
            Button("Continuer la séance", role: .cancel) {}
        } message: {
            Text("Tu peux continuer à noter tes séries ou terminer la séance. Les séries déjà enregistrées resteront conservées.")
        }
    }
}

private enum PaceStrengthInput: Hashable {
    case repetitions(String, Int)
    case load(String, Int)
}

/// Dedicated full-width inputs prevent accidental taps on adjacent controls.
/// Local editing state keeps the keyboard focused while the private store saves each keystroke.
private struct PaceStrengthSetRow: View {
    @EnvironmentObject private var tracker: PaceStrengthTracker
    let dayDate: String
    let exercise: PaceExercise
    let setNumber: Int
    let focus: FocusState<PaceStrengthInput?>.Binding
    let didToggle: (Bool) -> Void
    @State private var repetitionsText = ""
    @State private var loadText = ""

    private var entry: PaceStrengthSet {
        tracker.entry(day: dayDate, exerciseID: exercise.id, set: setNumber)
    }
    private var completed: Bool { entry.completed }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(String(format: "%02d", setNumber))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(completed ? PaceColors.teal : .secondary)
                .frame(width: 30)

            inputField(title: exercise.isTimed ? "SECONDES" : "RÉPÉTITIONS",
                       placeholder: exercise.reps,
                       text: $repetitionsText,
                       kind: .repetitions(exercise.id, setNumber),
                       keyboard: .numberPad,
                       accessibility: exercise.isTimed
                           ? "Durée en secondes, série \(setNumber)"
                           : "Répétitions, série \(setNumber)")
            if exercise.tracksLoad {
                inputField(title: "KG",
                           placeholder: "—",
                           text: $loadText,
                           kind: .load(exercise.id, setNumber),
                           keyboard: .decimalPad,
                           accessibility: "Charge en kilogrammes, série \(setNumber)")
            }
            Button {
                focus.wrappedValue = nil
                let next = !completed
                tracker.setCompleted(next, day: dayDate,
                                     exerciseID: exercise.id, set: setNumber)
                didToggle(next)
            } label: {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 29, weight: .light))
                    .foregroundStyle(completed ? PaceColors.teal : .secondary)
                    .frame(width: 44, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Série \(setNumber) : \(completed ? "validée, toucher pour annuler" : "toucher pour valider")")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 5)
        .background(completed ? PaceColors.teal.opacity(0.045) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            repetitionsText = entry.repetitions
            loadText = entry.weightKg
        }
        .onChange(of: repetitionsText) { _, newValue in
            tracker.setRepetitions(newValue, day: dayDate,
                                   exerciseID: exercise.id, set: setNumber)
        }
        .onChange(of: loadText) { _, newValue in
            tracker.setWeight(newValue, day: dayDate,
                              exerciseID: exercise.id, set: setNumber)
        }
    }

    private func inputField(title: String, placeholder: String,
                            text: Binding<String>, kind: PaceStrengthInput,
                            keyboard: UIKeyboardType, accessibility: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: 42)
                .padding(.horizontal, 9)
                .background(PaceColors.base.opacity(0.65),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(focus.wrappedValue == kind ?
                                      PaceColors.teal.opacity(0.75) : .clear, lineWidth: 1.5)
                }
                .focused(focus, equals: kind)
                .accessibilityLabel(accessibility)
                .submitLabel(.done)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
