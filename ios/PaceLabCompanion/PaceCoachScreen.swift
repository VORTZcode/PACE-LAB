import SwiftUI

private enum PaceCoachTab: String, CaseIterable {
    case session = "Ma séance"
    case plan = "Mon programme"
    case chat = "Discuter"
    var symbol: String {
        switch self {
        case .session: return "waveform.path.ecg"
        case .plan: return "calendar"
        case .chat: return "bubble.left.and.bubble.right"
        }
    }
}

struct PaceCoachScreen: View {
    @EnvironmentObject private var client: PaceChatGPTConnection
    @EnvironmentObject private var coach: PaceCoachEngine
    @EnvironmentObject private var engine: HealthSyncEngine
    @EnvironmentObject private var library: PaceLibrary
    @EnvironmentObject private var journal: PaceSessionJournal
    @EnvironmentObject private var athleteProfile: PaceAthleteProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var showPreview = false
    @State private var showDataControls = false
    @State private var showConsent = false
    @State private var showingConfirmation = false
    @State private var activeTab: PaceCoachTab = .session
    @State private var showAccountSettings = false
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment:.leading,spacing:22) {
                    if client.planUsageEnabled {
                        coachHeader
                        trainingSnapshot
                        modeSelector
                        if activeTab == .session {
                            if coach.newWorkoutAwaitingReview && coach.shareRunSummaries {
                                Label("Nouvelle sortie disponible pour le bilan",systemImage:"checkmark.circle")
                                    .font(.subheadline).foregroundStyle(PaceColors.teal)
                            }
                            sessionAnalysisCard
                            if let report = coach.latestReport { sessionReportCard(report) }
                        } else if activeTab == .plan {
                            programmeEvidenceCard
                            updateCard
                            if let pending = coach.pending { proposalCard(pending) }
                        } else {
                            chatSection
                        }
                    } else {
                        introduction
                        connectionCard
                        Text("Connecte ton compte pour obtenir une analyse personnalisée. Tu pourras ensuite confirmer tes objectifs et décider des données partagées.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if !coach.error.isEmpty {
                        Label(coach.error,systemImage:"exclamationmark.triangle")
                            .font(.subheadline).foregroundStyle(.orange)
                            .padding(14)
                            .frame(maxWidth:.infinity,alignment:.leading)
                            .background(PaceColors.surface,in:RoundedRectangle(cornerRadius:16))
                    }
                    if coach.isLoading {
                        HStack(spacing:11) {
                            ProgressView().controlSize(.small)
                            Text("Le coach prépare son analyse…")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(14)
                    }
                    Text("Conseils sportifs à examiner, pas diagnostic médical. Les décisions et modifications du programme restent sous ton contrôle.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(.bottom,20)
                }
                .frame(maxWidth:750)
                .padding(.horizontal,18)
                .padding(.top,15)
                .frame(maxWidth:.infinity)
            }
            .background(PaceColors.base)
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement:.topBarTrailing) {
                    if client.planUsageEnabled {
                        Button { showProfile = true } label: {
                            Image(systemName:"person.crop.circle")
                        }
                        .accessibilityLabel("Mon profil sportif")
                        Button { showAccountSettings = true } label: {
                            Image(systemName:"gearshape")
                        }
                        .accessibilityLabel("Compte et confidentialité")
                    }
                    Button("Fermer") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                }
            }
            .sheet(isPresented:$showProfile) { PaceAthleteProfileScreen() }
            .sheet(isPresented:$showAccountSettings) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment:.leading,spacing:16) {
                            connectionCard
                            consentCard
                            Text("Données partagées uniquement après autorisation. Consulte ton compte ChatGPT pour gérer les limites de l'application.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(18)
                    }
                    .background(PaceColors.base)
                    .navigationTitle("Compte et données")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement:.topBarTrailing) {
                            Button("Terminé") { showAccountSettings = false }
                        }
                    }
                }
            }
            .sheet(item:$client.browser) { web in
                PaceChatBrowser(url:web.url).ignoresSafeArea()
            }
            .alert("Adopter cette proposition ?",isPresented:$showingConfirmation) {
                Button("Annuler",role:.cancel){}
                Button("Adopter") {
                    guard let pending = coach.pending else { return }
                    let evidence = PaceEvidenceEngine.evaluate(engine.runHistory)
                    let concerns = PaceEvidenceEngine.review(plan:pending,baseline:evidence,profile:athleteProfile.profile)
                    guard concerns.isEmpty,
                          pending.adjustmentRationale?.isEmpty == false,
                          pending.evidenceNotes?.isEmpty == false else {
                        coach.error = "Ce programme demande une révision : " +
                            (concerns.isEmpty ? "justifications manquantes" : concerns.joined(separator:" · "))
                        return
                    }
                    do {
                        try library.acceptCoachDraft(pending)
                        coach.dismissPending()
                    } catch { coach.error = error.localizedDescription }
                }
            } message: {
                Text("Tu confirmes les sept séances et les repas proposés. Tu pourras revenir au programme initial dans Programme.")
            }
        }
    }

    private var coachHeader: some View {
        VStack(alignment:.leading,spacing:15) {
            HStack(alignment:.center,spacing:10) {
                Image(systemName:"sparkles")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(PaceColors.teal)
                    .frame(width:49,height:49)
                    .background(PaceColors.teal.opacity(0.10),
                                in:RoundedRectangle(cornerRadius:16))
                VStack(alignment:.leading,spacing:3) {
                    Text("Ton entraînement")
                        .font(.title2.weight(.semibold))
                    Text("Des données, des décisions éclairées")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let profile = athleteProfile.profile {
                Text(profile.runningGoal)
                    .font(.subheadline)
                    .fixedSize(horizontal:false,vertical:true)
            } else {
                Text("Confirme ton objectif pour personnaliser les prochaines séances.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Button {
                showProfile = true
            } label: {
                HStack(spacing:7) {
                    Text(athleteProfile.profile == nil ? "Confirmer mes objectifs" : "Modifier mes objectifs")
                    Image(systemName:"arrow.up.right")
                }
                .font(.subheadline.weight(.semibold))
            }
            .tint(PaceColors.teal)
        }
        .padding(21)
        .frame(maxWidth:.infinity,alignment:.leading)
        .background(PaceColors.surface,in:RoundedRectangle(cornerRadius:24))
    }

    private var trainingSnapshot: some View {
        let evidence = PaceEvidenceEngine.evaluate(engine.runHistory)
        return HStack(spacing:10) {
            PaceMetric(caption:"Courses sur 28 jours",
                       value:"\(evidence.runCount28Days)",suffix:"",
                       symbol:"figure.run")
            PaceMetric(caption:"Distance sur 28 jours",
                       value:PaceFormat.distance(evidence.distance28Days,places:1),
                       suffix:"km",symbol:"chart.bar")
        }
        .accessibilityElement(children:.contain)
    }

    private var modeSelector: some View {
        Picker("Espace du coach",selection:$activeTab) {
            ForEach(PaceCoachTab.allCases,id:\.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Choisir entre séance, programme et discussion")
    }

    private var programmeEvidenceCard: some View {
        let evidence = PaceEvidenceEngine.evaluate(engine.runHistory)
        return PaceCard {
            VStack(alignment:.leading,spacing:11) {
                HStack {
                    Label("Base d'entraînement",systemImage:"checkmark.shield")
                        .font(.headline)
                    Spacer()
                    Text(evidence.dataQuality)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PaceColors.teal)
                }
                Text("Analyse des 28 derniers jours")
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(evidence.runCount28Days) courses · \(PaceFormat.distance(evidence.distance28Days,places:1)) km · \(Int(evidence.minutes28Days)) minutes")
                    .font(.subheadline.weight(.semibold))
                Text(evidence.analysis)
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal:false,vertical:true)
                DisclosureGroup("Méthode et références") {
                    VStack(alignment:.leading,spacing:10) {
                        Text("Les propositions utilisent la fréquence, l'intensité, le volume récent, les objectifs confirmés et les limites des mesures. Aucun modèle ne peut garantir un résultat.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(PaceEvidenceEngine.sources,id:\.url) { source in
                            if let url = URL(string:source.url) {
                                Link(source.title,destination:url)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.top,8)
                }
                .font(.subheadline)
                .tint(PaceColors.teal)
            }
        }
    }

    private var introduction: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack(alignment:.center,spacing:13) {
                Image(systemName:"sparkles")
                    .font(.system(size:25,weight:.medium))
                    .foregroundStyle(PaceColors.teal)
                    .frame(width:56,height:56)
                    .background(PaceColors.teal.opacity(0.10),in:RoundedRectangle(cornerRadius:18))
                VStack(alignment:.leading,spacing:4) {
                    Text("Ton coach personnel")
                        .font(.title2.weight(.semibold))
                    Text("Course · Musculation · Nutrition")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Text("Analyse tes séances avec ton accord et prépare des ajustements que tu restes libre d’accepter ou de refuser.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var connectionCard: some View {
        PaceCard(padding:20) {
            VStack(alignment:.leading,spacing:14) {
                HStack {
                    Label("Compte ChatGPT",systemImage:"person.crop.circle")
                        .font(.headline)
                    Spacer()
                    if client.planUsageEnabled {
                        Label("Connecté",systemImage:"checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PaceColors.teal)
                    }
                }
                Text(client.status)
                    .font(.subheadline)
                    .foregroundStyle(client.isConnected ? .primary : .secondary)
                if client.isConnected { Text(client.email).font(.caption).foregroundStyle(.secondary) }
                if !client.planUsageEnabled {
                    Button {
                        client.signIn()
                    } label: {
                        HStack {
                            Image(systemName:"person.crop.circle")
                            Text(client.isConnected ? "Autoriser mon abonnement" : "Continuer avec ChatGPT")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth:.infinity).padding(.vertical,11)
                    }
                    .buttonStyle(.borderedProminent).tint(PaceColors.teal)
                    .disabled(client.isBusy)
                    if client.isBusy {
                        Button("Annuler la connexion") { client.cancelPendingSignIn() }
                            .font(.caption).tint(.secondary)
                    }
                    Text("Connexion à ton compte dans un navigateur sécurisé. Aucune clé API à fournir.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    if !client.models.isEmpty {
                        Picker("Modèle",selection:$client.selectedModel) {
                            ForEach(client.models,id:\.slug) { model in
                                Text(model.name).tag(model.slug)
                            }
                        }
                        .tint(PaceColors.teal)
                    }
                    HStack {
                        Text("Utilisation : abonnement ChatGPT")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Déconnecter") { client.disconnect() }
                            .font(.caption).tint(.secondary)
                    }
                }
                Button("Gérer mon utilisation ChatGPT") {
                    if let url = URL(string:"https://chatgpt.com/#settings/Usage") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption.weight(.medium))
                .tint(PaceColors.teal)
            }
        }
    }

    private var consentCard: some View {
        PaceCard {
            DisclosureGroup(isExpanded:$showDataControls) {
                VStack(alignment:.leading,spacing:14) {
                    Text("Le coach reçoit seulement les catégories que tu actives. Elles quittent l’iPhone pour être analysées par OpenAI ; les données locales et les parcours GPS ne sont pas transférés en intégralité.")
                        .font(.caption).foregroundStyle(.secondary)
                Toggle("Résumés de mes huit dernières courses",isOn:$coach.shareRunSummaries)
                VStack(alignment:.leading,spacing:10) {
                    Toggle(isOn:$coach.shareHeartProfile) {
                        VStack(alignment:.leading,spacing:3) {
                            Text("Profil cardiaque minute par minute")
                            Text("Min, max et moyenne par minute pour la séance étudiée.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn:$coach.shareDynamics) {
                        VStack(alignment:.leading,spacing:3) {
                            Text("Puissance, foulée et récupération")
                            Text("Moyennes et variations cardiaques lorsqu'elles sont disponibles.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn:$coach.shareSessionNotes) {
                        VStack(alignment:.leading,spacing:3) {
                            Text("Mon ressenti et mes notes")
                            Text("Difficulté et 300 caractères du commentaire personnel.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(!coach.shareRunSummaries)
                Toggle("Utiliser mon profil sportif confirmé",isOn:$athleteProfile.shareProfile)
                    .disabled(athleteProfile.profile == nil)
                Toggle("Dernier poids renseigné",isOn:$coach.shareWeight)
                Toggle("Repas prévus",isOn:$coach.shareNutrition)
                Divider()
                Toggle(isOn:$coach.autoReview) {
                    VStack(alignment:.leading,spacing:4) {
                        Text("Préparer automatiquement un bilan")
                        Text("Prépare un bilan après récupération ; ne modifie jamais le programme sans validation.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .disabled(!coach.shareRunSummaries)
                Button(showPreview ? "Masquer l’aperçu partagé" : "Voir le résumé sportif partagé") {
                    showPreview.toggle()
                }
                .font(.subheadline.weight(.semibold))
                .tint(PaceColors.teal)
                if showPreview {
                    Text(coach.contextPreview(engine:engine,library:library,journal:journal,profile:athleteProfile))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth:.infinity,alignment:.leading)
                        .padding(13)
                        .background(PaceColors.base,in:RoundedRectangle(cornerRadius:13))
                }
                }
                .padding(.top,12)
                .toggleStyle(.switch)
                .tint(PaceColors.teal)
            } label: {
                VStack(alignment:.leading,spacing:4) {
                    Label("Confidentialité et données",systemImage:"hand.raised")
                        .font(.subheadline.weight(.semibold))
                    Text(coach.shareRunSummaries
                         ? "Résumé des courses autorisé · réglages facultatifs"
                         : "Autoriser les résumés pour activer les analyses")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .tint(PaceColors.teal)
        }
    }

    private var recentTrainingLoad: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for:.now)
        let lastWeek = calendar.date(byAdding:.day,value:-7,to:today) ?? .distantPast
        let previousWeek = calendar.date(byAdding:.day,value:-14,to:today) ?? .distantPast
        let now = Date.now
        let currentRuns = engine.runHistory.filter { $0.startDate >= lastWeek && $0.startDate <= now }
        let previousRuns = engine.runHistory.filter { $0.startDate >= previousWeek && $0.startDate < lastWeek }
        let current = currentRuns.reduce(0.0) { $0 + $1.kilometers }
        let previous = previousRuns.reduce(0.0) { $0 + $1.kilometers }
        return VStack(alignment:.leading,spacing:12) {
            PaceSectionTitle(title:"Ma charge récente")
            HStack(spacing:10) {
                PaceMetric(caption:"7 derniers jours",value:PaceFormat.distance(current),suffix:"km",symbol:"figure.run")
                PaceMetric(caption:"7 jours précédents",value:PaceFormat.distance(previous),suffix:"km",symbol:"calendar")
            }
            Text("\(currentRuns.count) courses cette semaine, \(previousRuns.count) la semaine précédente. Les différences de distance ne prouvent pas, à elles seules, une progression.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var sessionAnalysisCard: some View {
        PaceCard {
            VStack(alignment:.leading,spacing:13) {
                Label("Décrypter une séance",systemImage:"waveform.path.ecg")
                    .font(.headline)
                if let run = coach.selectedRun(engine:engine) {
                    Menu {
                        Button("Dernière course") { coach.focusWorkoutID = nil }
                        Divider()
                        ForEach(Array(engine.runHistory.prefix(12))) { option in
                            Button("\(option.startDate.formatted(.dateTime.day().month().year())) · \(PaceFormat.distance(option.kilometers,places:2)) km") {
                                coach.focusWorkoutID = option.source_uuid
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment:.leading,spacing:3) {
                                Text("Séance sélectionnée")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("\(run.startDate.formatted(.dateTime.day().month().year())) · \(PaceFormat.distance(run.kilometers,places:2)) km")
                                    .font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                            Image(systemName:"chevron.up.chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(13)
                        .background(PaceColors.base,in:RoundedRectangle(cornerRadius:14))
                    }
                    .buttonStyle(.plain)
                    .tint(PaceColors.teal)
                        .font(.subheadline.weight(.medium))
                    Text("Analyse la fréquence cardiaque, la récupération, tes quatre dernières semaines et les informations que tu autorises.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button {
                        Task { await coach.analyzeSession(client:client,engine:engine,library:library,journal:journal,profile:athleteProfile) }
                    } label: {
                        Label("Analyser cette sortie",systemImage:"sparkles")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth:.infinity).padding(.vertical,10)
                    }
                    .buttonStyle(.borderedProminent).tint(PaceColors.teal)
                    .disabled(!coach.shareRunSummaries || coach.isLoading)
                } else {
                    Text("Enregistre d’abord une course avec Apple Santé.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func sessionReportCard(_ report:PaceCoachSessionReport) -> some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                PaceSectionTitle(title:"Bilan sportif")
                Spacer()
                Button("Effacer") { coach.clearSessionReport() }
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            PaceCard {
                VStack(alignment:.leading,spacing:14) {
                    Label(report.title,systemImage:"checkmark.seal")
                        .font(.headline).foregroundStyle(PaceColors.teal)
                    if let session = engine.workout(id:report.workoutID) {
                        Text("Séance du \(session.startDate.formatted(.dateTime.day().month().year())) · \(PaceFormat.distance(session.kilometers,places:2)) km")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(report.summary).font(.subheadline)
                    Divider()
                    Text("Ce que montrent les mesures").font(.subheadline.weight(.semibold))
                    ForEach(report.observations,id:\.self) { line in
                        Label(line,systemImage:"chart.xyaxis.line")
                            .font(.footnote).fixedSize(horizontal:false,vertical:true)
                    }
                    Divider()
                    Text("Conseils pour la suite").font(.subheadline.weight(.semibold))
                    ForEach(report.recommendations,id:\.self) { line in
                        Label(line,systemImage:"checkmark.circle")
                            .font(.footnote).fixedSize(horizontal:false,vertical:true)
                    }
                    Text("Conséquence sur le programme").font(.subheadline.weight(.semibold))
                    Text(report.trainingImpact).font(.footnote)
                    DisclosureGroup("Ce qu’on ne peut pas conclure") {
                        ForEach(report.uncertainties,id:\.self) { line in
                            Label(line,systemImage:"info.circle")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.tint(PaceColors.teal)
                    Text("Bilan sportif généré par ChatGPT, sans diagnostic médical.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var updateCard: some View {
        PaceCard {
            VStack(alignment:.leading,spacing:14) {
                Label("Préparer mon prochain programme",systemImage:"calendar.badge.clock")
                    .font(.headline)
                Text("Le coach propose sept jours de séances et quatorze repas à partir des résumés autorisés. Rien ne sera modifié sans validation.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button {
                    Task { await coach.generate(client:client,engine:engine,library:library,journal:journal,profile:athleteProfile) }
                } label: {
                    Label("Analyser et proposer",systemImage:"sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth:.infinity).padding(.vertical,10)
                }
                .buttonStyle(.borderedProminent)
                .tint(PaceColors.teal)
                .disabled(coach.isLoading || !coach.shareRunSummaries ||
                          athleteProfile.profile == nil || !athleteProfile.shareProfile)
                if athleteProfile.profile == nil || !athleteProfile.shareProfile {
                    Text("Confirme d'abord ton profil et autorise son utilisation pour éviter un programme générique.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Compléter mon profil") { showProfile = true }
                        .font(.subheadline.weight(.semibold)).tint(PaceColors.teal)
                }
            }
        }
    }

    private func proposalCard(_ draft:PaceAICoachDraft) -> some View {
        VStack(alignment:.leading,spacing:14) {
            PaceSectionTitle(title:"Proposition à valider")
            PaceCard {
                VStack(alignment:.leading,spacing:13) {
                    Label(draft.title,systemImage:"sparkles")
                        .font(.headline).foregroundStyle(PaceColors.teal)
                    Text(draft.summary).font(.subheadline)
                    Text("Pourquoi ce programme ?")
                        .font(.subheadline.weight(.semibold))
                    Text(draft.adjustmentRationale ?? "Justification indisponible")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let evidence = draft.evidenceNotes {
                        ForEach(evidence,id:\.self) { detail in
                            Label(detail,systemImage:"chart.xyaxis.line")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    ForEach(draft.training.sorted(by:{$0.date < $1.date})) { day in
                        VStack(alignment:.leading,spacing:4) {
                            HStack {
                                Text(day.date).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(day.minutes) min")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            Text(day.type+" · "+day.title)
                                .font(.subheadline.weight(.semibold))
                            Text(day.instructions).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth:.infinity,alignment:.leading)
                        Divider()
                    }
                    DisclosureGroup("Voir les quatorze repas") {
                        ForEach(draft.meals.sorted(by:{$0.date < $1.date})) { meal in
                            VStack(alignment:.leading,spacing:4) {
                                Text("\(meal.date) · \(meal.meal) : \(meal.title)")
                                    .font(.subheadline.weight(.semibold))
                                Text("≈ \(meal.kcal) kcal · ≈ \(meal.protein) g de protéines (estimations)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical,5)
                        }
                    }
                    .tint(PaceColors.teal)
                    if !draft.cautions.isEmpty {
                        ForEach(draft.cautions,id:\.self) { item in
                            Label(item,systemImage:"info.circle")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button { showingConfirmation = true } label: {
                        Label("Adopter ce programme",systemImage:"checkmark.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth:.infinity).padding(.vertical,11)
                    }
                    .buttonStyle(.borderedProminent).tint(PaceColors.teal)
                    Button("Refuser la proposition") { coach.dismissPending() }
                        .font(.subheadline).tint(.secondary)
                        .frame(maxWidth:.infinity)
                }
            }
        }
    }

    private var chatSection: some View {
        VStack(alignment:.leading,spacing:13) {
            HStack(alignment:.firstTextBaseline) {
                PaceSectionTitle(title:"Discuter avec le coach")
                Spacer()
                if !coach.conversation.isEmpty {
                    Button("Effacer") { coach.clearConversation() }
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
            }
            PaceCard {
                VStack(alignment:.leading,spacing:12) {
                    if coach.conversation.isEmpty {
                        Text("Pose une question sur une séance, la récupération ou le programme.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        ForEach(coach.conversation) { message in
                            VStack(alignment:.leading,spacing:5) {
                                Text(message.speaker)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(message.speaker == "Coach" ? PaceColors.teal : .secondary)
                                Text(message.text)
                                    .font(.subheadline)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth:.infinity,alignment:.leading)
                            .padding(11)
                            .background(PaceColors.base,in:RoundedRectangle(cornerRadius:13))
                        }
                    }
                    HStack(alignment:.bottom,spacing:10) {
                        TextField("Une question pour le coach…",text:$question,axis:.vertical)
                            .lineLimit(1...4)
                            .textInputAutocapitalization(.sentences)
                            .padding(.horizontal,13).padding(.vertical,11)
                            .background(PaceColors.base,in:RoundedRectangle(cornerRadius:16))
                        Button {
                            let text = question
                            question = ""
                            Task { await coach.chat(text,client:client,engine:engine,library:library,journal:journal,profile:athleteProfile) }
                        } label: {
                            Image(systemName:"arrow.up.circle.fill")
                                .font(.system(size:32))
                                .foregroundStyle(PaceColors.teal)
                        }
                        .disabled(coach.isLoading || question.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Envoyer la question")
                    }
                }
            }
        }
    }
}
