import SwiftUI

struct ProgrammeScreen: View {
    @EnvironmentObject var library: PaceLibrary
    @EnvironmentObject var strengthTracker: PaceStrengthTracker
    @State private var showCoach = false

    var body: some View {
        NavigationStack {
            PaceScreen(title: "Programme") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CYCLE 01 · FONDATIONS")
                        .font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(PaceColors.teal)
                    Text(library.activeCoachDraft == nil ? "Semaine 1" : "Programme coach")
                        .font(.title2.weight(.semibold))
                    Text(library.activeCoachDraft == nil
                    ? "Du 2 au 8 novembre 2026 · Course, renforcement et récupération."
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

                PaceSectionTitle(title: "Votre semaine")
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
                                    Text(day.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
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
                            .background(PaceColors.surface, in: RoundedRectangle(cornerRadius: 19))
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
    let day: PaceDay
    @State private var showVariants = false
    @State private var confirmFinish = false
    @State private var expandedExerciseID: String?
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
        return engine.snapshot.first {
            $0.activity_kind == expected && Calendar.current.isDate($0.startDate, inSameDayAs: date)
        }
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
            PaceSectionTitle(title: "Consignes")
            PaceCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(day.instructions).font(.body)
                    Text(day.intensity).font(.subheadline.weight(.medium)).foregroundStyle(PaceColors.teal)
                }
            }

            if !exercises.isEmpty {
                let done = strengthTracker.completedSets(day: day.date, exercises: exercises)
                let total = strengthTracker.totalSets(exercises: exercises)
                PaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Progression de la séance")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(done) / \(total) séries")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(PaceColors.teal)
                        }
                        ProgressView(value: Double(done), total: Double(max(total, 1)))
                            .tint(PaceColors.teal)
                        Text("Coche chaque série juste après l'avoir réalisée. Les répétitions et la charge sont facultatives ; tes saisies sont enregistrées sur l'iPhone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                                    expandedExerciseID = expanded ? nil : ex.id
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

                            if expanded {
                                Divider().padding(.vertical, 15)
                                HStack(spacing: 8) {
                                    PacePill(label: ex.isTimed ? "Temps" : "Répétitions",
                                             symbol: ex.isTimed ? "timer" : "number")
                                    PacePill(label: "Repos \(Int(ex.rest)) s", symbol: "clock")
                                }
                                .padding(.bottom, 12)
                                Text(ex.tips)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.bottom, 13)
                                ForEach(1...max(ex.sets, 1), id: \.self) { setNumber in
                                    PaceStrengthSetRow(dayDate: day.date, exercise: ex,
                                                       setNumber: setNumber, focus: $focusedStrengthInput)
                                        .padding(.bottom, 9)
                                }
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

            if let found = matchingActivity, !library.completed.contains(day.date) {
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
                            library.toggleDay(day.date)
                        } label: {
                            Label("Oui, valider cette séance", systemImage: "checkmark.circle")
                        }
                        .font(.subheadline.weight(.semibold))
                        .tint(PaceColors.teal)
                    }
                }
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
    @State private var repetitionsText = ""
    @State private var loadText = ""

    private var entry: PaceStrengthSet {
        tracker.entry(day: dayDate, exerciseID: exercise.id, set: setNumber)
    }
    private var completed: Bool { entry.completed }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Série \(setNumber)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    if completed {
                        Text("Enregistrée")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(PaceColors.teal)
                    }
                }
                Spacer(minLength: 10)
                Button {
                    focus.wrappedValue = nil
                    tracker.setCompleted(!completed, day: dayDate,
                                         exerciseID: exercise.id, set: setNumber)
                } label: {
                    Label(completed ? "Validée" : "Valider",
                          systemImage: completed ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(PaceColors.teal)
                .accessibilityLabel("Série \(setNumber) : \(completed ? "validée, toucher pour annuler" : "toucher pour valider")")
            }

            HStack(alignment: .top, spacing: 12) {
                inputField(title: exercise.metricLabel,
                           placeholder: exercise.reps,
                           text: $repetitionsText,
                           kind: .repetitions(exercise.id, setNumber),
                           keyboard: .numberPad,
                           accessibility: exercise.isTimed
                               ? "Durée réalisée en secondes, série \(setNumber)"
                               : "Répétitions réalisées, série \(setNumber)")
                if exercise.tracksLoad {
                    inputField(title: "Charge (kg)",
                               placeholder: "—",
                               text: $loadText,
                               kind: .load(exercise.id, setNumber),
                               keyboard: .decimalPad,
                               accessibility: "Charge utilisée en kilogrammes, série \(setNumber)")
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(completed ? PaceColors.teal.opacity(0.08) : PaceColors.base.opacity(0.7),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(completed ? PaceColors.teal.opacity(0.22) : PaceColors.teal.opacity(0.07),
                              lineWidth: 1)
        }
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
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 12)
                .background(PaceColors.surface,
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
