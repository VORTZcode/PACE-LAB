import SwiftUI

struct ProgrammeScreen: View {
    @EnvironmentObject var library: PaceLibrary
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
    let day: PaceDay
    @State private var showVariants = false

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
                PaceSectionTitle(title: "Exercices", subtitle: "\(exercises.count) mouvements")
                ForEach(exercises) { ex in
                    PaceCard {
                        VStack(alignment: .leading, spacing: 11) {
                            Text(ex.name).font(.headline)
                            HStack(spacing: 9) {
                                PacePill(label: "\(ex.sets) séries", symbol: "repeat")
                                PacePill(label: ex.reps + " reps", symbol: "number")
                            }
                            Text(ex.tips).font(.subheadline).foregroundStyle(.secondary)
                            DisclosureGroup("Variantes & progression") {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Plus facile : " + ex.easier)
                                    Text("Plus difficile : " + ex.harder)
                                }
                                .font(.subheadline).foregroundStyle(.secondary).padding(.top, 8)
                            }
                            .tint(PaceColors.teal)
                            .font(.subheadline.weight(.medium))
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

            Button {
                library.toggleDay(day.date)
            } label: {
                Label(library.completed.contains(day.date) ? "Journée validée" : "Marquer comme terminé",
                      systemImage: library.completed.contains(day.date) ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(PaceColors.teal)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
