# PACE-LAB V6.1 — Continuité du Coach et ergonomie de l'accueil

Date : 5 novembre 2026.

## Correctif demandé

La carte « Bilan de séance disponible » était visuellement une surface interactive, mais seul le bouton « Lire le bilan » réagissait. La carte entière est maintenant un seul bouton SwiftUI, sans commande imbriquée, avec intitulé et aide VoiceOver. Les autres cartes importantes du Coach utilisent le même composant et profitent du comportement.

## Ce que le Coach savait faire en V6.0

- Récupérer les activités Apple Santé admissibles (données en fonction des autorisations), les rapprocher du programme et les comparer à des séances de distance similaire.
- Fournir les tendances 28 et 56 jours, les valeurs de sommeil et les notes de ressenti selon les autorisations.
- Transmettre les objectifs de course, de composition corporelle et de motivation **uniquement** si le profil de l'athlète avait été enregistré et explicitement partagé.
- Générer un bilan par séance récente admissible, l'afficher et le publier brièvement dans la conversation.
- Réexaminer une adaptation prudente avec des règles locales de sécurité, sans accroître automatiquement la charge.

**Lacune V6.0 :** les réponses successives ne réutilisaient pas explicitement les conclusions de bilans précédents. Les analyses exploitaient l'historique chiffré, mais ne démontraient pas une continuité des recommandations elles-mêmes. Les seules données corporelles transmises étaient le dernier poids (sur autorisation), pas le tour de taille.

## V6.1

- Chaque nouveau bilan GPT valide conserve les catégories de données dont le partage était autorisé lors de sa production.
- Jusqu'à trois bilans antérieurs peuvent être repris comme **interprétations passées à revérifier**, pas comme des faits physiologiques, à condition que **toutes leurs autorisations d'origine soient encore actives** et que l'activité source soit encore trouvable. Les bilans anciens sans preuve d'autorisation ne sont pas retransmis.
- Une révocation ou un changement de consentement pendant une analyse empêche l'enregistrement du bilan issu de cet appel.
- Une option de partage explicite et désactivée par défaut autorise, si souhaité, le dernier tour de taille saisi et une mesure de comparaison datant d'au moins deux semaines ; aucune estimation de masse grasse ou de masse musculaire n'en est déduite.
- En présence d'un profil enregistré mais non partagé, un accès clair propose de rendre les objectifs disponibles au Coach.
- Le prompt de bilan demande de confronter la recommandation précédente aux nouvelles données, sans faire de l'objectif 10 km à 15 km/h l'allure immédiate d'entraînement.

## Limites

- Les comptes rendus antérieurs à V6.1 restent consultables sur l'iPhone mais ne sont **pas automatiquement retransmis** au modèle, faute d'un historique fiable de consentement.
- Le moteur ne « réentraîne » pas le modèle à partir de chaque séance. Il fournit un contexte structuré et un historique contrôlé ; le raisonnement reste probabiliste et susceptible d'erreur.
- La progression corporelle ne peut pas être confirmée par le seul poids ou tour de taille ; pas de diagnostic de graisse abdominale ni de masse musculaire à partir de ces deux mesures.
- La récupération automatique dépend des autorisations, des activités récentes et des possibilités d'exécution d'iOS, sans garantie de tâche en fond à chaque instant.
- Les adaptations automatiques restent limitées aux allègements justifiés, jamais à une augmentation non validée de charge.

## Vérifications

Contrats JavaScript, trois fixtures Swift et compilation iOS signée ; validation en conditions réelles d'une nouvelle séance Apple Watch à réaliser.
