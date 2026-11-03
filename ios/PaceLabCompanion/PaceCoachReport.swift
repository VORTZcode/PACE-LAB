import Foundation

struct PaceCoachSessionReport: Codable, Identifiable {
    let workoutID: String
    let createdAt: Date
    let title: String
    let summary: String
    let observations: [String]
    let recommendations: [String]
    let uncertainties: [String]
    let trainingImpact: String
    var id: String { workoutID }

    static func extract(_ response:String,workoutID:String) throws -> PaceCoachSessionReport {
        guard let from = response.firstIndex(of:"{"),let to = response.lastIndex(of:"}"),
              from <= to,let data = String(response[from...to]).data(using:.utf8),
              let parsed = try? JSONDecoder().decode(Response.self,from:data) else {
            throw PaceChatError.invalid("Le bilan ChatGPT n’a pas de format exploitable.")
        }
        // Reject missing information rather than inventing sports measurements.
        // Return the exact missing sections so the coach can repair its answer
        // automatically once and the user can understand a persistent failure.
        var missing: [String] = []
        if parsed.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
            missing.append("titre")
        }
        if parsed.summary.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ||
            parsed.summary.count >= 1600 {
            missing.append("synthèse exploitable")
        }
        if !(1...6).contains(parsed.observations.count) ||
            parsed.observations.contains(where:{
                $0.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
            }) {
            missing.append("observations étayées (1 à 6)")
        }
        if !(1...5).contains(parsed.recommendations.count) ||
            parsed.recommendations.contains(where:{
                $0.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
            }) {
            missing.append("recommandations concrètes (1 à 5)")
        }
        if !(1...5).contains(parsed.uncertainties.count) ||
            parsed.uncertainties.contains(where:{
                $0.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
            }) {
            missing.append("limites ou données inconnues (1 à 5)")
        }
        if parsed.trainingImpact.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
            missing.append("conséquence justifiée pour le programme")
        }
        guard missing.isEmpty else {
            throw PaceChatError.invalid("Bilan incomplet : " + missing.joined(separator:", ") +
                ". Aucune modification du programme n'a été appliquée.")
        }
        return .init(workoutID:workoutID,createdAt:.now,title:parsed.title,
            summary:parsed.summary,observations:parsed.observations,
            recommendations:parsed.recommendations,uncertainties:parsed.uncertainties,
            trainingImpact:parsed.trainingImpact)
    }
    private struct Response: Decodable {
        let title:String
        let summary:String
        let observations:[String]
        let recommendations:[String]
        let uncertainties:[String]
        let trainingImpact:String
    }
}
