import SwiftUI

/// Progressive disclosure: the rest of the dashboard remains readable even
/// when dozens of strength sets have been logged.
struct PaceStrengthProgressSection: View {
    @EnvironmentObject var tracker: PaceStrengthTracker
    @EnvironmentObject var library: PaceLibrary

    private var history: [PaceStrengthExerciseEvidence] {
        let exercises = Dictionary(library.programme.force.map { ($0.id, $0) },
                                   uniquingKeysWith: { first, _ in first })
        let measured: [PaceMeasuredStrengthSet] = tracker.records.compactMap { key, set in
            guard set.completed, let date = set.completedAt,
                  let value = set.actualRepetitions else { return nil }
            let chunks = key.split(separator: "|", omittingEmptySubsequences: false)
            // Key format is date | programme weekday | exercise name | set index.
            guard chunks.count == 4,
                  let exercise = exercises[String(chunks[1]) + "|" + String(chunks[2])]
            else { return nil }
            return PaceMeasuredStrengthSet(
                name: exercise.name, completedAt: date, isTimed: exercise.isTimed,
                countOrSeconds: value,
                weightKg: exercise.tracksLoad ? set.actualWeightKg : nil)
        }
        return PaceStrengthEvidence.summarize(measured)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaceSectionTitle(title: "Musculation", subtitle: "Séries réellement enregistrées")
            if history.isEmpty {
                PaceCard {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("Pas encore de séries comparables", systemImage: "dumbbell")
                            .font(.subheadline.weight(.semibold))
                        Text("Le suivi apparaîtra après l'enregistrement de séries avec durée ou répétitions. Les exercices d'un programme externe ne sont pas reconstruits automatiquement.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } else {
                PaceCard {
                    VStack(alignment: .leading, spacing: 13) {
                        ForEach(history.prefix(5)) { item in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(item.name).font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(item.completedSets) séries")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                HStack(spacing: 12) {
                                    if let duration = item.maxDurationSeconds {
                                        Text("Jusqu'à \(duration) s")
                                    }
                                    if let reps = item.maxRepetitions {
                                        Text("Jusqu'à \(reps) répétitions")
                                    }
                                    if let kg = item.maxWeightKg {
                                        Text("Charge max \(String(format:"%.1f",kg)) kg")
                                    }
                                }
                                .font(.caption).foregroundStyle(PaceColors.teal)
                                Text("\(item.sessions) jours enregistrés · dernière série le \(item.lastDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            if item.id != history.prefix(5).last?.id { Divider() }
                        }
                        Text("Charges et répétitions déclarées manuellement. Une hausse de charge ou de volume ne prouve pas, à elle seule, une prise de muscle.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
