import SwiftUI

struct PaceEffortGuide: View {
    let day: PaceDay

    private var isRun: Bool { day.type == "Course" }
    private var easy: Bool {
        day.intensity.lowercased().contains("rpe 3") || day.title.lowercased().contains("facile")
    }
    private var effort: ClosedRange<Double> {
        if day.type == "Récupération" { return 2...3 }
        if easy { return 3...4 }
        return 4...6
    }
    private var warmup: String {
        if day.instructions.contains("8 min marche rapide") { return "8 min de marche rapide, en augmentant doucement le rythme." }
        if day.instructions.contains("marche") { return "Commence par quelques minutes de marche souple." }
        return "Commence très progressivement, sans chercher la vitesse."
    }
    private var main: String {
        if day.instructions.contains("30 min course") { return "30 min de course tranquille. Si nécessaire, alterne 4 min de course et 1 min de marche." }
        if day.title.lowercased().contains("longue") { return "Cours à une allure régulière et confortable ; conserve la même facilité jusqu'à la fin." }
        if day.type == "Récupération" { return "Marche à un rythme agréable et mobilise doucement les articulations." }
        return "Suis la durée indiquée, avec une respiration confortable et un effort qui reste maîtrisé."
    }
    private var cooldown: String {
        if day.instructions.contains("5 min marche") { return "5 min de marche tranquille, puis laisse ta respiration revenir au calme." }
        return "Termine progressivement sans accélération finale ; marche quelques minutes si besoin."
    }

    var body: some View {
        PaceSectionTitle(title:"Ton guide de séance",subtitle:"Clair et progressif")
        PaceCard {
            VStack(alignment:.leading,spacing:17) {
                HStack(spacing:12) {
                    Image(systemName:isRun ? "figure.run" : "figure.walk")
                        .font(.title2).foregroundStyle(PaceColors.teal)
                        .frame(width:46,height:46)
                        .background(PaceColors.teal.opacity(0.10),in:RoundedRectangle(cornerRadius:15))
                    VStack(alignment:.leading,spacing:4) {
                        Text(isRun ? "Une allure facile, pas un chrono" : "Bouger pour récupérer")
                            .font(.headline)
                        Text(isRun ? "Le but est de construire ton endurance avec régularité." :
                             "Aujourd’hui, tu facilites la récupération sans te fatiguer davantage.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Divider()
                Text("Comment se déroule la séance")
                    .font(.subheadline.weight(.semibold))
                step(1,"Préparer",warmup)
                step(2,isRun ? "Courir tranquillement" : "Bouger",main)
                step(3,"Revenir au calme",cooldown)
                Divider()
                HStack {
                    VStack(alignment:.leading,spacing:4) {
                        Text("Intensité ressentie").font(.subheadline.weight(.semibold))
                        Text("RPE \(Int(effort.lowerBound))–\(Int(effort.upperBound)) / 10")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(easy || !isRun ? "Facile" : "Maîtrisée")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PaceColors.teal)
                }
                GeometryReader { geometry in
                    ZStack(alignment:.leading) {
                        Capsule().fill(Color.secondary.opacity(0.15))
                        Capsule().fill(PaceColors.teal)
                            .frame(width:geometry.size.width*effort.upperBound/10)
                            .opacity(0.65)
                        Capsule().fill(PaceColors.teal)
                            .frame(width:geometry.size.width*(effort.upperBound-effort.lowerBound)/10)
                            .offset(x:geometry.size.width*effort.lowerBound/10)
                    }
                }
                .frame(height:9)
                Text("RPE signifie perception de l’effort : 0 = aucun effort, 10 = effort maximal. Ici, tu dois rester nettement en dessous de ton maximum.")
                    .font(.footnote).foregroundStyle(.secondary)
                Label(isRun ? "Tu dois pouvoir parler en phrases complètes, sans haleter." :
                      "Tu peux discuter normalement et respirer confortablement.",systemImage:"quote.bubble")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PaceColors.teal)
                Label("Si tu ne peux plus parler normalement, ralentis ou marche. En cas de douleur inhabituelle, arrête-toi.",systemImage:"exclamationmark.shield")
                    .font(.footnote).foregroundStyle(.secondary)
                DisclosureGroup("Les termes du programme expliqués") {
                    VStack(alignment:.leading,spacing:10) {
                        Text("Endurance fondamentale : courir suffisamment lentement pour développer ton endurance sans accumuler beaucoup de fatigue.")
                        Text("RPE : ta difficulté ressentie sur 10. Entre 3 et 4, l’effort doit être confortable et durable.")
                        Text("Test de conversation : tu arrives à parler en phrases complètes ; sinon tu ralentis.")
                        Text("Fréquence cardiaque : une indication complémentaire, variable selon chaleur, sommeil, stress et terrain. Ne force pas une allure pour suivre un nombre.")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top,9)
                }
                .font(.footnote.weight(.semibold))
                .tint(PaceColors.teal)
                if isRun {
                    Text("La durée totale peut inclure l’échauffement et le retour au calme en plus du temps de course indiqué.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func step(_ number:Int,_ title:String,_ detail:String) -> some View {
        HStack(alignment:.top,spacing:12) {
            Text("\(number)").font(.subheadline.weight(.bold))
                .foregroundStyle(PaceColors.teal)
                .frame(width:30,height:30)
                .background(PaceColors.teal.opacity(0.12),in:Circle())
            VStack(alignment:.leading,spacing:3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal:false,vertical:true)
            }
        }
    }
}

struct PaceStrengthIntensityGuide: View {
    var body: some View {
        VStack(alignment:.leading,spacing:9) {
            Text("Comment doser ton effort")
                .font(.subheadline.weight(.semibold))
            Text("RIR 2–3 : à la fin de ta série, tu aurais encore pu réaliser 2 à 3 répétitions propres. Ce n’est pas une obligation d’aller jusqu’à l’échec.")
                .font(.subheadline)
            Text("RPE 6–7 / 10 : effort modéré à assez soutenu, mais toujours contrôlé. Prends le temps de récupérer entre les séries.")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("En cas de douleur articulaire, arrête l’exercice et adapte-le : la bonne technique prime sur la charge.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
