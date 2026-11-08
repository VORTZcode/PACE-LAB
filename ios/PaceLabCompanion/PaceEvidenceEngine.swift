import Foundation

/// Descriptive baseline from HealthKit. No fictional thresholds or diagnosed "readiness" score.
struct PaceTrainingEvidence {
    let runCount28Days: Int
    let distance28Days: Double
    let minutes28Days: Double
    let longestRun28Days: Double
    let completeWeeks: [Double]
    let baselineWeeklyKm: Double?
    let currentSevenDaysKm: Double
    let dataQuality: String
    let analysis: String

    var promptContext: String {
        let week = baselineWeeklyKm.map {
            PaceFormat.distance($0,places:2) + " km"
        } ?? "non fiable"
        return [
            "BASELINE OBSERVÉE (Apple Santé ; aucune estimation de VO2max, de seuil lactique ou de score de forme).",
            "28 derniers jours : \(runCount28Days) courses, \(PaceFormat.distance(distance28Days,places:2)) km, \(Int(minutes28Days)) min.",
            "Sortie la plus longue : \(PaceFormat.distance(longestRun28Days,places:2)) km.",
            "4 semaines de 7 jours : \(completeWeeks.enumerated().map { "S\($0.offset + 1)=\(PaceFormat.distance($0.element,places:1))km" }.joined(separator:" ; ")).",
            "Moyenne hebdomadaire observée : \(week).",
            "7 derniers jours : \(PaceFormat.distance(currentSevenDaysKm,places:2)) km.",
            "Qualité de référence : \(dataQuality).",
            "Décision fondée sur : \(analysis)"
        ].joined(separator:"\n")
    }
}

enum PaceEvidenceEngine {
    static let sources: [(title:String,url:String)] = [
        ("ACC 2026 — prescription individualisée FITT","https://www.jacc.org/doi/10.1016/j.jacc.2026.09.008"),
        ("Oliveira et al. 2024 — distribution de l’intensité","https://pubmed.ncbi.nlm.nih.gov/38717713/"),
        ("Meta-analyse 2025 — musculation et masse maigre","https://pubmed.ncbi.nlm.nih.gov/40909191/"),
        ("Étude cohorte 2025 — augmentation ponctuelle des distances","https://pubmed.ncbi.nlm.nih.gov/40623829/"),
        ("Revue 2022 — pas de règle universelle des 10 %","https://pmc.ncbi.nlm.nih.gov/articles/PMC9528699/")
    ]

