import SwiftUI

struct PaceMovementGuide {
    let title: String
    let focus: String
    let steps: [String]
    let check: String
    let errors: String
    let figure: String

    static func forExercise(_ exercise: PaceExercise) -> PaceMovementGuide {
        let name = exercise.name.lowercased()
        if name.contains("goblet squat") {
            return .init(title:"Squat avec haltère contre la poitrine",focus:"Cuisses, fessiers et stabilité du tronc",
                         steps:["Tiens l’haltère contre ta poitrine, pieds un peu plus larges que les hanches.",
                                "Plie hanches et genoux en gardant les talons au sol.",
                                "Descends aussi bas que tu peux sans douleur, puis pousse dans les pieds pour remonter."],
                         check:"Le buste reste gainé et les genoux suivent la direction des orteils.",
                         errors:"Éviter de décoller les talons, d’arrondir fortement le dos ou de descendre malgré une douleur.",figure:"squat")
        }
        if name.contains("squat à la chaise") {
            return .init(title:"Squat contrôlé vers une chaise",focus:"Cuisses et fessiers",
                         steps:["Place une chaise stable derrière toi et tiens l’haltère si prévu.",
                                "Recule les hanches, plie les genoux jusqu’à effleurer l’assise.",
                                "Remonte en poussant dans les pieds sans te laisser tomber sur la chaise."],
                         check:"Tu contrôles toute la descente et la chaise ne bouge pas.",
                         errors:"Éviter de s’asseoir brutalement et de laisser les genoux rentrer.",figure:"chair")
        }
        if name.contains("rowing") {
            return .init(title:"Tirage avec un haltère, un bras",focus:"Dos, surtout grand dorsal et muscles autour de l’omoplate",
                         steps:["Pose la main libre sur un support très stable, buste incliné, dos neutre.",
                                "Laisse l’haltère descendre sous l’épaule sans tourner le buste.",
                                "Tire le coude vers la hanche, puis redescends lentement. Répète de l’autre côté."],
                         check:"La sensation dominante est dans le dos, sans élan du buste.",
                         errors:"Ne pas hausser l’épaule, faire tourner le torse ou tirer avec une impulsion.",figure:"row")
        }
        if name.contains("développé couché") {
            return .init(title:"Développé au sol, un bras",focus:"Pectoraux, triceps et stabilité",
                         steps:["Allonge-toi au sol, genoux fléchis, haltère tenu au-dessus de l’épaule.",
                                "Plie lentement le coude jusqu’au contact léger du bras avec le sol.",
                                "Pousse l’haltère vers le plafond sans décoller le dos. Change de bras."],
                         check:"Le poignet reste aligné avec l’avant-bras et le mouvement reste contrôlé.",
                         errors:"Éviter une cambrure forcée ou une descente brutale du bras.",figure:"press")
        }
        if name.contains("pont fessier") {
            return .init(title:"Pont fessier",focus:"Fessiers et arrière des cuisses",
                         steps:["Allonge-toi sur le dos, genoux pliés, pieds au sol et haltère stabilisé sur le bassin.",
                                "Contracte les fessiers et soulève le bassin sans cambrer excessivement.",
                                "Marque une courte pause, puis redescends doucement."],
                         check:"Les épaules restent au sol ; la montée vient des hanches.",
                         errors:"Ne pas pousser avec le cou ou projeter les côtes vers le haut.",figure:"bridge")
        }
        if name.contains("planche latérale") {
            return .init(title:"Planche sur le côté",focus:"Gainage latéral et stabilité du bassin",
                         steps:["Place le coude exactement sous l’épaule et aligne les jambes.",
                                "Soulève le bassin jusqu’à former une ligne épaule-hanche-cheville.",
                                "Respire normalement pendant la durée prévue, puis change de côté."],
                         check:"Le bassin reste haut, sans douleur à l’épaule.",
                         errors:"Ne pas laisser le bassin s’affaisser ni bloquer la respiration.",figure:"sideplank")
        }
        if name.contains("planche avant") {
            return .init(title:"Planche sur les avant-bras",focus:"Abdominaux et gainage global",
                         steps:["Place les coudes sous les épaules et tends les jambes derrière toi.",
                                "Contracte légèrement abdominaux et fessiers pour aligner tête, dos et bassin.",
                                "Maintiens la position pendant le nombre de secondes prévu, en respirant."],
                         check:"Si tu notes 40 dans Durée (s), cela signifie 40 secondes, pas 40 répétitions.",
                         errors:"Ne pas creuser le bas du dos, relever trop le bassin ou retenir son souffle.",figure:"plank")
        }
        if name.contains("mollets") {
            return .init(title:"Élévations des mollets",focus:"Muscles du mollet et contrôle de la cheville",
                         steps:["Tiens-toi debout sur sol plat, avec appui stable à portée de main.",
                                "Monte sur la pointe des pieds sans rebondir.",
                                "Redescends lentement ; garde les genoux légèrement fléchis si demandé."],
                         check:"L’amplitude est confortable et le tendon d’Achille ne fait pas mal.",
                         errors:"Éviter les rebonds rapides et les séries poursuivies malgré une douleur au tendon.",figure:"calf")
        }
        if name.contains("split squat") {
            return .init(title:"Fente statique assistée",focus:"Cuisses, fessiers et équilibre",
                         steps:["Place un pied devant l’autre et garde une main près d’un appui stable.",
                                "Plie les deux genoux verticalement en contrôlant l’équilibre.",
                                "Remonte sans élan et réalise le même nombre de répétitions de l’autre jambe."],
                         check:"Le genou avant suit la direction du pied ; l’amplitude reste indolore.",
                         errors:"Éviter les mouvements brusques et une flexion douloureuse du genou.",figure:"split")
        }
        if name.contains("développé épaules") {
            return .init(title:"Développé au-dessus de la tête",focus:"Épaules et triceps",
                         steps:["Tiens l’haltère à hauteur d’épaule, poignet droit, tronc gainé.",
                                "Pousse vers le haut sans pencher le corps sur le côté.",
                                "Redescends de manière contrôlée puis change de bras."],
                         check:"Le geste reste confortable pour l’épaule, sans compensation du dos.",
                         errors:"Éviter de cambrer fortement et de poursuivre si une douleur d’épaule apparaît.",figure:"overhead")
        }
        if name.contains("soulevé de terre roumain") {
            return .init(title:"Charnière de hanches avec haltère",focus:"Arrière des cuisses, fessiers et stabilité du dos",
                         steps:["Debout, genoux légèrement fléchis, haltère proche des jambes.",
                                "Recule les hanches et incline le buste sans arrondir le dos.",
                                "Arrête la descente avant de perdre la position, puis redresse-toi avec les fessiers."],
                         check:"Tu sens un étirement modéré derrière les cuisses, sans douleur lombaire.",
                         errors:"Ne pas chercher à toucher le sol en arrondissant le dos.",figure:"hinge")
        }
        if name.contains("pompes inclinées") {
            return .init(title:"Pompes avec les mains surélevées",focus:"Pectoraux, triceps et gainage",
                         steps:["Pose les mains sur un meuble immobile, solide et non glissant.",
                                "Garde le corps aligné pendant que tu rapproches la poitrine du support.",
                                "Pousse avec les bras pour revenir, sans creuser le bas du dos."],
                         check:"Tout le corps avance et recule ensemble, sans déplacer le support.",
                         errors:"Ne pas utiliser une table instable ou laisser les hanches tomber.",figure:"incline")
        }
        if name.contains("dead bug") {
            return .init(title:"Dead bug : bras et jambe opposés",focus:"Stabilité abdominale et coordination",
                         steps:["Allonge-toi sur le dos, bras dirigés vers le plafond, hanches et genoux à angle droit.",
                                "Étends lentement un bras et la jambe opposée sans cambrer le dos.",
                                "Ramène-les, puis alterne les côtés."],
                         check:"Le bas du dos reste stable contre le sol et tu peux respirer.",
                         errors:"Ne pas allonger le bras ou la jambe au point de perdre le gainage.",figure:"deadbug")
        }
        if name.contains("marche du fermier") {
            return .init(title:"Marche avec haltère d’un côté",focus:"Prise en main, gainage latéral et posture",
                         steps:["Saisis l’haltère d’un côté, épaules à la même hauteur.",
                                "Marche lentement dans un espace dégagé, sans pencher le buste.",
                                "Chronomètre les secondes prévues puis change de main."],
                         check:"Le tronc reste vertical ; la valeur saisie est une durée en secondes.",
                         errors:"Ne pas accélérer, basculer le buste ou marcher sur un obstacle.",figure:"carry")
        }
        return .init(title:exercise.name, focus:"Contrôle et qualité du mouvement",
                     steps:[exercise.tips,"Réalise la série sans douleur et avec une vitesse contrôlée."],
                     check:"Garde 2 à 3 répétitions possibles si l’exercice est compté en répétitions.",
                     errors:"Arrête en cas de douleur inhabituelle.",figure:"standing")
    }
}

