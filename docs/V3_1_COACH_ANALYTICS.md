# PACE LAB V3.1 — Coach sportif contextualisé

## Évolutions
- Modèle ChatGPT choisi conservé entre les lancements. Si aucun modèle n’était encore mémorisé, le choix privilégie `gpt-6.1-sol` **uniquement si cette option est proposée par le compte**.
- Bilan de course distinct du renouvellement du programme : mesures disponibles, conseils prudents et incertitudes explicites. Le bilan ne modifie aucune séance ni aucun repas.
- Sélection de la sortie à étudier parmi les douze plus récentes, avec accès contextuel depuis la fiche d’activité.
- Analyse locale de charge : volume de course sur quatre semaines et comparaison visuelle des deux dernières périodes de sept jours. Ce n’est pas un score de santé ni un diagnostic.
- Trois nouvelles autorisations facultatives **désactivées par défaut** : profil cardiaque agrégé minute par minute sur une seule course (max 120 minutes), moyennes de dynamique de course et récupération, notes personnelles et effort ressenti.
- Paramètres de confidentialité repliables et aperçu en clair des données sportives envoyées.
- Bilan de séance stocké localement avec protection du fichier iOS, consultable, effaçable et associé à son activité.
- Si l’analyse automatique est autorisée, elle prépare un bilan après une nouvelle course et la fenêtre de récupération, **pas** une nouvelle semaine d’entraînement automatique. L’approbation humaine reste requise pour tout programme ou menu.

## Confidentialité
Les données sources (échantillons cardiaques, itinéraires GPS, historique HealthKit) sont conservées localement. Pour chaque requête, PACE LAB transmet uniquement le résumé correspondant aux cases activées à OpenAI, avec `store=false` dans la requête Responses API. Il ne faut **pas** affirmer que les données partagées restent exclusivement sur l’iPhone. Aucun itinéraire GPS n’est inclus dans les requêtes du coach.

Les notes personnelles ne sont jamais transmises si l’utilisateur n’active pas expressément leur option de partage. Une déconnexion de ChatGPT n’efface pas la bibliothèque Santé locale.

## Validation et limites
- Tests PWA, HealthKit, V2, V3 et V3.1, validation de bilan Swift sur données fictives, compilation Xcode réelle, installation sur iPhone.
- Vérifier manuellement la première requête de bilan depuis le compte connecté, notamment l’accès au modèle sélectionné, la limite de consommation et la réponse JSON.
- Les délais de rafraîchissement HealthKit en arrière-plan ne sont pas garantis par iOS.
- Les comparaisons de fréquence cardiaque, d’allure et de récupération sont descriptives : pente, température, fatigue, état d’hydratation et caractère fragmenté des mesures peuvent influencer les résultats.
- Les propositions ChatGPT ne sont pas des diagnostics ; l’utilisateur conserve la validation de chaque modification.
