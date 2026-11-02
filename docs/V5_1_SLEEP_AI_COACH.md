# PACE-LAB V5.1 — Sommeil Apple Santé et création du programme par ChatGPT

## Objectif et état réel
PACE-LAB laisse ChatGPT interpréter les faits autorisés, construire un **programme de sept jours**, proposer **14 repas détaillés** midi et soir, puis expliquer les décisions. Le programme reste une proposition contrôlée par les règles locales et doit être accepté explicitement avant tout remplacement.

## Sommeil depuis HealthKit
- Nouvelle autorisation **lecture Sommeil** distincte des séances et mesures de course, demandée depuis Coach ou Réglages.
- Seuls les échantillons HealthKit `sleepAnalysis` des stades endormis sont comptabilisés : les catégories `inBed` et `awake` ne sont jamais incluses dans le total de sommeil.
- Regroupement par fenêtre locale **midi à midi** pour rattacher les périodes traversant minuit à la même journée, sans diagnostic de trouble du sommeil.
- Les intervalles chevauchants sont fusionnés. Les sources concurrentes (Apple Watch, applications de sommeil) ne sont **pas additionnées** : une source est retenue par fenêtre de 24 heures.
- Résumé local jusqu'à 14 journées : durée par nuit, moyenne récente et moyenne des sept jours précédents **uniquement à partir de trois nuits enregistrées** dans la période, nombre de nuits disponibles et nuits de moins de six heures. Ce sont des statistiques descriptives, pas des seuils de préparation à l'entraînement.
- Actualisation à l'ouverture de l'app, au retour au premier plan et, si iOS le permet, lors des notifications HealthKit ; rafraîchissements courants limités pour ne pas surcharger la synchronisation.
- Si aucune donnée n'est accessible, afficher explicitement « absente ou autorisation indisponible ». **Ne pas interpréter l'absence comme zéro heure de sommeil.**

## Confidentialité
- La lecture des données Santé est demandée séparément par iOS.
- Un deuxième interrupteur **Partager mon sommeil avec ChatGPT** est désactivé par défaut.
- Le modèle reçoit uniquement des données de sommeil **agrégées localement** : nuits et durées, moyennes et couverture. Aucune heure brute d'endormissement, aucune trajectoire GPS, aucun segment brut ni stade de sommeil détaillé.
- Le résumé ne quitte jamais l'iPhone tant que le partage avec ChatGPT n'a pas été volontairement activé.
- Les sources de sommeil sont consultées en mémoire ; aucun historique brut du sommeil n'est ajouté aux sauvegardes disque du projet.

## Programme intelligent
- Sources disponibles sous contrôle de consentement : historique de course sur huit semaines, tendance de volume, fréquence cardiaque et mesures de foulée selon les options, RPE, gêne déclarée, séries de musculation, objectif sportif et nutrition, sommeil agrégé, historique des plans approuvés.
- ChatGPT produit un projet structuré avec **sept séances/jours** et **quatorze repas**. Chaque jour d'entraînement doit préciser l'objectif, les consignes, l'intensité, la durée et une indication de distance pour la course ; les repas contiennent des ingrédients, des quantités et une préparation.
- Vérification locale de la structure, de la fréquence course/musculation confirmée, des volumes et intensités inhabituels, et de la qualité minimale des descriptions. Les incohérences empêchent l'adoption plutôt que d'être « réparées » silencieusement.
- Aucune affirmation clinique à partir de la mesure de sommeil, ni changement de programme sur une unique mauvaise nuit.

## Limites explicites
- Les montres grand public estiment imparfaitement le sommeil et les phases. Le coach **ne dispose pas d'un score de récupération validé** et ne peut pas inférer précisément la fatigue.
- iOS ne garantit pas le déclenchement des mises à jour en temps réel ni en arrière-plan.
- La synchronisation ne prouve pas que toutes les nuits sont présentes ou que l'accès en lecture a été autorisé.
- L'envoi de résumés à OpenAI dépend d'un compte connecté et des catégories autorisées.
- Aucun programme ne remplace les conseils d'un professionnel lorsque douleurs persistantes ou autres symptômes importants.

## Tests
- `tests/sleep-fixture.swift` : union des segments, sources doublonnées, nuit traversant minuit, état manquant, résumé privé.
- `tests/coach-v51-sleep-contract.mjs` : autorisations, contrôle de partage, inclusion du contexte IA, création de sept jours et quatorze repas.
- Test Xcode sur iPhone physique. Le test d'autorisation HealthKit doit être terminé dans l'interface iPhone après installation ; le code ne peut pas accepter les permissions iOS au nom de l'utilisateur.