struct PaceExerciseVisual: View {
    let figure: String
    var imageHeight: CGFloat = 178
    @State private var selectedPose = "Start"
    @State private var showingEnlargedPose = false

    private let licensedPhotos: Set<String> = ["plank", "split", "overhead", "incline", "deadbug"]
    private let generatedPhotos: Set<String> = ["squat", "chair", "row", "press", "bridge", "sideplank"]

    private let supported: Set<String> = [
        "squat", "chair", "row", "press", "bridge", "sideplank",
        "plank", "calf", "split", "overhead", "hinge", "incline", "deadbug", "carry"
    ]

    var body: some View {
        if supported.contains(figure) {
            VStack(spacing: 7) {
                GeometryReader { geometry in
                    Button {
                        showingEnlargedPose = true
                    } label: {
                        Image("Movement_\(figure)_\(selectedPose)")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .overlay(alignment: .bottomTrailing) {
                                Label("Agrandir", systemImage: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.6), in: Capsule())
                                    .padding(9)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(selectedPose == "Start"
                                        ? "Agrandir la position initiale"
                                        : "Agrandir la position finale")
                }
                .frame(height: imageHeight)

                HStack(spacing: 5) {
                    poseButton("01 · Départ", pose: "Start")
                    poseButton("02 · Arrivée", pose: "End")
                }
                .padding(3)
                .background(PaceColors.surface, in: RoundedRectangle(cornerRadius: 12))
                if licensedPhotos.contains(figure) {
                    HStack(spacing: 8) {
                        Link("Photos : Everkinetic · CC BY-SA 4.0",
                             destination: URL(string: "https://github.com/yuhonas/free-exercise-db")!)
                        Link("Licence",
                             destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                } else if generatedPhotos.contains(figure) {
                    Text("Visuel généré par IA · démonstration indicative")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Schéma technique provisoire")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showingEnlargedPose) {
                NavigationStack {
                    VStack(spacing: 18) {
                        Spacer()
                        Image("Movement_\(figure)_\(selectedPose)")
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal, 9)
                        HStack(spacing: 7) {
                            poseButton("01 · Départ", pose: "Start")
                            poseButton("02 · Arrivée", pose: "End")
                        }
                        .padding(.horizontal, 18)
                        Text("Démonstration indicative : suis les consignes, contrôle ta posture et n'insiste pas en cas de douleur.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PaceColors.base)
                    .navigationTitle("Mouvement")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Fermer") { showingEnlargedPose = false }
                        }
                    }
                }
            }
        } else {
            Label("Consulte les consignes de mouvement ci-dessous",
                  systemImage: "figure.strengthtraining.traditional")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func poseButton(_ title: String, pose: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedPose = pose }
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selectedPose == pose ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 29)
                .background(selectedPose == pose ? PaceColors.teal : .clear,
                            in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedPose == pose ? .isSelected : [])
    }
}

struct PaceExerciseCoaching: View {
    let exercise: PaceExercise
    private var guide: PaceMovementGuide { .forExercise(exercise) }
    var body: some View {
        VStack(alignment:.leading,spacing:13) {
            PaceExerciseVisual(figure:guide.figure)
            Text(guide.focus).font(.caption).foregroundStyle(.secondary)
            VStack(alignment:.leading,spacing:10) {
                Text("Le mouvement, étape par étape").font(.subheadline.weight(.semibold))
                ForEach(Array(guide.steps.enumerated()),id:\.offset) { index,step in
                    HStack(alignment:.top,spacing:10) {
                        Text("\(index+1)").font(.caption.weight(.bold))
                            .foregroundStyle(PaceColors.teal).frame(width:22,height:22)
                            .background(PaceColors.teal.opacity(0.12),in:Circle())
                        Text(step).font(.subheadline).fixedSize(horizontal:false,vertical:true)
                    }
                }
            }
            Label(guide.check,systemImage:"checkmark.seal")
                .font(.footnote).foregroundStyle(PaceColors.teal)
            Label(guide.errors,systemImage:"exclamationmark.triangle")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
