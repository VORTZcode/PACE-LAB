# PACE LAB V3.2 — Coach natif, profil athlète et planification fondée sur les données

## Principe

Le Coach n'est pas une seconde application ChatGPT : c'est un parcours sportif natif. Lorsqu'un compte est connecté, l'utilisateur voit directement ses objectifs, les données observées et trois sections iOS : Ma séance, Mon programme, Discuter. Les contrôles « Compte et données » et « Mon profil sportif » sont accessibles depuis la barre de navigation. L'écran d'accueil présente un accès compact au Coach après la prochaine séance.

Le changement de programmation doit suivre les données disponibles, expliquer son fondement et rester sous contrôle humain. Aucune adaptation automatique n'est mise en œuvre sans acceptation.

## Mémoire de ChatGPT et profil permanent

L'autorisation d'utiliser l'abonnement ChatGPT ne donne pas accès aux conversations, aux mémoires, aux fichiers ou aux instructions de cette conversation. Il n'existe pas de lecture implicite de cette mémoire par OAuth.

V3.2 propose un profil **local et modifiable** : objectif de course à long terme, objectif corporel, motivation, fréquence de course/renforcement, contraintes matérielles, préférences nutritionnelles, restrictions sportives éventuellement déclarées. Les suggestions initiales proviennent des objectifs discutés précédemment, présentés comme un **brouillon à confirmer**. Une sauvegarde et un consentement de partage sont nécessaires pour qu'ils servent à une requête de coach.

Le fichier `pace-athlete-profile.json` réside dans le conteneur privé de l'application sur iPhone avec protection iOS. L'utilisateur peut effacer son profil.

## Contexte mesurable pour les programmes

Le moteur reçoit, lorsque l'utilisateur partage les résumés HealthKit :
- les quatre périodes de sept jours et la charge des 28 derniers jours ;
- le nombre de courses, la distance totale, la durée totale, la sortie la plus longue ;
- la qualité descriptive des données (historique insuffisant, partiel, descriptif) ;
- les huit dernières activités résumées, la récupération, et éventuellement les mesures détaillées/notes si l'utilisateur autorise ces catégories ;
- le programme actuellement en place, et le profil confirmé s'il est partagé.

Il ne fabrique ni seuil lactique, ni zone cardiaque, ni prédiction clinique, ni kilométrage quand les données sont absentes.

## Garde-fous avant adoption

Tout projet de semaine doit contenir sept séances/journées consécutives et quatorze repas, une explication des choix et des notes sur les mesures utilisées. Chaque course doit indiquer une distance prévisionnelle et une catégorie d'effort. En plus des contrôles déjà présents (repos, nutrition, dates), PACE LAB vérifie :
- la cohérence des distances par rapport à la sortie la plus longue du mois ;
- les variations importantes du volume hebdomadaire ;
- l'absence de séances de course intenses consécutives ;
- la fréquence de course et le maintien d'un renforcement adapté au profil confirmé.

Les limites numériques sont des **seuils conservateurs de revue**, pas des seuils médicaux garantis ni un algorithme démontré de prévention des blessures. Une alerte bloque l'adoption automatique, et le coach doit formuler une meilleure proposition. Les calories et protéines proposées sont étiquetées comme estimations.

## Fondements consultables dans l'application

- 2026 ACC Scientific Statement, principes FITT, individualisation et progression : https://www.jacc.org/doi/10.1016/j.jacc.2026.09.008
- Oliveira et al., 2024, méta-analyse des distributions d'intensité ; conclusions dépendantes du niveau des athlètes : https://pubmed.ncbi.nlm.nih.gov/38717713/
- 2025, méta-analyse renforcement/régime : protection partielle de la masse maigre : https://pubmed.ncbi.nlm.nih.gov/40909191/
- 2025, cohorte de 5 205 coureurs, associations entre sauts de distance sur une séance et blessures : https://pubmed.ncbi.nlm.nih.gov/40623829/
- 2022, revue systématique : aucune règle universelle de progression hebdomadaire de 10 % : https://pmc.ncbi.nlm.nih.gov/articles/PMC9528699/

Aucune de ces publications ne valide individuellement un programme proposé par une IA ou ne garantit un résultat de performance.

## Confidentialité

Les données Apple Santé résident dans le conteneur iOS. Les mesures choisies pour analyse et le profil confirmé partagé quittent l'appareil vers OpenAI lors d'une requête IA. Les jetons sont conservés dans le trousseau iOS et aucune donnée personnelle n'est envoyée à GitHub. Les catégories de partage peuvent être désactivées. L'application ne doit jamais être décrite comme « 100 % hors ligne » lorsque ChatGPT est utilisé.

## Vérifications

- Compilation SwiftUI native et signée, installation iPhone sans changement d'identifiant de bundle.
- Contrats de sécurité OAuth, interface et HealthKit.
- Test dynamique Swift sur entraînements artificiels pour vérifier la validation positive et négative du moteur de charge.
- Confirmation au toucher par l'utilisateur des trois vues, de l'éditeur de profil, des consentements et de la première proposition avec le modèle choisi.

## À approfondir

Pour aller au-delà d'une personnalisation prudente, les prochaines versions doivent intégrer des tests répétés et comparables (séances de référence avec terrain, météo, intensité, RPE, conditions), la tolérance de charge, la réponse physiologique individuelle sur plusieurs semaines et des ajustements validés avec le sportif. Les seules moyennes Apple Watch ne permettent pas de conclure à la progression sans ces conditions.
