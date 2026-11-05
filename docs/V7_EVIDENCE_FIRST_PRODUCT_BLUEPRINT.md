# PACE-LAB V7 — Vision produit et contrat de livraison

Statut : préparation sur branche séparée. Pas de compilation Xcode ni déploiement sur iPhone à cette étape.

## Positionnement

PACE-LAB ne doit pas être un petit clone du réseau social Strava. Sa promesse : après chaque séance Apple Watch, montrer ce qui a été réalisé, établir ce que les mesures prouvent ou non, puis expliquer la prochaine action, sans demander à l'athlète de piloter une intelligence artificielle.

Trois expériences doivent devenir excellentes :
- **Séance** : beau tracé réel, chiffres importants, bilan compréhensible, détails accessibles.
- **Progression** : volume, régularité, comparaison à effort suffisamment proche, incertitudes explicites.
- **Coach** : analyse automatique traçable, décision prudente, suivi réel des conséquences.

## Travail implémenté sur la branche V7

1. **Moteur déterministe de progression** (PaceProgressEvidence.swift). Il exclut les séances futures et les mesures invraisemblables, déduplique par UUID HealthKit, compare deux fenêtres de 28 jours, recherche une ancienne course de distance voisine dans les 7 à 120 jours, et signale quand la FC moyenne ne permet pas de juger de la comparabilité.
2. **Nouvel écran Progression** : objectif personnel confirmé, volume 28 jours vs 28 jours précédents, nombre de séances et semaines actives, comparaison prudente d'allure ; absence de preuve explicitement affichée.
3. **Historique d'activités** : mise en avant de la dernière course et aperçu du tracé GPS réellement accessible ; une seule lecture HealthKit ciblée, pas une requête par ligne ; carte entière ouvrable ; pas de fausse trace si GPS absent.
4. **Coach** : contexte enrichi de faits calculés localement uniquement lorsque le partage des résumés sportifs est autorisé ; états clairs pour rapport ChatGPT réussi, rapport local de secours, traitement en cours ou absence de résultat.
5. **Préparation qualité** : jeu de données Swift synthétique, tests de contrat et script de prévalidation sur Mac, sans installation ni signature.

Le moteur déterministe ne doit pas devenir une deuxième IA. Il fournit une couche mesurable et vérifiable avant toute interprétation.

## Architecture cible

| Niveau | Responsabilité | Invariant |
| --- | --- | --- |
| Apple Santé | Import des données autorisées | Identifiant, date, source, unité et état de synchronisation |
| Normalisation | Déduplication, filtrage des valeurs aberrantes | Aucune donnée absente inventée |
| Evidence Engine | Volume, régularité, comparaisons, récupération | Calcul reproductible, conditions de comparabilité |
| Decision Engine | Maintenir, alléger, demander une validation | Sources, incertitudes, possibilité de retour arrière |
| ChatGPT | Expliquer, contextualiser, dialoguer | Hypothèses distinctes des mesures ; pas d'action prétendue |
| Programme | Prochaine action cohérente avec le plan | Pas de changement gratuit ni compensation punitive |
| Journal de décisions | Effet attendu et observation ultérieure | Une décision suivie, confirmée ou invalidée |

Les conclusions précédentes du Coach sont des hypothèses à réexaminer, pas des mesures nouvelles. Un bon système peut confirmer, nuancer ou contredire ses anciennes recommandations.

## Santé : couverture future, sans faux accès

La situation actuelle du dépôt comprend les workouts, une partie de la FC et de la récupération, les distances et les calories, des dynamiques de course sur autorisation complémentaire, les routes GPS et un module de sommeil distinct.

Il faudra créer un catalogue de données HealthKit pertinents et vérifier concrètement :
- **Cardiovasculaire** : FC au repos, variabilité cardiaque SDNN, FC de marche, VO2 max estimé, unités et provenance.
- **Récupération** : durée et régularité du sommeil, couverture des nuits, respiration, température du poignet si disponible.
- **Corps** : poids HealthKit, tour de taille saisi, graisse corporelle et masse maigre uniquement lorsqu'une source les mesure réellement.
- **Activité globale** : pas, étages, minutes d'exercice, énergie, charge hebdomadaire et cohérence avec les séances.
- **Dynamique de course** : puissance, vitesse, longueur de foulée, temps de contact, oscillation, pauses, route et dénivelé si mesuré.

