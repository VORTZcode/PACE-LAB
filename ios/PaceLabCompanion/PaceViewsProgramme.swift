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
                                    if day.type == "Musculation" && library.missedSessions[day.date] == nil {
                                        let exercises = library.activeCoachDraft?.training
                                            .first(where: { $0.date == day.date && $0.type == "Musculation" })
                                            .map { PaceDraftStrengthExtractor.extract(from: $0.instructions, weekday: day.day) }
                                            ?? library.programme.force.filter { $0.day == day.day }
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

// Read-only bridge for legacy AI plans that store strength sets as prose.
// Never infer a load: only the prescribed numerical rep/time targets are extracted.
// Keeping dated exercise IDs avoids mixing sessions from different weeks.
private enum PaceDraftStrengthExtractor {
    static func extract(from instructions: String, weekday: String) -> [PaceExercise] {
        guard let bodyRange = instructions.range(of: "Corps de séance", options: .caseInsensitive) else { return [] }
        let remainder = String(instructions[bodyRange.upperBound...])
        let bodyStart = remainder.firstIndex(of: ":").map { remainder.index(after: $0) } ?? remainder.startIndex
        let body = String(remainder[bodyStart...])
        let exercisePart = body.components(separatedBy: "Repos ").first ?? body
        let pattern = #"^(.+?)\s+(\d+)\s*[×x]\s*(\d+)(?:\s*[-à]\s*(\d+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return exercisePart.split(separator: ";").compactMap { raw -> PaceExercise? in
            let item = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            let range = NSRange(item.startIndex..<item.endIndex, in: item)
            guard let match = regex.firstMatch(in: item, range: range),
                  let nameRange = Range(match.range(at: 1), in: item),
                  let countRange = Range(match.range(at: 2), in: item),
                  let repsRange = Range(match.range(at: 3), in: item),
                  let sets = Int(item[countRange]), let reps = Int(item[repsRange]),
                  (1...8).contains(sets), (1...120).contains(reps) else { return nil }
            let name = String(item[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.count >= 3 else { return nil }
            let tail = String(item[Range(match.range, in: item)!.upperBound...]).lowercased()
            let isTimed = tail.contains("second") || tail.contains(" sec")
            let weight = tail.contains("kg")
            let loadExpected = weight || name.lowercased().contains("haltère")
            return PaceExercise(day: weekday, block: "Programme coach", name: name, sets: sets,
                reps: isTimed ? "\(reps) s" : String(reps),
                tempo: isTimed ? "Isométrique" : "Contrôlé",
                rest: 75, rir: 3, tips: item, easier: "Réduire l'amplitude ou la charge si nécessaire.",
                harder: "Conserver l'exécution et progresser seulement après récupération.",
                measurement_unit: isTimed ? "seconds" : "repetitions", load_expected: loadExpected)
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
    private var exercises: [PaceExercise] {
        if let approved = library.activeCoachDraft,
           let strengthDay = approved.training.first(where: { $0.date == day.date && $0.type == "Musculation" }) {
            return PaceDraftStrengthExtractor.extract(from: strengthDay.instructions, weekday: day.day)
        }
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
                                presentedExerciseID = ex.id
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
                PaceStrengthFlowScreen(
                    dayDate: day.date, exercise: ex,
                    onClose: { presentedExerciseID = nil },
                    onNext: {
                        if let index = exercises.firstIndex(where: { $0.id == ex.id }),
                           exercises.indices.contains(index + 1) {
                            presentedExerciseID = exercises[index + 1].id
                        } else {
                            presentedExerciseID = nil
                        }
                    }
                )
                .environmentObject(strengthTracker)
                .id(ex.id)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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


// A focused, one-set-at-a-time editor. Existing per-set persistence is untouched.
private struct PaceStrengthFlowScreen: View {
    @EnvironmentObject private var tracker: PaceStrengthTracker
    let dayDate: String
    let exercise: PaceExercise
    let onClose: () -> Void
    let onNext: () -> Void

    @State private var activeSet = 1
    @State private var reps = ""
    @State private var kilograms = ""
    @State private var showingGuide = false
    @State private var resting = false
    @State private var restDeadline: Date?
    @State private var pausedSeconds: TimeInterval?
    @State private var completedExercise = false
    @FocusState private var field: StrengthField?
    private enum StrengthField: Hashable { case repetitions, kilograms }

    private var numberOfSets: Int { max(1, exercise.sets) }
    private var current: PaceStrengthSet {
        tracker.entry(day: dayDate, exerciseID: exercise.id, set: activeSet)
    }
    private var validReps: Bool {
        guard let value = Int(reps), value > 0 else { return false }
        return value <= 999
    }
    private var validLoad: Bool {
        guard exercise.tracksLoad else { return true }
        guard !kilograms.isEmpty else { return true } // Bodyweight / unknown load is allowed.
        guard let value = Double(kilograms.replacingOccurrences(of: ",", with: ".")) else { return false }
        return value >= 0 && value.isFinite
    }
    private var isCurrentCompleted: Bool { current.completed }

    var body: some View {
        NavigationStack {
            Group {
                if resting {
                    recoveryScreen
                } else if completedExercise {
                    doneScreen
                } else {
                    editorScreen
                }
            }
            .background(PaceColors.base.ignoresSafeArea())
            .navigationTitle("Musculation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer", systemImage: "xmark") { field = nil; onClose() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Conseils", systemImage: "info.circle") { field = nil; showingGuide = true }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Terminé") { field = nil }
                }
            }
            .sheet(isPresented: $showingGuide) { guideSheet }
            .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { date in
                if resting, let deadline = restDeadline, date >= deadline {
                    advanceAfterRest()
                }
            }
            .onAppear { chooseFirstUnfinished() }
        }
    }

    private var editorScreen: some View {
        VStack(spacing: 18) {
            VStack(spacing: 7) {
                Text(exercise.name)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)
                Text("Série \(activeSet) sur \(numberOfSets)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(1...numberOfSets, id: \.self) { number in
                        Button {
                            field = nil
                            activeSet = number
                            loadSet(number)
                        } label: {
                            Image(systemName: tracker.entry(day: dayDate, exerciseID: exercise.id, set: number).completed
                                  ? "checkmark.circle.fill" : "\(number).circle.fill")
                                .font(.system(size: 29))
                                .foregroundStyle(number == activeSet ? PaceColors.teal :
                                    tracker.entry(day: dayDate, exerciseID: exercise.id, set: number).completed ? .green : .secondary)
                                .frame(minWidth: 45, minHeight: 45)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Série \(number)")
                    }
                }
            }
            if field == nil {
                PaceExerciseVisual(figure: PaceMovementGuide.forExercise(exercise).figure,
                                   imageHeight: 145)
                    .frame(height: 177)
                    .clipShape(RoundedRectangle(cornerRadius: 19))
                    .overlay(alignment: .bottomTrailing) {
                        Button { showingGuide = true } label: {
                            Label("Voir les conseils", systemImage: "info.circle.fill")
                                .font(.caption.weight(.medium))
                                .padding(10)
                                .background(.regularMaterial, in: Capsule())
                        }
                        .padding(9)
                    }
            }

            HStack(spacing: 12) {
                metricField(title: exercise.isTimed ? "Secondes" : "Répétitions",
                            value: $reps, focus: .repetitions, keyboard: .numberPad, unit: nil)
                if exercise.tracksLoad {
                    metricField(title: "Charge", value: $kilograms,
                                focus: .kilograms, keyboard: .decimalPad, unit: "kg")
                }
            }
            if !validReps {
                Text(exercise.isTimed ? "Indique la durée réalisée en secondes." : "Indique les répétitions réellement effectuées.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if isCurrentCompleted {
                Text("Série déjà validée · tu peux modifier ses valeurs.")
                    .font(.footnote).foregroundStyle(PaceColors.teal)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .safeAreaInset(edge: .bottom) {
            Button(action: saveAndAdvance) {
                Label(isCurrentCompleted ? "Enregistrer les modifications" : "Valider la série",
                      systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent).tint(PaceColors.teal)
            .disabled(!validReps || !validLoad)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(PaceColors.base)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func metricField(title: String, value: Binding<String>,
                             focus: StrengthField, keyboard: UIKeyboardType, unit: String?) -> some View {
        VStack(spacing: 12) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                TextField("—", text: value)
                    .keyboardType(keyboard)
                    .font(.system(size: 43, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .focused($field, equals: focus)
                    .accessibilityLabel(title)
                if let unit {
                    Text(unit).font(.headline).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 66)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(PaceColors.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(field == focus ? PaceColors.teal : .clear, lineWidth: 2)
        }
    }

    private var recoveryScreen: some View {
        VStack(spacing: 26) {
            Spacer()
            Text("Récupération").font(.title.bold())
            TimelineView(.periodic(from: .now, by: 0.5)) { time in
                let remaining = max(0, pausedSeconds ?? restDeadline?.timeIntervalSince(time.date) ?? 0)
                let fraction = min(1, remaining / max(1, exercise.rest))
                ZStack {
                    Circle().stroke(PaceColors.teal.opacity(0.13), lineWidth: 17)
                    Circle().trim(from: 0, to: fraction)
                        .stroke(PaceColors.teal, style: StrokeStyle(lineWidth: 17, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 8) {
                        Text(String(format: "%d:%02d", Int(ceil(remaining)) / 60,
                                    Int(ceil(remaining)) % 60))
                            .font(.system(size: 66, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("Avant la série \(min(activeSet + 1, numberOfSets))")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 264, height: 264)
            }
            HStack(spacing: 12) {
                Button("+ 30 s") {
                    if let deadline = restDeadline { restDeadline = deadline.addingTimeInterval(30) }
                    else { pausedSeconds = (pausedSeconds ?? 0) + 30 }
                }
                .buttonStyle(.bordered)
                Button {
                    if let deadline = restDeadline {
                        pausedSeconds = max(0, deadline.timeIntervalSinceNow)
                        restDeadline = nil
                    } else {
                        restDeadline = Date().addingTimeInterval(pausedSeconds ?? exercise.rest)
                        pausedSeconds = nil
                    }
                } label: {
                    Label(restDeadline == nil ? "Reprendre" : "Pause",
                          systemImage: restDeadline == nil ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.borderedProminent).tint(PaceColors.teal)
                Button("Passer") { advanceAfterRest() }
                    .buttonStyle(.bordered)
            }
            Spacer()
            Text("Série suivante · \(exercise.name)")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 10)
        }
        .padding(24)
    }

    private var doneScreen: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 78)).foregroundStyle(PaceColors.teal)
            Text("Exercice terminé").font(.largeTitle.bold())
            Text("\(numberOfSets) séries prévues · \(exercise.name)")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
            Button("Revoir les séries") {
                activeSet = numberOfSets
                loadSet(activeSet)
                completedExercise = false
            }
            .buttonStyle(.bordered)
            Button(action: onNext) {
                Label("Exercice suivant ou terminer", systemImage: "arrow.right")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent).tint(PaceColors.teal)
        }
        .padding(24)
    }

    private var guideSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PaceExerciseVisual(figure: PaceMovementGuide.forExercise(exercise).figure,
                                       imageHeight: 220)
                    Text(PaceMovementGuide.forExercise(exercise).focus)
                        .font(.headline)
                    ForEach(Array(PaceMovementGuide.forExercise(exercise).steps.enumerated()),
                            id: \.offset) { item in
                        Label(item.element, systemImage: "checkmark.circle")
                    }
                    Text("Variante facile : \(exercise.easier)")
                    Text("Variante difficile : \(exercise.harder)")
                }
                .padding()
            }
            .navigationTitle("Conseils")
            .toolbar { Button("Fermer") { showingGuide = false } }
        }
    }

    private func chooseFirstUnfinished() {
        let next = (1...numberOfSets).first {
            !tracker.entry(day: dayDate, exerciseID: exercise.id, set: $0).completed
        }
        activeSet = next ?? numberOfSets
        completedExercise = next == nil
        loadSet(activeSet)
    }

    private func loadSet(_ index: Int) {
        let stored = tracker.entry(day: dayDate, exerciseID: exercise.id, set: index)
        let preceding = index > 1 ? tracker.entry(day: dayDate, exerciseID: exercise.id, set: index - 1) : PaceStrengthSet()
        reps = stored.repetitions.isEmpty ? preceding.repetitions : stored.repetitions
        kilograms = stored.weightKg.isEmpty ? preceding.weightKg : stored.weightKg
    }

    private func saveAndAdvance() {
        guard validReps && validLoad else { return }
        field = nil
        tracker.setRepetitions(reps, day: dayDate, exerciseID: exercise.id, set: activeSet)
        if exercise.tracksLoad {
            tracker.setWeight(kilograms, day: dayDate, exerciseID: exercise.id, set: activeSet)
        }
        if current.completed {
            // An already completed set is edited without starting recovery again.
            chooseFirstUnfinished()
            return
        }
        tracker.setCompleted(true, day: dayDate, exerciseID: exercise.id, set: activeSet)
        if activeSet < numberOfSets {
            resting = true
            restDeadline = Date().addingTimeInterval(max(0, exercise.rest))
            pausedSeconds = nil
            if exercise.rest <= 0 { advanceAfterRest() }
        } else {
            completedExercise = true
        }
    }

    private func advanceAfterRest() {
        resting = false
        restDeadline = nil
        pausedSeconds = nil
        activeSet = min(numberOfSets, activeSet + 1)
        loadSet(activeSet)
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
