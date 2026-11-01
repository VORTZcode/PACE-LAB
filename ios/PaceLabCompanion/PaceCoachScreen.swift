import SwiftUI

struct PaceCoachScreen: View {
    @EnvironmentObject private var client: PaceChatGPTConnection
    @EnvironmentObject private var coach: PaceCoachEngine
    @EnvironmentObject private var engine: HealthSyncEngine
    @EnvironmentObject private var library: PaceLibrary
    @EnvironmentObject private var journal: PaceSessionJournal
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var showPreview = false
    @State private var showDataControls = false
    @State private var showConsent = false
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    introduction
                    connectionCard
                    if client.planUsageEnabled {
                        consentCard
                        if coach.newWorkoutAwaitingReview && coach.shareRunSummaries {
                            PaceCard {
                                VStack(alignment:.leading,spacing:9) {
                                    Label("Une nouvelle course est prête à être analysée",
                                          systemImage:"figure.run.circle")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(PaceColors.teal)
                                    Text("Le coach peut proposer des ajustements après l’enregistrement de la récupération.")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Button("Analyser cette course") {
                                        Task { await coach.analyzeSession(client:client,engine:engine,library:library,journal:journal) }
                                    }
                                    .buttonStyle(.bordered).tint(PaceColors.teal)
                                }
                            }
                        }
                        recentTrainingLoad
                        sessionAnalysisCard
                        if let report = coach.latestReport {
                            sessionReportCard(report)
                        }
                        updateCard
                        if let pending = coach.pending {
                            proposalCard(pending)
                        }
                        chatSection
                    }
                    if !coach.error.isEmpty {
                        Label(coach.error,systemImage:"exclamationmark.circle")
                            .font(.footnote).foregroundStyle(.orange)
                            .padding(14)
                    }
                    if coach.isLoading {
                        HStack(spacing:11) {
                            ProgressView().controlSize(.small)
                            Text("Le coach analyse les données autorisées…")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal,5)
                    }
                    Text("PACE LAB n’est pas un dispositif médical. Les suggestions du coach ne remplacent pas un professionnel de santé.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(.bottom,22)
                }
                .frame(maxWidth:750)
                .padding(.horizontal,18).padding(.top,14)
                .frame(maxWidth:.infinity)
            }
            .background(PaceColors.base)
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { if !coach.shareRunSummaries { showDataControls = true } }
            .toolbar {
                ToolbarItem(placement:.topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                }
            }
            .sheet(item:$client.browser) { web in
                PaceChatBrowser(url:web.url)
                    .ignoresSafeArea()
            }
            .alert("Appliquer cette proposition ?",isPresented:$showingConfirmation) {
                Button("Annuler",role:.cancel){}
                Button("Appliquer") {
                    guard let pending = coach.pending else { return }
                    do {
                        try library.acceptCoachDraft(pending)
                        coach.dismissPending()
                    } catch { coach.error = error.localizedDescription }
                }
            } message: {
                Text("Les séances et repas du programme affiché seront remplacés. Vous pourrez restaurer le programme initial depuis l’onglet Programme.")
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
                    Text(coach.contextPreview(engine:engine,library:library,journal:journal))
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
                        Task { await coach.analyzeSession(client:client,engine:engine,library:library,journal:journal) }
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
                    Task { await coach.generate(client:client,engine:engine,library:library,journal:journal) }
                } label: {
                    Label("Analyser et proposer",systemImage:"sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth:.infinity).padding(.vertical,10)
                }
                .buttonStyle(.borderedProminent)
                .tint(PaceColors.teal)
                .disabled(coach.isLoading || !coach.shareRunSummaries)
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
                                Text("\(meal.kcal) kcal · \(meal.protein) g protéines")
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
                            Task { await coach.chat(text,client:client,engine:engine,library:library,journal:journal) }
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