Le souhait « tout Santé » ne doit pas devenir un transfert de dossier médical complet. Une catégorie est seulement exploitée si elle est utile à une décision sportive, techniquement accessible, autorisée et correctement interprétée. L'utilisateur doit voir les catégories partagées avec l'IA et pouvoir révoquer le partage. HealthKit ne révèle pas toujours explicitement si l'utilisateur a refusé la lecture : l'interface ne doit pas inventer un statut.

La route GPS brute et les localisations précises restent sur l'appareil. Un export public futur devra masquer les points sensibles, départ et arrivée inclus.

## Ergonomie visée

### Aujourd'hui
Une prochaine action, une seule information Coach prioritaire, un accès direct à la dernière séance. Les erreurs de service restent visibles dans un endroit identifiable sans encombrer la page.

### Activités
La dernière sortie est une expérience visuelle. L'historique est lisible et filtrable. Le chargement des itinéraires reste ciblé et sans dizaines de requêtes concurrentes.

### Séance
Premier écran : distance, durée, allure, vraie carte. Ensuite : « ce que cette séance montre ». Les graphiques, intervalles, récupération, détails de musculation et comparaison technique sont des niveaux secondaires clairement organisés. La prise de ressenti doit demander le moins de gestes possible.

### Progression
Volume et régularité en premier, puis séances comparables. Plus tard : tendances sur 3 à 6 mois, performances à distances repères et suivi du renforcement. Une baisse de FC moyenne isolée n'est pas une preuve d'amélioration physiologique. Aucun pourcentage de graisse n'est inféré du poids et du tour de taille seuls.

### Coach
Dialogue naturel ; états « en attente / en cours / réussi / à reprendre » ; accès aux raisons de chaque conseil ; décisions réversibles. iOS ne garantit pas une exécution continue quand l'app est suspendue.

## Critères de livraison impératifs

| Lot | Preuve exigée avant installation |
| --- | --- |
| Anti-crash | 50 ouvertures successives de fiches réelles, autorisation GPS accordée puis refusée, aucune perte locale |
| Progression | Fixtures : invalides, doublons, absence de FC, distances différentes, fenêtres calendaires |
| Carte héroïque | Tracé exact, absence honnête si non disponible, clic complet, VoiceOver et petits écrans |
| Coach | Une séance : un bilan réel ou une erreur traçable ; pas de faux succès ; rattrapage après reprise |
| Vie privée | Consentement et révocation ; aucun GPS précis dans la requête de bilan |
| Plan | Séance manquée != séance faite ; pas d'augmentation de charge non validée |
| Flyover | Demi-tours, arrêts, GPS bruité, contrôle des vitesses et fluidité sur vrai iPhone |
| Publication | Tests Swift, contrats, compilation Xcode, validation du parcours complet |

Prévalidation lorsque le Mac sera accessible : commande bash scripts/preflight-v7.sh.

Le succès d'un test statique ne prouve **pas** une interaction SwiftUI correcte ; une compilation ne prouve **pas** qu'un bouton ou qu'une autorisation Santé fonctionne sur le téléphone.

## Ordre des prochains chantiers

P0 — fiabilité des imports et analyses, instrumentation, tests de parcours, données longitudinales.
P1 — fiche de séance hiérarchisée, suivi de progression sur plusieurs mois, statistiques réellement comparables, catalogue Santé.
P2 — contrôle caméra Flyover, performance MapKit, effort de saisie musculation/nutrition.
P3 — exports, réalisations sportives, éventuelles fonctions sociales uniquement si elles servent l'athlète.

## Limites exactes de cette préparation

Les modifications V7 sur GitHub sont **du code en attente de compilation et de tests appareils**, et non une mise à jour installée. La récupération de données Santé supplémentaires n'est **pas encore implémentée**. Il ne faut ni fusionner ni déployer cette branche avant l'exécution des prévalidations sur Mac et de la recette iPhone.