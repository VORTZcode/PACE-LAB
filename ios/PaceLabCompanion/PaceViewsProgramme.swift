import SwiftUI

/// Show every workout observed on the local calendar day, even after validation.
/// Date coincidence does not prove that a workout fulfilled the planned session.
enum PacePlanActivityMatch {
    static func on(_ date: String, in workouts: [WorkoutPayload],
                   calendar: Calendar = .current) -> [WorkoutPayload] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let plannedDate = formatter.date(from: date) else { return [] }
        return workouts.filter {
            calendar.isDate($0.startDate, inSameDayAs: plannedDate)
        }.sorted { $0.startDate < $1.startDate }
    }

    static func matching(for day: PaceDay, in workouts: [WorkoutPayload]) -> WorkoutPayload? {
        let expected: String
        switch day.type {
        case "Course": expected = "running"
        case "Musculation": expected = "strength"
        case "Récupération": expected = "walking"
        default: return nil
        }
        let candidates = on(day.date,in:workouts).filter { $0.activity_kind == expected }
        // A shared workout category is a hint, not proof of completing the prescription.
        return candidates.count == 1 ? candidates.first : nil
    }
}

struct ProgrammeScreen: View {
    @EnvironmentObject var library: PaceLibrary
    @EnvironmentObject var strengthTracker: PaceStrengthTracker
    @EnvironmentObject var engine: HealthSyncEngine
    @EnvironmentObject var tabs: PaceTabRouter
    @EnvironmentObject var athleteProfile: PaceAthleteProfileStore
    @EnvironmentObject var runLinks: PaceRunWorkoutLinks
    @EnvironmentObject var strengthLinks: PaceStrengthWorkoutLinks

