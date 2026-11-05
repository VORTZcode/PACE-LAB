# PACE-LAB V7 — Journal de développement (hors appareil)

**État : branche de code en pull request brouillon, pas d'installation iPhone.**
Branche active iPhone inchangée : feature/native-v4-4-exercise-photos.
Branche de développement : feature/v7-evidence-first-ux-audit.
PR : https://github.com/VORTZcode/PACE-LAB/pull/22

## Travail réellement préparé

| Domaine | Contenu | Limite |
| --- | --- | --- |
| Course | Fenêtres de 28/56 jours, déduplication UUID, comparaisons homogènes, repères de sorties complètes proches de 3, 5 et 10 km | Pas de temps intermédiaire ni record de segment ; conditions non contrôlées |
| Activités | Dernière course mise en avant et aperçu de la véritable trace GPS | À vérifier sur appareil et avec autorisations manquantes |
| Fiche | Hiérarchie améliorée, données détaillées repliables, carte de bilan entièrement cliquable | Accessibilité et navigation à tester |
| Santé | Premier lecteur optionnel de FC repos, VFC SDNN, VO₂ max estimée, FC de marche, poids, masse grasse et masse maigre, dans la limite des mesures présentes ; stockage protégé local | Plusieurs catégories encore non intégrées ; lecteur non testé sur l'iPhone |
| Coach | Calculs déterministes introduits dans son contexte autorisé ; tendances Santé supplémentaires avec deuxième consentement ; états fiables en cours / attente / reprise / confirmé | Pas de garantie d'exécution IA quand iOS suspend l'application |
| Programme | Association explicite course–séance prévue ; statut confirmé, déclaré manuellement, manqué, candidat ou ambigu | Une correspondance ne garantit pas le respect de l'intensité prescrite |
| Musculation | Séries, répétitions, charges et durées groupées par exercice | Pas de preuve de gain musculaire ; programmes GPT externes non entièrement reconstruits |
| Nutrition | Déclaration datée par recette et repas, distincte des calories prévues | Portions non mesurées ; anciens coches non datées non reconduites arbitrairement |
| Qualité | Tests de contrats, fixtures Swift, validation Linux et Xcode à lancer sur GitHub | Aucune compilation Xcode ou recette iPhone encore validée |

## Règles de conception

1. Une modification d'allure ou de FC isolée ne prouve pas une amélioration physiologique.
2. Un entraînement enregistré le même jour qu'un entraînement prévu ne prouve pas l'adhérence au programme.
3. Un repas marqué consommé n'établit pas la portion ingérée, ni les apports exacts.
4. Les données GPS et mesures personnelles ne doivent être transmises au Coach que selon des règles explicites ; le GPS brut n'est pas envoyé dans les prompts.
5. Le Coach doit distinguer mesures, interprétations, décisions et inconnues.
6. Les changements de charge automatiquement autorisés restent conservateurs, réversibles et journalisés.

## Validation requise avant installation

Prévalidation macOS : bash scripts/preflight-v7.sh.

Validation réelle sur iPhone :
- Cinquante ouvertures de séances avec permissions GPS accordées/refusées et tracés présents/absents.
- Replay 3D sur véritables demi-tours et pauses, quatre vitesses, aucune fermeture inattendue.
- Nouvelle séance Apple Watch : synchronisation -> analyse IA réussie ou état d'échec -> éventuelle décision prudente -> journal.
- Panne réseau et reprise : pas de doublon, pas de succès inventé.
- Plusieurs activités le même jour : aucune association arbitraire au programme.
- Déclaration d'une séance manquée distincte d'une validation manuelle.
- Données Santé présentes/absentes/refusées, accès et partage avec l'IA séparés.
- Changement de semaine : aucune fausse consommation de repas provenant d'une autre date.
- Force : exercices chronométrés et chargés, doublons et données invalides.
- VoiceOver, Dynamic Type, petit écran et transitions.

## Problèmes restant à développer

- Plus grande couverture Santé (activité quotidienne, respiration, température du poignet), provenance, fraîcheur et granularité.
- Mémoire sportive réellement longitudinale sur plusieurs mois, au-delà des quelques bilans récents, avec évaluation des décisions passées.
- Réévaluation automatique scientifiquement fondée du plan dans le temps, sans changements arbitraires.
- Progression en musculation y compris les exercices générés par un nouveau programme GPT.
- Nutrition : ajustement des portions, ingrédients réellement consommés et métadonnées fiables.
- Meilleurs temps de passage basés sur de véritables splits mesurés, plutôt que des approximations de distances.
- Validation intégrale des parcours UX et publication d'une version signée.

## État de compilation

Le premier échec GitHub Actions était dû à un test obsolète codant en dur le libellé 5.9. Le test a été corrigé. Les exécutions suivantes restaient en attente de runner lors de la préparation ; tant que les tests et la compilation ne sont pas verts, la V7 n'est **pas prête à installer**.

La PR demeure en brouillon jusqu'à réussite des portes de validation.