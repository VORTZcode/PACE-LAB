# PACE-LAB V8 — Audit comparatif Strava, modifications et validation

**Date : 5 novembre 2026.** Application iOS native SwiftUI, branche `feature/v8-strava-depth-progress` dérivée de V7. Ce document distingue ce qui est observé, ce qui est implémenté et ce qui reste à prouver.

## Méthode et limites
- Strava : recherche documentaire dans le Centre d'aide officiel, notamment les fiches 2026 sur la progression, les meilleurs efforts, le journal, les activités, les segments et les parcours correspondants. Captures publiques étudiées ; **pas d'accès authentifié ni de parcours complet réalisé dans l'application Strava**. Une analyse fonctionnelle documentaire n'est pas un audit d'usage exhaustif.
- PACE-LAB : inspection du code V7, tests de compilation et fixtures Swift ; installation sur l'iPhone connecté, lancement et capture de son écran d'accueil. Cela ne suffit pas à valider les taps, les permissions et la totalité des sous-écrans.
- Capture réelle de l'accueil : réalisée localement sur le Mac, conservée hors dépôt afin de ne pas publier les données d'entraînement privées.

## Pourquoi Strava paraît plus fini
1. **Information immédiatement exploitable.** Une activité donne d'emblée une histoire lisible, des chiffres, sa carte et l'accès aux analyses approfondies.
2. **Exploration concrète.** Les graphiques de volume et de performance ne sont pas de simples illustrations : les semaines, entraînements et segments sont des entrées de navigation.
3. **Mémoire sportive.** L'historique est retrouvable et les performances peuvent être comparées sur plusieurs horizons, par distance, par segment ou par itinéraire répété.
4. **Boucle de retour.** Records et progrès fournissent une raison claire de rouvrir l'application, indépendamment de la prochaine séance.
5. **Hiérarchie et fluidité.** Les principales actions sont découvrables sans devoir ouvrir de longs panneaux ; les transitions et les états de chargement participent à la finition.
6. **Écosystème.** Exploration cartographique, réseau social, clubs, défis, segments et kudos créent de la valeur supplémentaire. Ces fonctions ne sont pas toutes pertinentes pour un coach personnel privé.

**Observation V7 sur iPhone** : titre de page large, héros « prochaine séance » occupant la majorité de la première vue, action principale très imposante, analyse ChatGPT en deuxième carte, dernière activité sous le premier écran. La couleur secondaire du cartouche d'analyse manque de saillance en mode sombre. Le Liquid Glass est présent, mais l'ordre et la densité des informations restent à rationaliser.

## Matrice de livraison et reste à faire

| Axe | Strava (vérification documentaire) | PACE-LAB constaté avant V8 | Action V8 | Prochain seuil |
|---|---|---|---|---|
| Recherche historique | Recherche d'activités et journal filtrable | Type / année / 25 résultats par lot, pas de recherche texte | **Implémenté** : recherche texte par date, type, distance ; tri chronologique garanti | Recherche multi-critères combinable, favoris et tags |
| Graphiques de volume | Périodes sélectionnables, drill-down vers les séances | Volumes mensuels sans inspection au toucher | **Implémenté** : sélection mensuelle et accès aux courses | Comparatif plage à plage et explications en contexte |
| Régularité | Vue journal d'entraînement et séries hebdomadaires | Fenêtres factuelles 28 jours, sans historique hebdomadaire navigable | **Implémenté** : 12, 26, 52 semaines, distance, temps, sessions ; semaines vides explicites | Distinguer temps de course / musculation dans un calendrier multi-sports |
| Fiabilité des agrégations | Comparaisons historiques orientées activité | Moteur de dédoublonnage des cours intégral | **Implémenté** : semaines et drill-down basés sur exactement les mêmes runs validés | Contrôles avec milliers d'activités et fuseaux / DST / changement de calendrier |
| Meilleurs efforts | 400m–50km, chronos réels et records | Approximations honnêtes par activité entière de distance voisine | **Non implémenté** | Calcul exact sur trace chronométrée qualifiée + traitement des pauses / GPS bruyant ; ne jamais labelliser RP un résultat approximatif |
| Graphes par activité | Analyse d'entraînement, splits, segments et données biométriques | Graphes FC/puissance/cadence, intervalles 5min, comparaison de courses | **Conservé** | Synchronisation d'un curseur commun entre graphes, séries manquantes et tableaux accessibles |
| Parcours GPS | Cartes plein écran, découverte, matched activities | Tracé MapKit + flyover natif | **Conservé** | Rejouer demi-tours/arrêts réels, réutilisation de parcours, choix d'itinéraires |
| Entraînement / coach | Analyse et commentaires de sortie | Coach GPT + bilans locaux + adaptation prudente | **Conservé** | Journal vérifiable décision → application → résultat, historique 3 à 6 mois |
| Journal de force | Strava générique pour le renforcement | Séries, charges, temps, RPE, liens Apple Watch | **Conservé** | Programme généré et exercice libre, progression par mouvement, meilleures séries |
| Nutrition | Hors cœur Strava | Programme et repas déclarés datés | **Conservé** | Portions, substitutions et consommations vérifiables |
| Qualité visuelle | Navigation et analyses denses | Héros volumineux, information importante sous le pli | **Modifié** : héro plus compact, durée + distance sur dernière activité, meilleure visibilité du label Coach | QA sur petit écran, iOS clair, Dynamic Type et VoiceOver |
| Social, défis, segments | Différenciation Strava | Absent par choix produit | **Non prioritaire** | À étudier seulement si l'utilisateur souhaite une communauté ; ne pas retarder le coach privé |

