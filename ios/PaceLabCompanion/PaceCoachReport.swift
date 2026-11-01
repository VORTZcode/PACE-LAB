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
        guard !parsed.title.isEmpty,!parsed.summary.isEmpty,
              parsed.summary.count < 1600,
              (1...6).contains(parsed.observations.count),
              (1...5).contains(parsed.recommendations.count),
              (1...5).contains(parsed.uncertainties.count),
              !parsed.trainingImpact.isEmpty else {
            throw PaceChatError.invalid("Le bilan proposé manque de précautions ou de données.")
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