    private var adherence: PaceTrainingAdherenceSnapshot {
        PaceTrainingAdherenceAdapter.snapshot(
            library: library, engine: engine, runLinks: runLinks,
            strengthLinks: strengthLinks)
    }

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
                            Text("\(library.completedCount) réalisées · \(library.missedCount) non réalisées")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                if adherence.plannedTrainingCount > 0 {
                    PaceCard {
                        VStack(alignment: .leading, spacing: 9) {
                            Label("Réalisation des entraînements", systemImage: "checkmark.shield")
                                .font(.subheadline.weight(.semibold))
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(adherence.confirmed)")
                                        .font(.title3.weight(.semibold)).monospacedDigit()
                                    Text("liés à Apple Santé").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(adherence.selfReported)")
                                        .font(.title3.weight(.semibold)).monospacedDigit()
                                    Text("validés manuellement").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(adherence.missed)")
                                        .font(.title3.weight(.semibold)).monospacedDigit()
                                    Text("non réalisés").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if adherence.unconfirmedCandidates > 0 || adherence.ambiguous > 0 {
                                Text("\(adherence.unconfirmedCandidates) activité(s) à associer · \(adherence.ambiguous) jour(s) avec plusieurs activités possibles")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            Text("Une date ou une catégorie sportive identique ne prouve pas que toutes les consignes prévues ont été respectées.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                if let preferred=athleteProfile.profile {
                    let plannedRuns=library.currentPlan.filter { $0.type == "Course" }.count
                    let plannedStrength=library.currentPlan.filter { $0.type == "Musculation" }.count
                    if plannedRuns != preferred.preferredRunsPerWeek ||
                        plannedStrength != preferred.preferredStrengthPerWeek {
                        HStack(spacing:10) {
                            Image(systemName:"calendar.badge.exclamationmark")
                                .foregroundStyle(.orange)
                            VStack(alignment:.leading,spacing:3) {
                                Text("Fréquence différente de ton profil")
                                    .font(.subheadline.weight(.semibold))
                                Text("Plan : \(plannedRuns) courses + \(plannedStrength) muscu · objectif : \(preferred.preferredRunsPerWeek) + \(preferred.preferredStrengthPerWeek)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength:4)
                            Button {
                                tabs.openCoach(.programme)
                            } label: {
                                Image(systemName:"arrow.up.right")
                                    .font(.caption.weight(.semibold))
                            }
                            .accessibilityLabel("Examiner la fréquence avec le coach")
                            .tint(PaceColors.teal)
                        }
                        .padding(14)
                        .modifier(PaceGlassCardSurface(cornerRadius:18))
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

                PaceSectionTitle(title: "Ta semaine")
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
                                    let observed = PacePlanActivityMatch.on(day.date, in: engine.snapshot)
                                    if let recorded = PacePlanActivityMatch.matching(for:day,in:engine.snapshot) {
                                        Label(day.type == "Course"
                                              ? "Course enregistrée · \(PaceFormat.distance(recorded.kilometers,places:2)) km · \(PaceFormat.duration(recorded.duration_seconds))"
                                              : "Activité enregistrée · \(PaceFormat.duration(recorded.duration_seconds))",
                                              systemImage:"applewatch")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(PaceColors.teal)
                                            .fixedSize(horizontal:false,vertical:true)
                                    } else if !observed.isEmpty {
                                        Label("\(observed.count) activité\(observed.count > 1 ? "s" : "") ce jour · à rapprocher du programme",
                                              systemImage:"questionmark.circle")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let missed = library.missedSessions[day.date] {
                                        Label("Non réalisée · \(missed.reason)", systemImage: "minus.circle.fill")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.orange)
                                    }
                                    if day.type == "Musculation" && library.activeCoachDraft == nil &&
                                       library.missedSessions[day.date] == nil {
                                        let exercises = library.programme.force.filter { $0.day == day.day }
                                        Text("\(strengthTracker.completedSets(day: day.date, exercises: exercises)) / \(strengthTracker.totalSets(exercises: exercises)) séries validées")
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(PaceColors.teal)
                                            .monospacedDigit()
                                    }
                                }
                                Spacer(minLength: 4)
                                Image(systemName: library.completed.contains(day.date) ? "checkmark.circle.fill" :
                                      library.missedSessions[day.date] != nil ? "minus.circle.fill" : "chevron.right")
                                    .foregroundStyle(library.completed.contains(day.date) ? PaceColors.teal :
                                                     library.missedSessions[day.date] != nil ? .orange : Color.secondary)
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
            }
        }
        .toolbar {
            ToolbarItem(placement:.topBarTrailing) {
                Button { tabs.openCoach(.programme) } label: { Image(systemName:"brain.head.profile") }
                    .accessibilityLabel("Adapter mon programme avec ChatGPT")
            }
        }
    }
}

struct DayDetailScreen: View {
    @EnvironmentObject var engine: HealthSyncEngine
    @EnvironmentObject var library: PaceLibrary
    @EnvironmentObject var strengthTracker: PaceStrengthTracker
    @EnvironmentObject var strengthLinks: PaceStrengthWorkoutLinks
    @EnvironmentObject var runLinks: PaceRunWorkoutLinks
    let day: PaceDay
    @State private var confirmFinish = false
    @State private var showMissedEditor = false
    @State private var presentedExerciseID: String?
    @State private var exerciseDetailTab = 0
    @State private var restEnd: Date?
    @State private var restExerciseID: String?
    @State private var restSetNumber: Int?
    @FocusState private var focusedStrengthInput: PaceStrengthInput?

    @ViewBuilder
    private func exerciseTabButton(_ title: String, tab: Int) -> some View {
        Button {
            focusedStrengthInput = nil
            withAnimation(.easeInOut(duration: 0.16)) { exerciseDetailTab = tab }
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 37)
                .foregroundStyle(exerciseDetailTab == tab ? .white : .secondary)
                .background(exerciseDetailTab == tab ? PaceColors.teal : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func navigateExercise(from current: PaceExercise, direction: Int) {
        guard let index = exercises.firstIndex(where: { $0.id == current.id }),
              exercises.indices.contains(index + direction) else { return }
        focusedStrengthInput = nil
        exerciseDetailTab = 0
        presentedExerciseID = exercises[index + direction].id
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
    private var dayActivities: [WorkoutPayload] {
        PacePlanActivityMatch.on(day.date, in: engine.snapshot)
    }
    private var matchingActivity: WorkoutPayload? {
        if day.type == "Course",
           let id = runLinks.confirmedWorkoutUUID(for: day.date),
           let match = engine.snapshot.first(where: { $0.source_uuid == id && $0.isRun }) {
            return match
        }
        if day.type == "Musculation",
           let id = strengthLinks.confirmedWorkoutUUID(for: day.date),
           let match = engine.snapshot.first(where: {
               $0.source_uuid == id && $0.activity_kind == "strength"
           }) {
            return match
        }
        return PacePlanActivityMatch.matching(for: day, in: engine.snapshot)
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
            // Before the workout, show the instructions rather than a false
            // warning that Apple Santé has not recorded a future session.
            if !dayActivities.isEmpty || library.completed.contains(day.date) {
            PaceSectionTitle(title: "Activité enregistrée",
                             subtitle: "Apple Santé")
            if dayActivities.isEmpty {
                PaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Journée validée, sans activité Apple Santé",
                              systemImage: "applewatch.slash")
                            .font(.subheadline.weight(.medium))
                        Text("La synchronisation peut être en cours. Cette validation ne crée pas de mesures Apple Watch.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            } else {
                PaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(dayActivities) { activity in
                            NavigationLink {
                                if activity.activity_kind == "strength" {
                                    StrengthWorkoutDetailScreen(workout: activity)
                                } else {
                                    WorkoutDetailScreen(workout: activity)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: activity.symbol)
                                        .foregroundStyle(PaceColors.teal)
                                        .frame(width: 30)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(activity.cadenceLabel)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("\(activity.startDate.formatted(.dateTime.hour().minute())) · \(PaceFormat.duration(activity.duration_seconds))" +
                                             (activity.isRun && activity.kilometers > 0 ?
                                              " · \(PaceFormat.distance(activity.kilometers, places: 2)) km" : ""))
                                            .font(.caption).foregroundStyle(.secondary)
                                        if activity.isRun {
                                            Text("Allure \(PaceFormat.pace(activity.paceMinutes))/km · FC \(PaceFormat.heart(activity.hr_average_bpm)) bpm")
                                                .font(.caption).foregroundStyle(.secondary)
                                        } else if let heart = activity.hr_average_bpm {
                                            Text("FC moyenne \(PaceFormat.heart(heart)) bpm")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        if activity.source_uuid == matchingActivity?.source_uuid {
                                            Text("Type correspondant à la séance prévue")
                                                .font(.caption2).foregroundStyle(PaceColors.teal)
                                        } else {
                                            Text("Activité du jour · association au programme non confirmée")
                                                .font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Ouvrir les mesures réelles de cette activité")
                        }
                    }
                }
            }
            }

            if exercises.isEmpty {
                if library.completed.contains(day.date) || !dayActivities.isEmpty {
                    DisclosureGroup {
                        PaceEffortGuide(day:day)
                            .padding(.top,10)
                    } label: {
                        Label("Revoir les consignes prévues",systemImage:"text.book.closed")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(PaceColors.teal)
                    .padding(.horizontal,4)
                } else {
                    PaceEffortGuide(day:day)
                }
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
                    PaceCard {
                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                focusedStrengthInput = nil
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    exerciseDetailTab = 0
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
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(minHeight: 52)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(ex.name), \(finished) séries validées sur \(ex.sets)")
                            .accessibilityHint("Ouvrir la fiche de l’exercice pour voir le mouvement et enregistrer les séries")


                        }
                    }
                }
            }

            if let found = matchingActivity,
               !library.completed.contains(day.date) ||
                (day.type == "Course" &&
                 runLinks.confirmedWorkoutUUID(for: day.date) != found.source_uuid) ||
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
                            } else if day.type == "Course" {
                                runLinks.confirm(date: day.date, workout: found)
                                if runLinks.confirmedWorkoutUUID(for: day.date) == found.source_uuid {
                                    library.markDayCompleted(day.date)
                                }
                            } else {
                                library.markDayCompleted(day.date)
                            }
                        } label: {
                            Label(day.type == "Course" || day.type == "Musculation"
                                  ? "Associer à ma séance et valider"
                                  : "Oui, valider cette séance", systemImage: "checkmark.circle")
                        }
                        .font(.subheadline.weight(.semibold))
                        .tint(PaceColors.teal)
                    }
                }
            }

            if let error = runLinks.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.orange)
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
            if let missed = library.missedSessions[day.date] {
                PaceCard {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("Séance non réalisée", systemImage: "minus.circle.fill")
                            .font(.headline).foregroundStyle(.orange)
                        Text("Motif : \(missed.reason)")
                            .font(.subheadline)
                        if !missed.note.isEmpty {
                            Text(missed.note).font(.footnote).foregroundStyle(.secondary)
                        }
                        HStack {
                            Button("Modifier le motif") { showMissedEditor = true }
                            Spacer()
                            Button("Remettre en attente") { library.clearMissed(day.date) }
                        }
                        .font(.subheadline)
                        .tint(PaceColors.teal)
                    }
                }
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
            if day.type != "Repos" && day.type != "Récupération" &&
               !library.completed.contains(day.date) && library.missedSessions[day.date] == nil {
                Button {
                    showMissedEditor = true
                } label: {
                    Label("Je n’ai pas pu faire cette séance", systemImage: "calendar.badge.exclamationmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
        .sheet(isPresented: $showMissedEditor) {
            PaceMissedSessionEditor(day: day)
                .environmentObject(library)
        }
        .fullScreenCover(isPresented: Binding(
            get: { presentedExerciseID != nil },
            set: { if !$0 { presentedExerciseID = nil } }
        )) {
            if let ex = exercises.first(where: { $0.id == presentedExerciseID }) {
                NavigationStack {
                    GeometryReader { viewport in
                        let guide = PaceMovementGuide.forExercise(ex)
                        let artworkHeight = max(125, min(ex.sets > 4 ? 155 : 210, viewport.size.height * 0.31))
                        VStack(alignment: .leading, spacing: 11) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(day.day.uppercased() + " · MUSCULATION")
                                        .font(.caption2.weight(.semibold))
                                        .tracking(1.3)
                                        .foregroundStyle(PaceColors.teal)
                                    Text(ex.name)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.86)
                                    Text(guide.focus)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "figure.strengthtraining.functional")
                                    .font(.system(size: 28, weight: .ultraLight))
                                    .foregroundStyle(PaceColors.teal)
                                    .frame(width: 54, height: 54)
                                    .background(PaceColors.teal.opacity(0.09),
                                                in: RoundedRectangle(cornerRadius: 17))
                            }
                            .padding(.top, 4)

                            Group {
                                if exerciseDetailTab == 0 {
                                    PaceExerciseVisual(figure: guide.figure, imageHeight: artworkHeight - 45)
                                        .id(ex.id)
                                } else if exerciseDetailTab == 1 {
                                    VStack(alignment: .leading, spacing: 9) {
                                        ForEach(Array(guide.steps.enumerated()), id: \.offset) { step in
                                            HStack(alignment: .top, spacing: 9) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(PaceColors.teal)
                                                Text(step.element)
                                                    .font(.subheadline)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                    }
                                    .padding(13)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .background(PaceColors.surface,
                                                in: RoundedRectangle(cornerRadius: 18))
                                } else {
                                    VStack(alignment: .leading, spacing: 14) {
                                        Label("Plus facile", systemImage: "arrow.down.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(PaceColors.teal)
                                        Text(ex.easier).font(.subheadline)
                                        Divider().opacity(0.45)
                                        Label("Plus difficile", systemImage: "arrow.up.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(PaceColors.teal)
                                        Text(ex.harder).font(.subheadline)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .background(PaceColors.surface,
                                                in: RoundedRectangle(cornerRadius: 18))
                                }
                            }
                            .frame(height: artworkHeight)

                            HStack(spacing: 3) {
                                exerciseTabButton("Démonstration", tab: 0)
                                exerciseTabButton("Conseils", tab: 1)
                                exerciseTabButton("Variantes", tab: 2)
                            }
                            .padding(4)
                            .background(PaceColors.surface,
                                        in: RoundedRectangle(cornerRadius: 15))

                            HStack(alignment: .firstTextBaseline) {
                                Text("Séries")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                Spacer()
                                Text("\(strengthTracker.completedSets(day: day.date, exercise: ex)) / \(ex.sets) · \(ex.reps)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 3)

                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 1) {
                                    ForEach(1...max(ex.sets, 1), id: \.self) { setNumber in
                                        PaceStrengthSetRow(dayDate: day.date, exercise: ex,
                                                           setNumber: setNumber, focus: $focusedStrengthInput,
                                                           didToggle: { completed in
                                            onStrengthSetChanged(exercise: ex, index: setNumber,
                                                                 completed: completed)
                                        })
                                        .id(ex.id + ":" + String(setNumber))
                                        if setNumber < max(ex.sets, 1) {
                                            Divider().padding(.leading, 32).opacity(0.35)
                                        }
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                            .background(PaceColors.surface,
                                        in: RoundedRectangle(cornerRadius: 17))
                            .frame(maxHeight: .infinity, alignment: .top)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    }
                    .background(PaceColors.base.ignoresSafeArea())
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if focusedStrengthInput == nil {
                        HStack(spacing: 12) {
                            Image(systemName: "timer")
                                .font(.title2)
                                .foregroundStyle(PaceColors.teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("RÉCUPÉRATION")
                                    .font(.caption2.weight(.bold))
                                    .tracking(1.1)
                                    .foregroundStyle(.secondary)
                                if restExerciseID == ex.id, let end = restEnd {
                                    TimelineView(.periodic(from: .now, by: 1)) { context in
                                        let remaining = max(0, Int(ceil(end.timeIntervalSince(context.date))))
                                        Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                                            .font(.system(size: 27, weight: .bold, design: .rounded))
                                            .monospacedDigit()
                                    }
                                } else {
                                    Text(String(format: "%02d:%02d", Int(ex.rest) / 60, Int(ex.rest) % 60))
                                        .font(.system(size: 27, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                }
                            }
                            Spacer()
                            Button {
                                if restExerciseID == ex.id, restEnd != nil {
                                    restEnd = nil
                                    restExerciseID = nil
                                    restSetNumber = nil
                                } else {
                                    restExerciseID = ex.id
                                    restSetNumber = nil
                                    restEnd = Date().addingTimeInterval(max(1, ex.rest))
                                }
                            } label: {
                                Image(systemName: restExerciseID == ex.id && restEnd != nil
                                      ? "stop.fill" : "play.fill")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 54, height: 48)
                                    .background(PaceColors.teal,
                                                in: RoundedRectangle(cornerRadius: 15))
                            }
                            .accessibilityLabel(restExerciseID == ex.id && restEnd != nil
                                                ? "Arrêter le minuteur" : "Démarrer la récupération")
                        }
                        .padding(15)
                        .background(PaceColors.surface,
                                    in: RoundedRectangle(cornerRadius: 22))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Fermer", systemImage: "xmark") {
                                focusedStrengthInput = nil
                                presentedExerciseID = nil
                            }
                        }
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button {
                                navigateExercise(from: ex, direction: -1)
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            .disabled(exercises.first?.id == ex.id)
                            .accessibilityLabel("Exercice précédent")

                            Button {
                                navigateExercise(from: ex, direction: 1)
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .disabled(exercises.last?.id == ex.id)
                            .accessibilityLabel("Exercice suivant")
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background {
            Color.clear.contentShape(Rectangle())
                .onTapGesture { focusedStrengthInput = nil }
        }
        .scrollDismissesKeyboard(.immediately)
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


/// Records an absence honestly; it is not an Apple Health workout or a completed session.
private struct PaceMissedSessionEditor: View {
    @EnvironmentObject private var library: PaceLibrary
    @Environment(\.dismiss) private var dismiss
    let day: PaceDay
    @State private var reason = "Manque de temps"
    @State private var note = ""
    private let reasons = ["Manque de temps", "Fatigue", "Douleur ou gêne", "Maladie", "Imprévu", "Autre"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(day.title).font(.headline)
                    Text(day.date).font(.subheadline).foregroundStyle(.secondary)
                } header: { Text("Séance prévue") }
                Section("Pourquoi n’a-t-elle pas eu lieu ?") {
                    Picker("Motif", selection: $reason) {
                        ForEach(reasons, id: \.self) { item in Text(item).tag(item) }
                    }
                    TextField("Précision facultative", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    Text("Cette séance sera indiquée comme non réalisée, sans être comptée comme terminée. Tu pourras modifier ce motif ou remettre la séance en attente.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Ton motif reste sur cet iPhone ; le partage de tes notes avec l’IA dépend de ton autorisation.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Séance non réalisée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        library.markDayMissed(day.date, reason: reason, note: note)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let saved = library.missedSessions[day.date] {
                    reason = saved.reason
                    note = saved.note
                }
            }
        }
    }
}