## Contrat de vérité
- Les séries hebdomadaires utilisent le validateur `PaceProgressEvidence.validRuns` : UUID HealthKit unique, séance non future, date parseable, distance, durée et allure plausibles.
- Les semaines sans entraînement doivent afficher zéro, pas une séance artificielle.
- Le détail d'une semaine utilise le même validateur que l'agrégat.
- Une variation d'allure ou de fréquence cardiaque seule **ne prouve pas** un gain physiologique.
- Aucun GPS brut, aucune coordonnée et aucune donnée Santé supplémentaire ne sont envoyés à ChatGPT par cette V8.

## Validation effectivement exécutée
- Prévalidation V7 sur état initial : 39 fichiers de contrats, fixtures Swift, build Simulator **PASS**.
- Après premières modifications V8 : **40 fichiers de contrats**, fixtures Swift, build Simulator **PASS**.
- Build appareil iOS signé avec le profil local existant : **PASS**.
- Installation sur l'iPhone connecté : **PASS** ; lancement de l'application : **PASS**, processus constaté actif ; accueil capturé.
- Contrôle des parcours interactifs dans l'application Strava et tests de tous les sous-écrans PACE-LAB sur l'iPhone : **NON réalisés**. Ne pas les inscrire comme validés.
- Le profil de développement local réutilisé expire le **8 novembre 2026** ; l'environnement Xcode connecté n'avait pas de compte permettant son renouvellement automatique. Une nouvelle signature sera nécessaire après expiration.

## Prochains travaux impératifs, par ordre
**P0 — fiabilité produit :** vérifier sur l'iPhone les interactions de recherche, les barres des semaines et des mois, les écrans sans données, l'ouverture répétée de fiches, VoiceOver/Dynamic Type, les autorisations Santé révoquées, la reprise hors réseau et l'absence de crash. Renouveler le profil iOS avant le 8 novembre.

**P1 — profondeur sportive :** vrais best efforts sur GPS chronométré avec gestion rigoureuse des pauses, répétitions d'itinéraire, graphes synchronisés, calendrier multi-sports, suivi longitudinal des décisions du Coach et validation automatique seulement lorsqu'une mesure fiable existe.

**P2 — finition :** hiérarchie des états vides et chargements, instrumentation des temps d'ouverture, budget de performances sur 300+ séances, tests de transitions et revue d'accessibilité sur plusieurs appareils. Envisager ensuite export et partage sécurisé.

## Sources publiques
- https://support.strava.com/fr/articles/15401618-resume-graphique-des-progres
- https://support.strava.com/fr/articles/15402077-journal-d-entrainement
- https://support.strava.com/fr/articles/15401661-comment-fonctionne-le-mode-meilleurs-efforts-lors-d-une-course-a-pied-sur-strava
- https://support.strava.com/fr/articles/15401943-affichage-des-activites
- https://support.strava.com/fr/articles/15401900-comment-consulter-les-resultats-de-mes-segments-sur-strava
- https://support.strava.com/en-us/articles/15401955-how-do-i-view-my-matched-activities

## Correctif urgent V8.1 — navigation Activités après retour terrain

Retour réel de l'utilisateur : défilement de l'onglet Activités extrêmement lent et interactions presque bloquées après installation de la V8. **Cela invalide tout statut « expérience iPhone validée ».**

Régression de performance isolée dans les sources :
- la recherche reconstruisait les dates ISO, chaînes localisées, filtres, tableaux et tri du parcours d'activités depuis des propriétés calculées, évaluables pendant les recompositions SwiftUI ;
- la grande carte de l'activité en vedette utilisait un `MKMapView` rendu vivant dans la même vue que la liste et lançait une requête HealthKit GPS, coûteuse lorsque l'utilisateur défile ;
- le conteneur de 25 lignes appliquait un matériau Liquid Glass à toute la liste, avec rendu de matériau hors-écran.

Correctifs appliqués : index des champs de recherche et du tri **une fois par révision de l'historique Santé**, filtrage uniquement aux changements explicites de recherche/type/année, liste simplifiée, retrait du MapKit embarqué sur le bandeau de liste ; parcours GPS conservé dans la fiche détaillée. Le groupe de lignes utilise désormais un arrière-plan opaque au lieu du verre complexe. Les données personnelles locales et autorisations n'ont pas été effacées.

Ces causes sont fondées sur l'examen du code, pas sur un profilage Instruments mesuré du bug. La validation de la fluidité par balayage réel sur l'iPhone **reste à faire**, même lorsque la compilation et l'installation réussissent. Pas de promesse de 60 fps sans mesure.
