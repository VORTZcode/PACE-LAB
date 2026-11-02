# PACE-LAB V5.4 — Coach autonome fiable et audit compréhensible

## Pourquoi cette version

Une modification de programme n'est justifiée que si elle sert l'objectif de progression et s'appuie sur plusieurs observations réellement disponibles. La stabilité reste le résultat normal. Les règles locales sont des **garde-fous conservateurs**, pas des prédicteurs de blessure ou une preuve d'efficacité physiologique.

## Changements

### Vie privée et sécurité découplées

- Un ressenti douloureux significatif (note de gêne d'au moins 4/10) **interdit localement** une modification automatique, même si le partage des notes avec ChatGPT est désactivé.
- Cette information de gêne n'est **pas envoyée à ChatGPT** si l'utilisateur n'a pas autorisé le partage des notes. Le veto est pris sur l'iPhone, avec une explication locale si nécessaire.
- Le changement d'état « gêne significative oui/non » fait partie de la clé de contrôle anti-doublon, mais ni l'intensité exacte ni le commentaire privé n'y figurent.
- Les changements de données ou de permissions pendant l'appel IA peuvent annuler l'action.

### Données longitudinales de meilleure qualité

- Le signal lié à la charge sur 28 jours nécessite désormais une comparaison exploitable sur 56 jours, au moins 6 courses récentes, une répartition sur au moins 3 périodes hebdomadaires et au moins 15 km sur les 28 jours.
- Une seule semaine de volume inhabituel ne doit plus être considérée comme une tendance longue indépendante du ressenti.
- Les seuils de qualité (6 courses, 3 semaines, 15 km) sont des **critères de prudence internes**, à recalibrer à partir d'observations réelles ; ils ne sont pas des seuils scientifiques prédictifs.
- Le sommeil ne peut contribuer à une adaptation que si son historique est assez complet et comparé à la moyenne personnelle. Jamais sur une seule mauvaise nuit.

### Journal des décisions lisible

- Compte et données → Coach autonome : synthèse de la décision la plus récente.
- « Voir toutes les décisions et leurs résultats » : consultation des 30 entrées conservées.
- Chaque entrée distingue les données invoquées, l'alternative envisagée, l'effet attendu, les incertitudes et, lorsqu'elle existe, l'observation de la sortie qui a suivi.
- Le programme affiche les adaptations et leur réversibilité. Les archives des versions antérieures restent lisibles grâce aux champs optionnels du journal.
- On évite d'afficher deux mécanismes concurrents de recommandation lorsque le Coach autonome est activé.

## Périmètre des modifications

Le seul changement automatique reste l'**allègement de la durée de la prochaine course**, dans les limites déjà vérifiées (jusqu'à ~20 %), en conservant les objectifs globaux. Aucune augmentation de charge, aucun ajout de séance, aucun remplacement complet des sept jours et quatorze repas sans validation explicite.

## Vérifications

- `tests/coach-v54-refinements-contract.mjs` : veto local, confidentialité, plan non réécrit, journal complet, couvertures longitudinales.
- `tests/autopilot-fixture.swift` : signaux réellement indépendants, sommeils manquants, repli stable, intervalle de sept jours et charge répartie.
- Contrats V3.x–V5.3, calculs de sommeil et compilation iPhone physique.

## Limites

- L'application ne peut pas garantir une exécution continuelle lorsque iOS la suspend ; les callbacks HealthKit et notifications dépendent des possibilités de l'OS.
- Le contrôle sur données simulées et le lancement sur iPhone ne prouvent pas le bon fonctionnement d'un vrai cycle Apple Watch → GPT → programme → séance suivante.
- Les variations de FC, distance, sommeil ou RPE ne suffisent pas à établir une relation de cause à effet.
- Un suivi réel sur plusieurs semaines est nécessaire pour mesurer l'utilité et réduire les adaptations inutiles.