    static func evaluate(_ runs:[WorkoutPayload],now:Date = .now) -> PaceTrainingEvidence {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for:now)
        let lower = calendar.date(byAdding:.day,value:-28,to:now) ?? .distantPast
        let recent = runs.filter { $0.startDate >= lower && $0.startDate <= now && $0.kilometers > 0 }
        let total = recent.reduce(0.0) { $0 + $1.kilometers }
        let duration = recent.reduce(0.0) { $0 + $1.duration_seconds/60 }
        let longest = recent.map(\.kilometers).max() ?? 0
        let weeks = (0..<4).map { index -> Double in
            let start = calendar.date(byAdding:.day,value:-(index + 1)*7,to:today) ?? .distantPast
            let end = calendar.date(byAdding:.day,value:-index*7,to:today) ?? now
            return runs.filter { $0.startDate >= start && $0.startDate < end }
                .reduce(0.0) { $0 + max(0,$1.kilometers) }
        }
        let average = recent.count >= 4 ? weeks.reduce(0,+)/4 : nil
        let weekStart = calendar.date(byAdding:.day,value:-7,to:now) ?? .distantPast
        let last7 = runs.filter { $0.startDate >= weekStart && $0.startDate <= now }
            .reduce(0.0) { $0 + max(0,$1.kilometers) }
        let quality: String
        let interpretation: String
        if recent.count < 4 {
            quality = "Insuffisante"
            interpretation = "Moins de quatre courses sur 28 jours : conserver une charge modeste, demander le ressenti, ne pas estimer une progression individuelle fiable."
        } else if weeks.filter({ $0 > 0 }).count < 3 {
            quality = "Partielle"
            interpretation = "Historique irrégulier : les moyennes de semaines ne sont pas une capacité garantie. Ne pas extrapoler une cible agressive."
        } else {
            quality = "Descriptive sur 28 jours"
            interpretation = "Comparer volumes et fréquences ; demander symptômes, douleur, sommeil, facilité perçue et terrain avant tout ajustement d'intensité."
        }
        return .init(runCount28Days:recent.count,distance28Days:total,minutes28Days:duration,
                     longestRun28Days:longest,completeWeeks:weeks,baselineWeeklyKm:average,
                     currentSevenDaysKm:last7,dataQuality:quality,analysis:interpretation)
    }

    private static func nutritionClaim(_ text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern,
                                                       options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text,
                  range: NSRange(text.startIndex..<text.endIndex, in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        let digits = String(text[range]).filter(\.isNumber)
        return Int(digits)
    }

    /// Safety gate, not a validated universal training rule; protects against unexplained jumps.
    static func review(plan:PaceAICoachDraft,baseline:PaceTrainingEvidence,
                       profile:PaceAthleteProfile? = nil,
                       observedStrengthLast7:Int? = nil) -> [String] {
        var concerns:[String] = []
        let computedKcal = plan.meals.reduce(0) { $0 + $1.kcal }
        let computedProtein = plan.meals.reduce(0) { $0 + $1.protein }
        let proposedNotes = plan.evidenceNotes ?? []
        // The model must not be its own arithmetic checker. Compare explicit
        // weekly nutrition claims with the actual 14 recipe entries.
        for note in proposedNotes where note.lowercased().contains("kcal") {
            if let weekly = nutritionClaim(note, pattern:
                #"(?:repas.{0,65}(?:environ|total|représentent)\s+)([0-9][0-9\s]{3,})\s*kcal"#),
               abs(weekly - computedKcal) > 50 {
                concerns.append("Calcul nutritionnel contradictoire : le bilan annonce \(weekly) kcal pour la semaine, mais les 14 repas totalisent \(computedKcal) kcal.")
            }
            if let daily = nutritionClaim(note, pattern:
                #"(?:soit|moyenne(?:\s+de)?|environ)\s+([0-9][0-9\s]{2,})\s*kcal\s+par\s+jour"#),
               abs(daily - Int((Double(computedKcal) / 7.0).rounded())) > 10 {
                concerns.append("Moyenne calorique contradictoire : \(daily) kcal/j annoncées contre \(Int((Double(computedKcal) / 7.0).rounded())) kcal/j calculées.")
            }
        }
        if computedProtein == 0 { concerns.append("Aucun apport protéique indiqué dans les repas.") }
        let runs = plan.training.filter { $0.type == "Course" }
        if runs.isEmpty { concerns.append("Aucune course planifiée malgré l’objectif de course.") }
        if let profile {
            if runs.count > profile.preferredRunsPerWeek {
                concerns.append("Le nombre de courses dépasse la fréquence confirmée : aucune séance supplémentaire ne doit être imposée.")
            }
            let strengthCount = plan.training.filter { $0.type == "Musculation" }.count
            if strengthCount > profile.preferredStrengthPerWeek {
                concerns.append("Le nombre de musculation dépasse la fréquence confirmée.")
            }
            if profile.preferredStrengthPerWeek > 0 && strengthCount == 0 {
                concerns.append("Le programme a supprimé tout le renforcement malgré l'objectif de préserver le muscle.")
            }
            if runs.count < profile.preferredRunsPerWeek ||
               strengthCount < profile.preferredStrengthPerWeek {
                if (plan.adjustmentRationale ?? "").trimmingCharacters(in:.whitespacesAndNewlines).count < 55 {
                    concerns.append("Une réduction des fréquences souhaitées doit être expliquée précisément avant adoption.")
                }
            }
        }
        if runs.contains(where:{ $0.plannedDistanceKm == nil || ($0.plannedDistanceKm ?? 0) <= 0 }) {
            concerns.append("Distance prévisionnelle absente : impossible de comparer le plan à la charge réelle.")
        }
        if runs.contains(where:{ $0.effortCategory == nil }) {
            concerns.append("Intensité prévue absente : impossible d’évaluer la répartition des efforts.")
        }
        // A distance labelled as total walking + running is not a running-distance
        // target. A reviewer cannot compare it with Apple Health running mileage.
        if runs.contains(where: { day in
            let wording = day.instructions.lowercased()
            return wording.contains("marche comprise") ||
                   wording.contains("marche incluse") ||
                   wording.contains("distance de l’ensemble") ||
                   wording.contains("distance totale, marche")
        }) {
            concerns.append("Au moins une distance de course inclut la marche : séparer les kilomètres réellement courus de la marche avant toute comparaison.")
        }
        if let observedStrengthLast7, observedStrengthLast7 >= 0 {
            let proposed = plan.training.filter { $0.type == "Musculation" }.count
            if proposed > observedStrengthLast7 && observedStrengthLast7 > 0 &&
                (plan.adjustmentRationale ?? "").lowercased().contains("conserver les") {
                concerns.append("Le bilan annonce une fréquence de musculation conservée alors que le nombre de séances proposées dépasse celui réellement effectué.")
            }
        }
        let values = runs.compactMap(\.plannedDistanceKm)
        if let biggest = values.max(),baseline.longestRun28Days > 0,
           biggest > baseline.longestRun28Days * 1.10 {
            concerns.append("La plus longue sortie proposée dépasse de plus de 10 % la plus longue sortie enregistrée sur 28 jours. Seuil prudent de revue inspiré d’une étude de cohorte, pas une règle individuelle validée.")
        }
        let total = values.reduce(0,+)
        // The 28-day average can be artificially low after illness or a return
        // to training. Compare with both the medium-term average and last 7 days.
        // The 35% and 10% values are review triggers, not injury-risk laws.
        if let weekly = baseline.baselineWeeklyKm, weekly > 1 {
            let recent = baseline.currentSevenDaysKm
            let upperReference = max(weekly, recent)
            if total > weekly * 1.35 && total > upperReference * 1.10 {
                concerns.append("Le volume proposé dépasse à la fois la moyenne de 28 jours et le volume couru ces 7 derniers jours. Réexaminer la progression.")
            }
        }
        let sorted = plan.training.sorted { $0.date < $1.date }
        for pair in zip(sorted,sorted.dropFirst()) {
            if pair.0.effortCategory == "intense" && pair.1.effortCategory == "intense" {
                concerns.append("Deux séances intenses consécutives sont proposées.")
                break
            }
        }
        let intenseCount = runs.filter { $0.effortCategory == "intense" }.count
        if intenseCount > 1 && runs.count <= 3 {
            concerns.append("Une semaine de trois courses ou moins ne doit pas concentrer plusieurs séances très intenses.")
        } else if intenseCount > 1 && baseline.runCount28Days < 12 {
            concerns.append("Plus d’une séance de course intense proposée avec un historique récent limité.")
        }
        if baseline.dataQuality == "Insuffisante" && intenseCount > 0 {
            concerns.append("Historique insuffisant pour justifier une séance intense sans évaluation préalable.")
        }
        return concerns
    }
}
