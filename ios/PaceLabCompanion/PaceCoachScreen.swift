import SwiftUI

struct PaceCoachScreen: View {
    @EnvironmentObject private var client: PaceChatGPTConnection
    @EnvironmentObject private var coach: PaceCoachEngine
    @EnvironmentObject private var engine: HealthSyncEngine
    @EnvironmentObject private var library: PaceLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var showPreview = false
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
                                        Task { await coach.generate(client:client,engine:engine,library:library) }
                                    }
                                    .buttonStyle(.bordered).tint(PaceColors.teal)
                                }
                            }
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
            VStack(alignment:.leading,spacing:14) {
                Label("Données partagées avec le coach",systemImage:"hand.raised")
                    .font(.headline)
                Text("Chaque option est facultative. Les données brutes de cardio et les trajets GPS ne sont jamais envoyés.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Résumés de mes huit dernières courses",isOn:$coach.shareRunSummaries)
                Toggle("Dernier poids renseigné",isOn:$coach.shareWeight)
                Toggle("Repas prévus",isOn:$coach.shareNutrition)
                Divider()
                Toggle(isOn:$coach.autoReview) {
                    VStack(alignment:.leading,spacing:4) {
                        Text("Préparer automatiquement un bilan")
                        Text("Après une nouvelle course, dès que la récupération est disponible et si l’application peut communiquer.")
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
                    Text(coach.contextPreview(engine:engine,library:library))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth:.infinity,alignment:.leading)
                        .padding(13)
                        .background(PaceColors.base,in:RoundedRectangle(cornerRadius:13))
                }
            }
            .toggleStyle(.switch)
            .tint(PaceColors.teal)
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
                    Task { await coach.generate(client:client,engine:engine,library:library) }
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
                            Task { await coach.chat(text,client:client,engine:engine,library:library) }
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
