import Foundation

/// Capability inventory, not an authorization readout.
/// HealthKit does not reliably disclose which read permissions the user denied.
enum PaceHealthPipelineStage: String {
    case availableInCurrentPipeline
    case partialPipeline
    case planned
}

enum PaceHealthDataDomain: String, CaseIterable {
    case sessions = "Séances"
    case cardio = "Cardiovasculaire"
    case recovery = "Récupération"
    case body = "Composition corporelle"
    case dailyActivity = "Activité quotidienne"
}

struct PaceHealthCapability: Identifiable {
    let id: String
    let title: String
    let domain: PaceHealthDataDomain
    let stage: PaceHealthPipelineStage
    let benefit: String
    /// Never means that actual user data is present or authorized.
    let neverShareRawByDefault: Bool
}

/// Keep product promises aligned with the code. Adding a row does NOT grant
/// HealthKit permission and does NOT start a query or share data with OpenAI.
enum PaceHealthCoverageCatalog {
    static let all: [PaceHealthCapability] = [
        .init(id:"workouts",title:"Séances enregistrées",
              domain:.sessions,stage:.availableInCurrentPipeline,
              benefit:"Volume, durée et historique",neverShareRawByDefault:false),
        .init(id:"workout-routes",title:"Itinéraires GPS",
              domain:.sessions,stage:.availableInCurrentPipeline,
              benefit:"Carte et survol uniquement sur l'iPhone",neverShareRawByDefault:true),
        .init(id:"heart-rate",title:"Fréquence cardiaque durant l'effort",
              domain:.cardio,stage:.availableInCurrentPipeline,
              benefit:"Effort observé et récupération",neverShareRawByDefault:false),
        .init(id:"running-dynamics",title:"Dynamique de course",
              domain:.sessions,stage:.partialPipeline,
              benefit:"Puissance, cadence estimée, foulée et oscillation si disponibles",
              neverShareRawByDefault:false),
        .init(id:"sleep",title:"Sommeil",
              domain:.recovery,stage:.partialPipeline,
              benefit:"Durée et régularité, sans diagnostic des stades",
              neverShareRawByDefault:false),
        .init(id:"manual-body",title:"Poids et tour de taille saisis",
              domain:.body,stage:.partialPipeline,
              benefit:"Suivi descriptif des mesures déclarées",neverShareRawByDefault:false),
        .init(id:"resting-heart-rate",title:"Fréquence cardiaque au repos",
              domain:.cardio,stage:.partialPipeline,
              benefit:"Tendance cardiovasculaire contextuelle",neverShareRawByDefault:false),
        .init(id:"hrv-sdnn",title:"Variabilité cardiaque SDNN",
              domain:.cardio,stage:.partialPipeline,
              benefit:"Tendance individuelle, pas un score universel de récupération",
              neverShareRawByDefault:false),
        .init(id:"vo2max",title:"VO2 max estimé",
              domain:.cardio,stage:.partialPipeline,
              benefit:"Repère d'endurance estimé, dépendant de la source",neverShareRawByDefault:false),
        .init(id:"walking-heart-rate",title:"Fréquence cardiaque de marche",
              domain:.cardio,stage:.partialPipeline,
              benefit:"Indicateur complémentaire dépendant des conditions",
              neverShareRawByDefault:false),
        .init(id:"respiratory-rate",title:"Fréquence respiratoire",
              domain:.recovery,stage:.planned,
              benefit:"Contexte de récupération, pas un diagnostic",
              neverShareRawByDefault:false),
        .init(id:"sleeping-wrist-temperature",title:"Température du poignet pendant le sommeil",
              domain:.recovery,stage:.planned,
              benefit:"Variation personnelle si la montre le mesure",
              neverShareRawByDefault:false),
        .init(id:"body-mass-healthkit",title:"Poids depuis Santé",
              domain:.body,stage:.partialPipeline,
              benefit:"Mesure importée et source vérifiable",neverShareRawByDefault:false),
        .init(id:"body-fat-percentage",title:"Pourcentage de graisse corporelle",
              domain:.body,stage:.partialPipeline,
              benefit:"Suivi uniquement si réellement mesuré",neverShareRawByDefault:false),
        .init(id:"lean-body-mass",title:"Masse maigre",
              domain:.body,stage:.partialPipeline,
              benefit:"Estimation à contextualiser selon le capteur",neverShareRawByDefault:false),
        .init(id:"step-count",title:"Pas quotidiens",
              domain:.dailyActivity,stage:.planned,
              benefit:"Charge hors séances et régularité quotidienne",neverShareRawByDefault:false),
        .init(id:"flights-climbed",title:"Étages montés",
              domain:.dailyActivity,stage:.planned,
              benefit:"Contexte d'activité",neverShareRawByDefault:false),
        .init(id:"daily-active-energy",title:"Énergie active quotidienne",
              domain:.dailyActivity,stage:.planned,
              benefit:"Indicateur estimé, non assimilation exacte de calories",
              neverShareRawByDefault:false)
    ]

    static func grouped(_ domain: PaceHealthDataDomain) -> [PaceHealthCapability] {
        all.filter { $0.domain == domain }
    }

    static var planned: [PaceHealthCapability] {
        all.filter { $0.stage == .planned }
    }
}
