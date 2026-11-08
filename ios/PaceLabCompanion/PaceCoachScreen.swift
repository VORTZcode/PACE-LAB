import SwiftUI

private struct PaceWorkoutID: Identifiable {
    let id: String
}
private enum PaceCoachTab: String, CaseIterable {
    case chat = "Discuter"
    case session = "Bilans"
    case plan = "Programme"
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
    @EnvironmentObject private var strengthTracker: PaceStrengthTracker
    @EnvironmentObject private var adaptiveMonitor: PaceAdaptiveMonitor
    @EnvironmentObject private var sleep: PaceSleepHealthKit
    @EnvironmentObject private var healthSignals: PaceHealthSignals
    @EnvironmentObject private var autopilot: PaceAutopilot
    @EnvironmentObject private var tabs: PaceTabRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    @State private var question = ""
    @FocusState private var composerFocused: Bool
    @State private var showPreview = false
    @State private var showDataControls = false
    @State private var showMetrics = false
    @State private var showConsent = false
    @State private var showingConfirmation = false
    @State private var activeTab: PaceCoachTab = .chat
    @State private var showAccountSettings = false
    @State private var showProfile = false
    @State private var effortWorkoutID: PaceWorkoutID?

    var body: some View {
        NavigationStack {
            ScrollViewReader { chatScroll in
            ScrollView {
                LazyVStack(alignment:.leading,spacing:22) {
                    if client.planUsageEnabled {
                        if athleteProfile.profile == nil { coachHeader }
                        else if !athleteProfile.shareProfile {
                            Button { showProfile = true } label: {
                                Label("Activer le partage de mes objectifs avec le Coach",
                                      systemImage:"person.crop.circle.badge.exclamationmark")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .tint(PaceColors.teal)
                        }
                        if activeTab != .chat || !autopilot.enabled ||
                           coach.automaticPendingCount > 0 ||
                           coach.automaticNeedsAttentionCount > 0 || coach.pending != nil {
                            coachStatusOverview
                        }
                        modeSelector
                        if activeTab == .session {
                            if coach.newWorkoutAwaitingReview && coach.shareRunSummaries {
                                Label(autopilot.enabled || coach.autoReview
                                      ? "Nouvelle activité détectée · bilan automatique prévu"
                                      : "Nouvelle activité disponible pour le bilan",
                                      systemImage:"checkmark.circle")
                                    .font(.subheadline).foregroundStyle(PaceColors.teal)
                            }
                            if !autopilot.enabled, let suggested = adaptiveMonitor.visible {
                                adaptiveReviewCard(suggested)
                            }
                            if let run = coach.selectedRun(engine: engine),
                               let report = coach.report(for: run.source_uuid) {
                                sessionReportCard(report)
                            }
                            sessionAnalysisCard
                            DisclosureGroup(isExpanded:$showMetrics) {
                                VStack(alignment:.leading,spacing:12) {
                                    trainingSnapshot
                                    sleepSnapshot
                                }
                                .padding(.top,10)
                            } label: {
                                Label("Mesures et sources utilisées",systemImage:"chart.bar.xaxis")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .tint(PaceColors.teal)
                            .padding(.horizontal,4)
                        } else if activeTab == .plan {
                            if let pending = coach.pending { proposalCard(pending) }
                            else { updateCard }
                            DisclosureGroup("Données et méthode du programme") {
                                programmeEvidenceCard
                            }
                            .font(.subheadline.weight(.semibold))
                            .tint(PaceColors.teal)
                            .padding(.horizontal,4)
                        } else {
                            chatSection
                        }
                    } else {
                        introduction
                        connectionCard
                    }
                    if !coach.error.isEmpty && activeTab != .chat {
                        Label(coach.error,systemImage:"exclamationmark.triangle")
                            .font(.subheadline).foregroundStyle(.orange)
                            .padding(14)
                            .frame(maxWidth:.infinity,alignment:.leading)
                            .modifier(PaceGlassCardSurface(cornerRadius: 16))
                    }
                    if coach.isLoading && activeTab != .chat {
                        HStack(spacing:11) {
                            ProgressView().controlSize(.small)
                            Text("Le coach prépare son analyse…")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(14)
                    }
                }
                .frame(maxWidth:750)
                .padding(.horizontal,18)
                .padding(.top,15)
                .frame(maxWidth:.infinity)
            }
            .background(PaceColors.base)
            .safeAreaInset(edge:.bottom,spacing:0) {
                if client.planUsageEnabled && activeTab == .chat {
                    coachComposer
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of:coach.conversation.last?.id) { _,_ in
                guard activeTab == .chat else { return }
                withAnimation(.easeOut(duration:0.2)) {
                    chatScroll.scrollTo("coach-chat-end",anchor:.bottom)
                }
            }
            .onChange(of:coach.streamingReply.count / 120) { _,_ in
                guard activeTab == .chat else { return }
                chatScroll.scrollTo("coach-chat-end",anchor:.bottom)
            }
            .onChange(of:activeTab) { _, tab in
                if tab == .chat {
                    Task { @MainActor in
                        chatScroll.scrollTo("coach-chat-end",anchor:.bottom)
                    }
                } else {
                    composerFocused = false
                }
            }
            .onAppear {
                navigateToCoachDestination(tabs.coachDestination)
                if activeTab == .chat {
                    Task { @MainActor in
                        await Task.yield()
                        chatScroll.scrollTo("coach-chat-end",anchor:.bottom)
                    }
                }
            }
            .onChange(of:tabs.coachDestination) { _, destination in
                navigateToCoachDestination(destination)
            }
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
                    if isPresented {
                        Button("Fermer") { dismiss() }
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .sheet(isPresented:$showProfile) { PaceAthleteProfileScreen() }
            .sheet(item:$effortWorkoutID) { uuid in
                PaceEffortEditor(uuid:uuid.id).environmentObject(journal)
            }
            .sheet(isPresented:$showAccountSettings) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment:.leading,spacing:16) {
                            connectionCard
                            autopilotControls
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
                    let lastWeek = Date().addingTimeInterval(-7 * 86400)
                    let actualStrength = engine.snapshot.filter {
                        $0.activity_kind == "strength" && $0.startDate >= lastWeek && $0.startDate <= .now
                    }.count
                    let concerns = PaceEvidenceEngine.review(plan:pending,baseline:evidence,
                        profile:athleteProfile.profile,observedStrengthLast7:actualStrength)
                    guard concerns.isEmpty,
                          pending.adjustmentRationale?.isEmpty == false,
                          pending.evidenceNotes?.isEmpty == false else {
                        coach.error = "Ce programme demande une révision : " +
                            (concerns.isEmpty ? "justifications manquantes" : concerns.joined(separator:" · "))
                        return
                    }
                    do {
                        try library.acceptCoachDraft(pending)
                        coach.recordAcceptedPlan(pending,baseline:evidence)
                        coach.dismissPending()
                    } catch { coach.error = error.localizedDescription }
                }
            } message: {
                Text("Tu confirmes les sept séances et les repas proposés. Tu pourras revenir au programme initial dans Programme.")
            }
            }
        }
    }

    private func navigateToCoachDestination(_ destination:PaceCoachDestination) {
        if isPresented && coach.focusWorkoutID != nil {
            activeTab = .session
            return
        }
        switch destination {
        case .discussion: activeTab = .chat
        case .bilans: activeTab = .session
        case .programme: activeTab = .plan
        case .settings:
            activeTab = .plan
            showAccountSettings = true
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
        .modifier(PaceGlassCardSurface(cornerRadius: 24))
    }

    private var coachStatusOverview: some View {
        PaceCard(padding:14) {
            VStack(alignment:.leading,spacing:9) {
                HStack(spacing:9) {
                    Image(systemName:autopilot.enabled ? "checkmark.circle.fill" : "brain.head.profile")
                        .foregroundStyle(PaceColors.teal)
                    Text(autopilot.enabled ? "Coach autonome actif" : "Coach en mode manuel")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button { showAccountSettings=true } label: {
                        Image(systemName:"slider.horizontal.3")
                            .foregroundStyle(PaceColors.teal)
                    }
                    .accessibilityLabel("Autorisations et réglages du coach")
                }
                if coach.automaticNeedsAttentionCount > 0 {
                    Label("\(coach.automaticNeedsAttentionCount) bilan(s) à reprendre",
                          systemImage:"exclamationmark.circle")
                        .font(.caption).foregroundStyle(.orange)
                } else if coach.automaticPendingCount > 0 && autopilot.enabled {
                    Label("\(coach.automaticPendingCount) activité(s) à analyser",
                          systemImage:"clock.arrow.circlepath")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if coach.pending != nil {
                    Label("Un programme est prêt à être examiné.",
                          systemImage:"calendar.badge.checkmark")
                        .font(.caption).foregroundStyle(PaceColors.teal)
                }
                if activeTab == .session {
                    if coach.isLoading {
                        Label("Analyse en cours · résultat non encore validé",
                              systemImage: "hourglass")
                            .font(.caption).foregroundStyle(PaceColors.teal)
                    } else if let report = coach.latestReport {
                        Label(report.isLocal
                              ? "Dernier bilan local · analyse ChatGPT non aboutie"
                              : "Dernier bilan ChatGPT confirmé · \(report.createdAt.formatted(date:.abbreviated,time:.shortened))",
                              systemImage: report.isLocal ? "exclamationmark.circle" : "checkmark.shield")
                            .font(.caption)
                            .foregroundStyle(report.isLocal ? .orange : .secondary)
                    } else {
                        Label("Aucun bilan ChatGPT confirmé pour le moment",
                              systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    DisclosureGroup("État technique et données") {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(engine.status)
                            Text(client.planUsageEnabled
                                 ? "Compte ChatGPT connecté et accès activé"
                                 : "Compte ou accès ChatGPT à configurer")
                            Text("Les analyses en attente sont reprises lorsque l'application dispose du temps d'exécution nécessaire. iOS ne garantit pas leur achèvement en arrière-plan.")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                    }
                    .font(.caption.weight(.medium))
                    .tint(PaceColors.teal)
                }
                if !autopilot.enabled {
                    Button("Configurer les analyses automatiques") { showAccountSettings=true }
                        .font(.caption.weight(.semibold))
                        .tint(PaceColors.teal)
                }
            }
        }
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

    private var sleepSnapshot: some View {
        PaceCard {
            VStack(alignment:.leading,spacing:10) {
                HStack {
                    Label("Sommeil · Apple Santé",systemImage:"moon.stars")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(sleep.summary.coverage7)/7 jours")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !sleep.monitoringEnabled {
                    Text("Active la lecture du sommeil pour permettre au coach de comprendre ta récupération dans le temps.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Autoriser le sommeil dans Apple Santé") { sleep.requestAccess() }
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text(sleep.summary.mostRecent7AverageMinutes.map {
                        "Durée moyenne observée : \($0 / 60) h \($0 % 60) min"
                    } ?? "Pas assez de nuits pour calculer une moyenne fiable.")
                        .font(.subheadline)
                    Text(sleep.status)
                        .font(.caption).foregroundStyle(.secondary)
                    if !coach.shareSleep {
                        Text("Ces données restent sur l’iPhone : le partage avec ChatGPT est désactivé.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Actualiser le sommeil") { sleep.refresh(force:true) }
                        .font(.caption.weight(.semibold))
                        .disabled(sleep.isLoading)
                }
            }
        }
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
                if let last = coach.acceptedPlans.first {
                    Divider().opacity(0.35)
                    Label("Suivi du dernier plan accepté", systemImage: "calendar.badge.clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PaceColors.teal)
                    Text(last.summary)
                        .font(.subheadline)
                    if last.reviewedAt != nil {
                        Text("Bilan descriptif des courses trouvées dans Santé. Les écarts ne prouvent ni progression, ni échec du programme.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("PACE-LAB comparera le plan aux sorties enregistrées après sa semaine, sans modifier les séances.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
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

    private var autopilotControls: some View {
        PaceCard {
            VStack(alignment:.leading,spacing:12) {
                Label("Coach autonome",systemImage:"brain.head.profile")
                    .font(.headline)
                Text("Après une nouvelle séance ou nuit synchronisée, ChatGPT vérifie le plan. Les allègements prudents peuvent être appliqués sans validation répétée. Pas de hausse de charge ni de changements de nutrition automatiques.")
                    .font(.footnote).foregroundStyle(.secondary)
                Toggle(isOn:Binding(get:{ autopilot.enabled },
                                    set:{ autopilot.setEnabled($0) })) {
                    Text("Autoriser les adaptations automatiques")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(PaceColors.teal)
                .disabled(!client.planUsageEnabled || !coach.shareRunSummaries ||
                          athleteProfile.profile == nil || !athleteProfile.shareProfile)
                if !client.planUsageEnabled || !coach.shareRunSummaries ||
                    athleteProfile.profile == nil || !athleteProfile.shareProfile {
                    Text("Pour activer : connecter ChatGPT, confirmer le profil sportif et autoriser le résumé des courses.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(autopilot.status)
                    .font(.caption).foregroundStyle(PaceColors.teal)
                Text("Aucune garantie d'analyse immédiate si iOS suspend l'app. Les changements sont réversibles dans Programme.")
                    .font(.caption2).foregroundStyle(.secondary)
                if let recent=autopilot.entries.first {
                    Divider()
                    HStack(alignment:.top,spacing:9) {
                        Image(systemName:recent.action == "allègement" ? "calendar.badge.clock" :
                              recent.action == "à examiner" ? "exclamationmark.circle" : "checkmark.circle")
                            .foregroundStyle(PaceColors.teal)
                        VStack(alignment:.leading,spacing:4) {
                            Text(recent.headline).font(.caption.weight(.semibold))
                            Text(recent.date.formatted(date:.abbreviated,time:.shortened))
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(recent.action == "maintien"
                                 ? "Aucun changement nécessaire selon les données disponibles."
                                 : String(recent.explanation.prefix(165)))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                NavigationLink {
                    ScrollView {
                        LazyVStack(alignment:.leading,spacing:13) {
                            if autopilot.entries.isEmpty {
                                ContentUnavailableView("Aucune décision encore",
                                    systemImage:"clock.arrow.circlepath",
                                    description:Text("Le coach analysera les nouvelles données après activation et synchronisation."))
                            }
                            ForEach(autopilot.entries) { item in
                                PaceCard {
                                    VStack(alignment:.leading,spacing:9) {
                                        HStack(alignment:.top) {
                                            Label(item.action == "allègement" ? "Séance adaptée" :
                                                  item.action == "à examiner" ? "À examiner" :
                                                  "Programme conservé",
                                                  systemImage:item.action == "allègement" ?
                                                      "calendar.badge.checkmark" : "checkmark.shield")
                                                .font(.subheadline.weight(.semibold))
                                            Spacer()
                                            Text(item.date.formatted(date:.abbreviated,time:.shortened))
                                                .font(.caption2).foregroundStyle(.secondary)
                                        }
                                        Text(item.headline).font(.subheadline.weight(.medium))
                                        Text(item.explanation)
                                            .font(.footnote).foregroundStyle(.secondary)
                                            .fixedSize(horizontal:false,vertical:true)
                                        if let evidence=item.evidenceDetails, !evidence.isEmpty {
                                            DisclosureGroup("Données qui étayent la décision") {
                                                ForEach(evidence,id:\.self) { fact in
                                                    Label(fact,systemImage:"checkmark.shield")
                                                        .font(.caption).foregroundStyle(.secondary)
                                                }
                                            }.font(.caption.weight(.semibold)).tint(PaceColors.teal)
                                        }
                                        if let alternative=item.alternativeConsidered {
                                            Group {
                                                Text("Alternative examinée").font(.caption.weight(.semibold))
                                                Text(alternative).font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        if let expected=item.expectedEffect {
                                            Group {
                                                Text("Effet attendu").font(.caption.weight(.semibold))
                                                Text(expected).font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        if let uncertainty=item.uncertainty {
                                            Group {
                                                Text("Limites de l'analyse").font(.caption.weight(.semibold))
                                                Text(uncertainty).font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        if let followUp=item.followUp {
                                            Divider().opacity(0.35)
                                            Label("Observation après la décision",systemImage:"chart.line.uptrend.xyaxis")
                                                .font(.caption.weight(.semibold))
                                            Text(followUp).font(.caption).foregroundStyle(.secondary)
                                        }
                                        if let date=item.sessionDate,
                                           library.approvedAdjustments[date] != nil {
                                            Text("Adaptation du \(date) en vigueur. Tu peux l'annuler dans Programme.")
                                                .font(.caption2).foregroundStyle(PaceColors.teal)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .background(PaceColors.base)
                    .navigationTitle("Décisions du coach")
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Voir toutes les décisions et leurs résultats",
                          systemImage:"clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                }
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
                    Toggle(isOn:$coach.shareDynamicsTimeline) {
                        VStack(alignment:.leading,spacing:3) {
                            Text("Analyse croisée de toutes les courbes")
                            Text("Fréquence cardiaque, allure, puissance, foulée, contact au sol et oscillation, alignés dans le temps. Profils agrégés sur l’iPhone avant envoi à OpenAI, sans GPS. Jusqu'à 120 intervalles.")
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
                VStack(alignment:.leading,spacing:8) {
                    Toggle(isOn:$coach.shareSleep) {
                        VStack(alignment:.leading,spacing:3) {
                            Text("Partager mes durées de sommeil avec ChatGPT")
                            Text("Jusqu’à 14 journées : durées et moyennes, sans heures exactes, stades ni données brutes.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!sleep.monitoringEnabled)
                    if !sleep.monitoringEnabled {
                        Button("Demander l’accès Sommeil à Apple Santé") { sleep.requestAccess() }
                            .font(.caption.weight(.semibold))
                    }
                    Text("Le sommeil n’est envoyé à OpenAI que si ce partage est activé. Une autorisation Apple Santé seule ne suffit pas.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Toggle("Dernier poids renseigné",isOn:$coach.shareWeight)
                Toggle("Tour de taille renseigné et évolution",isOn:$coach.shareWaist)
                VStack(alignment: .leading, spacing: 7) {
                    Toggle(isOn: $coach.shareHealthTrends) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tendances complémentaires Apple Santé")
                            Text("FC au repos, VFC, VO₂ max estimée et mesures corporelles réellement présentes. Résumés sur 56 jours, jamais séries brutes.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!healthSignals.accessRequested)
                    if !healthSignals.accessRequested {
                        Button("Autoriser d'abord ces mesures dans Santé") {
                            Task { await healthSignals.requestAccess() }
                        }
                        .font(.caption.weight(.semibold))
                    }
                    Text("Cette autorisation pour ChatGPT est distincte de l'accès Apple Santé. Une variation isolée ne déclenche pas de modification du programme.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Toggle(isOn:$coach.shareStrengthSets) {
                    VStack(alignment:.leading,spacing:3) {
                        Text("Mes séries de musculation")
                        Text("Répétitions ou durées en secondes, charge si renseignée. Saisies manuelles, jamais déduites de l’Apple Watch.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Toggle("Repas prévus",isOn:$coach.shareNutrition)
                Divider()
                if autopilot.enabled {
                    Label("Le Coach autonome prépare aussi les bilans de sortie automatiquement, avec les données autorisées.",
                          systemImage:"checkmark.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Toggle(isOn:$coach.autoReview) {
                        VStack(alignment:.leading,spacing:4) {
                            Text("Préparer automatiquement un bilan")
                            Text("Prépare un bilan après récupération ; ne modifie jamais le programme sans validation.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!coach.shareRunSummaries)
                }
                Button(showPreview ? "Masquer l’aperçu partagé" : "Voir le résumé sportif partagé") {
                    showPreview.toggle()
                }
                .font(.subheadline.weight(.semibold))
                .tint(PaceColors.teal)
                if showPreview {
                    Text(coach.contextPreview(engine:engine,library:library,journal:journal,profile:athleteProfile,strength:strengthTracker,sleep:sleep))
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

    private func adaptiveReviewCard(_ recommendation:PaceAdaptation) -> some View {
        PaceCard {
            VStack(alignment:.leading,spacing:12) {
                HStack {
                    Image(systemName:recommendation.recommendation == .pause ?
                          "exclamationmark.shield" : "checkmark.shield")
                        .foregroundStyle(PaceColors.teal)
                    Text("Après ta dernière sortie")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Masquer") { adaptiveMonitor.dismiss() }
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(recommendation.headline)
                    .font(.title3.weight(.semibold))
                ForEach(recommendation.reasons,id:\.self) { reason in
                    Text(reason).font(.footnote).foregroundStyle(.secondary)
                }
                if recommendation.recommendation == .requestFeedback {
                    Button {
                        effortWorkoutID = PaceWorkoutID(id:recommendation.workoutUUID)
                    } label: {
                        Label("Noter mon ressenti",systemImage:"pencil.line")
                    }
                    .buttonStyle(.borderedProminent).tint(PaceColors.teal)
                }
                if recommendation.requiresApproval {
                    if let date = recommendation.sessionDate {
                        Text("Séance concernée : \(date)")
                            .font(.caption).foregroundStyle(.secondary)
                        if recommendation.recommendation == .easier,
                           let duration = recommendation.proposedMinutes {
                            Text("Durée proposée : \(duration) min, en endurance facile")
                                .font(.subheadline.weight(.medium))
                        } else {
                            Text("Pause proposée avant la prochaine course. Consulte un professionnel en cas de douleur importante ou persistante.")
                                .font(.footnote)
                        }
                        Button {
                            do {
                                try library.approveAdaptation(recommendation)
                                adaptiveMonitor.dismiss()
                            } catch { coach.error = error.localizedDescription }
                        } label: {
                            Label("Accepter pour cette séance uniquement",
                                  systemImage:"checkmark.circle")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth:.infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(PaceColors.teal)
                    } else {
                        Text("Aucune future course n'est planifiée : il n'y a rien à modifier.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button {
                        effortWorkoutID = PaceWorkoutID(id:recommendation.workoutUUID)
                    } label: {
                        Label("Modifier mon ressenti",systemImage:"square.and.pencil")
                    }
                    .font(.caption.weight(.medium)).tint(PaceColors.teal)
                    Button("Conserver le programme actuel") { adaptiveMonitor.dismiss() }
                        .font(.subheadline).tint(.secondary)
                        .frame(maxWidth:.infinity)
                }
            }
        }
    }

    private var sessionAnalysisCard: some View {
        PaceCard {
            VStack(alignment:.leading,spacing:13) {
                Label("Bilan de mes activités",systemImage:"waveform.path.ecg")
                    .font(.headline)
                if let run = coach.selectedRun(engine:engine) {
                    Menu {
                        Button("Dernière activité") { coach.focusWorkoutID = nil }
                        Divider()
                        ForEach(Array(engine.snapshot.filter { $0.isRun ||
                            ($0.activity_kind == "strength" && coach.shareStrengthSets) }.prefix(12))) { option in
                            Button("\(option.startDate.formatted(.dateTime.day().month().year())) · \(option.cadenceLabel) · \(PaceFormat.duration(option.duration_seconds))") {
                                coach.focusWorkoutID = option.source_uuid
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment:.leading,spacing:3) {
                                Text("Séance sélectionnée")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("\(run.startDate.formatted(.dateTime.day().month().year())) · \(run.cadenceLabel) · \(PaceFormat.duration(run.duration_seconds))")
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
                    if coach.isLoading {
                        Label("Analyse ChatGPT en cours…",systemImage:"clock.arrow.circlepath")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PaceColors.teal)
                    } else if (autopilot.enabled || coach.autoReview) &&
                              coach.report(for:run.source_uuid)?.isLocal == false {
                        Label("Bilan à jour",systemImage:"checkmark.circle")
                            .font(.caption).foregroundStyle(PaceColors.teal)
                    } else if autopilot.enabled || coach.autoReview {
                        Label(coach.report(for: run.source_uuid)?.isLocal == true
                              ? "Bilan local disponible · analyse IA à relancer"
                              : coach.report(for: run.source_uuid) != nil
                                ? "Bilan ChatGPT disponible ci-dessous"
                              : !coach.error.isEmpty
                                ? "Bilan incomplet · relance possible"
                                : coach.newWorkoutAwaitingReview
                                  ? "Nouvelle séance détectée · analyse automatique attendue"
                                  : "Bilans automatiques activés",
                              systemImage:"brain.head.profile")
                            .font(.footnote).foregroundStyle(PaceColors.teal)
                        Button {
                            Task { await coach.analyzeSession(client:client,engine:engine,
                                library:library,journal:journal,profile:athleteProfile,
                                strength:strengthTracker,sleep:sleep) }
                        } label: {
                            Label("Relancer le bilan manuellement",systemImage:"arrow.clockwise")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.bordered).tint(PaceColors.teal)
                        .disabled(!coach.shareRunSummaries)
                    } else {
                        Button {
                            Task { await coach.analyzeSession(client:client,engine:engine,
                                library:library,journal:journal,profile:athleteProfile,
                                strength:strengthTracker,sleep:sleep) }
                        } label: {
                            Label("Analyser cette sortie",systemImage:"sparkles")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth:.infinity).padding(.vertical,10)
                        }
                        .buttonStyle(.borderedProminent).tint(PaceColors.teal)
                        .disabled(!coach.shareRunSummaries)
                    }
                } else {
                    Text("Aucune activité disponible à analyser.")
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
                    Label(report.title,systemImage: report.isLocal ? "iphone" : "checkmark.seal")
                        .font(.headline).foregroundStyle(PaceColors.teal)
                    if let session = engine.workout(id:report.workoutID) {
                        Text("Séance du \(session.startDate.formatted(.dateTime.day().month().year())) · \(PaceFormat.distance(session.kilometers,places:2)) km")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(report.summary)
                        .font(.subheadline).fixedSize(horizontal:false,vertical:true)
                    if let first=report.recommendations.first {
                        Divider()
                        Label(first,systemImage:"arrow.forward.circle")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(PaceColors.teal)
                    }
                    Text(report.trainingImpact)
                        .font(.footnote).foregroundStyle(.secondary)
                    DisclosureGroup("Comprendre l'analyse") {
                        VStack(alignment:.leading,spacing:11) {
                            Text("Observations").font(.subheadline.weight(.semibold))
                            ForEach(report.observations,id:\.self) { line in
                                Text(line).font(.footnote)
                            }
                            if report.recommendations.count > 1 {
                                Text("Autres conseils").font(.subheadline.weight(.semibold))
                                ForEach(report.recommendations.dropFirst(),id:\.self) { line in
                                    Text(line).font(.footnote)
                                }
                            }
                            Text("Limites").font(.subheadline.weight(.semibold))
                            ForEach(report.uncertainties,id:\.self) { line in
                                Text(line).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top,6)
                    }
                    .font(.subheadline.weight(.medium))
                    .tint(PaceColors.teal)
                    if report.isLocal {
                        Text("Bilan local uniquement. Aucun raisonnement ChatGPT disponible.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
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
                    Task { await coach.generate(client:client,engine:engine,library:library,journal:journal,profile:athleteProfile,strength:strengthTracker,sleep:sleep) }
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
                    if coach.shareRunSummaries {
                        let cycle = PaceCyclePlanner.assess(runs:engine.runHistory,
                            notes:coach.shareSessionNotes ? journal.notes : [:],
                            history:coach.acceptedPlans)
                        VStack(alignment:.leading,spacing:5) {
                            Label("Phase observée : \(cycle.phase.rawValue)", systemImage:"chart.line.uptrend.xyaxis")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PaceColors.teal)
                            Text(cycle.reasons.joined(separator:" · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(cycle.eligibleWeeks)/4 semaines avec au moins deux courses · \(cycle.feedbackCoverage)/\(cycle.comparableRuns) ressentis complets")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(PaceColors.surface,in:RoundedRectangle(cornerRadius:14))
                    }
                    let totalEnergy = draft.meals.reduce(0) { $0 + $1.kcal }
                    let totalProtein = draft.meals.reduce(0) { $0 + $1.protein }
                    Text("Nutrition calculée : \(Int((Double(totalEnergy) / 7).rounded())) kcal/j · \(Int((Double(totalProtein) / 7).rounded())) g de protéines/j (estimations)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PaceColors.teal)
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

    private var coachComposer: some View {
        HStack(alignment:.bottom,spacing:11) {
            TextField("Message au coach…",text:$question,axis:.vertical)
                .lineLimit(1...5)
                .textInputAutocapitalization(.sentences)
                .focused($composerFocused)
                .padding(.horizontal,15)
                .padding(.vertical,12)
                .background(PaceColors.surface,in:RoundedRectangle(cornerRadius:19))
                .accessibilityLabel("Écrire un message au coach")
            Button(action:sendCoachMessage) {
                Image(systemName:"arrow.up.circle.fill")
                    .font(.system(size:35))
                    .foregroundStyle(PaceColors.teal)
                    .frame(minWidth:44,minHeight:44)
            }
            .disabled(coach.isLoading ||
                      question.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Envoyer au coach")
        }
        .padding(.horizontal,16)
        .padding(.vertical,11)
        .background(.regularMaterial)
        .overlay(alignment:.top) { Rectangle().fill(.primary.opacity(0.06)).frame(height:0.5) }
    }

    private func sendCoachMessage() {
        let text=question.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty,!coach.isLoading else { return }
        question=""
        composerFocused=false
        Task {
            await coach.chat(text,client:client,engine:engine,library:library,
                             journal:journal,profile:athleteProfile,
                             strength:strengthTracker,sleep:sleep)
        }
    }

    private var chatSection: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Text("Conversation")
                    .font(.title3.weight(.semibold))
                Spacer()
                if !coach.conversation.isEmpty {
                    Menu {
                        Button("Effacer la conversation",role:.destructive) {
                            coach.clearConversation()
                        }
                    } label: {
                        Image(systemName:"ellipsis")
                            .frame(width:44,height:44)
                    }
                    .accessibilityLabel("Options de la conversation")
                    .tint(.secondary)
                }
            }
            if coach.conversation.isEmpty {
                VStack(alignment:.leading,spacing:9) {
                    Label("Que veux-tu savoir ?",systemImage:"bubble.left")
                        .font(.headline)
                    Text("Pose une question sur une séance, ta progression ou le programme. Les bilans validés arriveront ici automatiquement.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical,16)
            } else {
                ForEach(coach.conversation.suffix(100)) { message in
                    let isMine=message.speaker == "Moi"
                    HStack(alignment:.bottom,spacing:9) {
                        if isMine { Spacer(minLength:36) }
                        VStack(alignment:.leading,spacing:5) {
                            if !isMine {
                                Text("Coach")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(PaceColors.teal)
                            }
                            Text(message.text)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal:false,vertical:true)
                        }
                        .padding(14)
                        .background(isMine
                                    ? PaceColors.teal.opacity(0.12) : PaceColors.surface.opacity(0.78),
                                    in:RoundedRectangle(cornerRadius:18))
                        if !isMine { Spacer(minLength:16) }
                    }
                    .accessibilityElement(children:.combine)
                }
            }
            if coach.isLoading {
                HStack(alignment:.bottom,spacing:9) {
                    ProgressView().controlSize(.small)
                    if coach.streamingReply.isEmpty {
                        Text("Le coach écrit…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Text(coach.streamingReply)
                            .font(.subheadline)
                            .textSelection(.enabled)
                            .fixedSize(horizontal:false,vertical:true)
                    }
                    Spacer(minLength:0)
                }
                .padding(13)
            }
            if !coach.error.isEmpty {
                Label(coach.error,systemImage:"exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(13)
                    .frame(maxWidth:.infinity,alignment:.leading)
                    .modifier(PaceGlassCardSurface(cornerRadius:14))
                    .accessibilityAddTraits(.updatesFrequently)
            }
            Color.clear.frame(height:1).id("coach-chat-end")
        }
    }

}
