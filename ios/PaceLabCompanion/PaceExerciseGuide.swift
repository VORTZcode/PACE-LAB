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
                         errors:"Éviter de s’asseoir brutalement et de laisser les genoux rentrer.",figure:"squat")
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
                         errors:"Ne pas laisser le bassin s’affaisser ni bloquer la respiration.",figure:"plank")
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
                         errors:"Éviter les mouvements brusques et une flexion douloureuse du genou.",figure:"squat")
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
                         errors:"Ne pas utiliser une table instable ou laisser les hanches tomber.",figure:"plank")
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

private struct PosePoint {
    var x: CGFloat
    var y: CGFloat
}

struct PaceExerciseVisual: View {
    let figure: String

    var body: some View {
        HStack(spacing: 10) {
            stage("Départ", final: false)
            stage("Fin du geste", final: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Illustration schématique des deux phases du mouvement, départ puis fin du geste. Lire les instructions pour la technique exacte.")
    }

    private func stage(_ title: String, final: Bool) -> some View {
        VStack(spacing: 7) {
            Canvas { context, size in
                func p(_ x: CGFloat,_ y: CGFloat) -> CGPoint { CGPoint(x:x*size.width,y:y*size.height) }
                let squat = figure == "squat"
                let plank = figure == "plank"
                let row = figure == "row" || figure == "hinge"
                let ground = figure == "bridge" || figure == "press" || figure == "deadbug"
                let forward = figure == "calf" || figure == "carry" || figure == "overhead"
                var shoulder=p(0.49,0.35), hip=p(0.50,0.62),head=p(0.48,0.23)
                var elbow=p(0.65,0.46),hand=p(0.66,0.61)
                var knee=p(0.49,0.77),ankle=p(0.49,0.92)
                var farKnee=p(0.65,0.78),farAnkle=p(0.65,0.92)
                if squat && final {
                    shoulder=p(0.43,0.41);head=p(0.40,0.29);hip=p(0.58,0.66)
                    knee=p(0.38,0.77);ankle=p(0.34,0.92)
                    farKnee=p(0.72,0.76);farAnkle=p(0.73,0.92)
                } else if row {
                    shoulder=p(final ? 0.54:0.63,0.45);head=p(final ? 0.43:0.52,0.33);hip=p(0.35,0.64)
                    knee=p(0.32,0.78);ankle=p(0.30,0.93)
                    elbow=p(final ? 0.55:0.70,final ? 0.54:0.66)
                    hand=p(final ? 0.43:0.72,final ? 0.62:0.81)
                } else if plank {
                    head=p(0.17,final ? 0.52:0.50);shoulder=p(0.28,0.54)
                    hip=p(0.56,final ? 0.57:0.75)
                    elbow=p(0.24,0.73);hand=p(0.36,0.75)
                    knee=p(0.75,0.70);ankle=p(0.86,0.76)
                    farKnee=knee;farAnkle=ankle
                } else if ground {
                    head=p(0.17,0.75);shoulder=p(0.28,0.74)
                    hip=p(0.52,final && figure=="bridge" ? 0.53:0.77)
                    elbow=p(0.36,final ? 0.35:0.58);hand=p(0.44,final ? 0.23:0.56)
                    knee=p(0.67,0.60);ankle=p(0.77,0.84)
                    farKnee=knee;farAnkle=ankle
                } else if forward {
                    if figure=="overhead" {
                        elbow=p(0.65,final ? 0.28:0.46);hand=p(0.65,final ? 0.11:0.35)
                    } else if figure=="calf" && final {
                        ankle=p(0.51,0.86);farAnkle=p(0.65,0.86)
                    } else if figure=="carry" && final {
                        hip=p(0.56,0.61);knee=p(0.63,0.74);ankle=p(0.75,0.90)
                    }
                }
                // Layered anatomical silhouette: broad torso and tapered limbs, with
                // rounded joints, subtle highlights and turquoise activated muscles.
                // Keeps the vectors offline, scale-independent and consistent in light/dark.
                let silhouette = Color(red:0.30,green:0.38,blue:0.43)
                let muscle = PaceColors.teal
                func bone(_ a:CGPoint,_ b:CGPoint,width:CGFloat=14, tint:Color=silhouette) {
                    var path=Path();path.move(to:a);path.addLine(to:b)
                    context.stroke(path,with:.color(tint),
                                   style:StrokeStyle(lineWidth:width,lineCap:.round,lineJoin:.round))
                    var accent=Path();accent.move(to:CGPoint(x:a.x-1,y:a.y-1))
                    accent.addLine(to:CGPoint(x:b.x-1,y:b.y-1))
                    context.stroke(accent,with:.color(.white.opacity(0.13)),
                                   style:StrokeStyle(lineWidth:max(1,width*0.16),lineCap:.round))
                }
                // Back leg and support arm are intentionally subdued for depth.
                bone(hip,farKnee,width:13,tint:silhouette.opacity(0.58))
                bone(farKnee,farAnkle,width:11,tint:silhouette.opacity(0.58))
                if !(plank || row || ground) {
                    bone(shoulder,p(0.36,0.47),width:11,tint:silhouette.opacity(0.65))
                    bone(p(0.36,0.47),p(0.38,0.60),width:10,tint:silhouette.opacity(0.65))
                }
                bone(shoulder,hip,width:23,tint:silhouette)
                bone(hip,knee,width:17,tint:silhouette)
                bone(knee,ankle,width:12,tint:silhouette)
                bone(shoulder,elbow,width:14,tint:silhouette)
                bone(elbow,hand,width:11,tint:silhouette)
                // Principal contracted area; a visual cue, not an anatomical heat map.
                if row || figure == "bridge" || figure == "squat" || figure == "plank" {
                    bone(p((shoulder.x+hip.x)/(2*size.width),
                           (shoulder.y+hip.y)/(2*size.height)),
                         p((shoulder.x+hip.x)/(2*size.width)+0.02,
                           (shoulder.y+hip.y)/(2*size.height)+0.09),
                         width:11,tint:muscle.opacity(0.82))
                }
                let neck = p(head.x/size.width,head.y/size.height+0.055)
                bone(neck,shoulder,width:9,tint:silhouette)
                let headRect=CGRect(x:head.x-size.width*0.07,y:head.y-size.width*0.07,
                                    width:size.width*0.14,height:size.width*0.17)
                context.fill(Path(ellipseIn:headRect),with:.color(silhouette))
                context.stroke(Path(ellipseIn:headRect.insetBy(dx:2,dy:2)),
                               with:.color(.white.opacity(0.18)),lineWidth:1)
                let dumbbell = ["row","press","overhead","carry","hinge","squat"].contains(figure)
                if dumbbell {
                    let weight=p(hand.x/size.width, min(0.91,hand.y/size.height+0.02))
                    bone(p(weight.x/size.width-0.08,weight.y/size.height),
                            p(weight.x/size.width+0.08,weight.y/size.height),width:5,tint:PaceColors.teal)
                }
                let y = size.height*0.95
                bone(p(0.10,y/size.height),p(0.90,y/size.height),width:1,tint:.secondary)
            }
            .frame(height: 165)
            .padding(.horizontal, 5)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth:.infinity)
        .padding(.vertical,9)
        .background {
            RoundedRectangle(cornerRadius:18)
                .fill(LinearGradient(colors:[PaceColors.teal.opacity(0.13),
                                             PaceColors.teal.opacity(0.025)],
                                     startPoint:.topLeading,endPoint:.bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius:18)
                .strokeBorder(PaceColors.teal.opacity(0.14),lineWidth:1)
        }
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
