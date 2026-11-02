# PACE-LAB V5.2 — Coach autonome (première boucle réelle)

## Ce qui est automatisé

Le mode **Coach autonome**, désactivé par défaut et activable dans Coach → Compte et données, transforme les nouvelles données Apple Santé (séances, sommeil, ressentis et séries de musculation) en **décisions ChatGPT structurées**, puis en adaptations locales contrôlées. Une fois activé, l'utilisateur n'a plus à ouvrir le Coach pour lancer chaque analyse.

1. Apple Santé actualise l'historique ; le sommeil se met à jour lorsque ses données sont disponibles.
2. Le moteur agrège uniquement les catégories dont le partage avec ChatGPT a été autorisé : compte connecté, résumés de course, profil confirmé, sommeil si autorisé, ressentis si autorisés et séries si autorisées.
3. ChatGPT retourne une décision JSON `maintain`, `easier` ou `review`, avec justification et éléments observables. L'IA ne peut pas écrire directement dans le programme.
4. Les règles Swift déterministes valident la demande. **Seul l'allègement de la prochaine course** peut être exécuté sans validation répétée. Il faut au moins deux signaux de prudence parmi un RPE élevé, une gêne déclarée légère, une variation mesurée du volume et une série de nuits courtes suffisamment couverte.
5. La durée de la course est réduite d'environ 20 % au maximum, avec minimum de 15 minutes ; le jour reste une course facile. Aucun ajout de séance, augmentation de charge, changement de nutrition, remplacement du programme complet, suppression générale du plan ni décision sur douleur significative.
6. Les décisions sont conservées dans un journal local chiffré par la protection des fichiers iOS ; elles sont visibles dans les réglages du Coach. Les changements sont aussi visibles et réversibles dans Programme.
7. Si les notifications iOS sont autorisées, une adaptation appliquée ou une situation à examiner peut produire une notification locale.

## Garde-fous

- Activation volontaire de ce mode, distincte du partage des données Santé et du consentement aux requêtes ChatGPT.
- Pas d'action sans compte ChatGPT opérationnel, historique sportif partagé et profil confirmé.
- Dernière course datant de moins de sept jours et terminée depuis plus de trois minutes ; prochaine séance de course à venir et non déjà adaptée.
- Données absentes = inconnues ; pas de fausse mesure de récupération, ni diagnostic basé sur le sommeil.
- Douleur déclarée d'au moins 4/10 : **aucune adaptation silencieuse**, examen manuel recommandé.
- Requêtes dédupliquées par identifiant de séance, note, sommeil, progrès de musculation et révision des données cardio ; délai minimal de 15 minutes entre tentatives.
- Une décision sans justification correcte, ou rejetée par les règles locales, **ne modifie pas** le plan.
- Historique persistant des 30 dernières décisions et notifications facultatives.

## Limites

- **iOS ne garantit aucune analyse immédiate lorsqu'il suspend l'application.** Les callbacks HealthKit sont best effort et les analyses reprennent au prochain réveil autorisé ou à l'ouverture de l'app. Un service serveur serait nécessaire pour une garantie d'analyse indépendante de l'iPhone.
- L'accès ChatGPT doit pouvoir répondre avec les autorisations du compte ; un échec réseau conserve le plan et reporte la tentative.
- Ce n'est pas encore un agent autonome autorisé à créer/remplacer sans validation l'ensemble des sept jours et quatorze repas. Le premier périmètre automatisé concerne les ajustements conservateurs de la course ; les programmes complets générés par IA restent à valider.
- Les textes et décisions ChatGPT ne sont pas des diagnostics. L'effort ressenti, la douleur et les métriques HealthKit ont des limites.
- Les nouvelles fonctions sont testées par contrats et par un programme Swift exécutable de cas adverses ; un essai avec les vraies données de l'Apple Watch reste nécessaire pour valider le déclenchement réel sur l'appareil.

## Validation

- `tests/autopilot-fixture.swift` compile avec `PaceAutopilotGuard.swift` ; teste refus sans données, gêne significative, répétition, mauvais type de séance, nuit peu couverte et acceptation d'un allègement ~20 % lorsqu'il est justifié.
- `tests/coach-v52-autopilot-contract.mjs` vérifie l'intégration SwiftUI/HealthKit/ChatGPT, les autorisations et la persistance.
- `xcodebuild` sur iPhone physique puis installation via devicectl.

## Prochain incrément

- Génération automatique encadrée d'une nouvelle semaine **uniquement à la fin du cycle**, sans dérive quotidienne, en validant la fréquence confirmée de 3 courses + 2 musculation et les 14 repas. Un déploiement complet doit bénéficier de tests longitudinaux et d'un retour arrière fiable.
- Détection des séances de musculation terminées avec comparaison par exercice, séries et charges réellement saisies.
- Notifications plus lisibles et outil de suivi de l'efficacité réelle des décisions sur 4 à 8 semaines.
