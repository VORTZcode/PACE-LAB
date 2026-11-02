# PACE LAB 4.0 — Fondations de l'expérience

## Première étape effectivement implémentée
- Système visuel centralisé : marges d'écran, espacements, rayons de carte, hauteurs de lignes et étiquette éditoriale (« eyebrow ») réutilisable. Titres de section avec trait d'accessibilité adapté.
- Accueil reconstruit autour d'une **seule séance prioritaire** et de son bouton « Ouvrir ma séance ». Sur une séance de musculation prévue, la progression des séries est visible immédiatement, sans ouvrir la fiche.
- Dernière activité réellement enregistrée, y compris musculation, désormais accessible depuis l'accueil. Auparavant, la dernière course pouvait masquer un renforcement plus récent.
- Statistiques en second niveau : 7 jours et mois en cartes compactes, accès vers les analyses dédiées, Coach mis en évidence une seule fois.
- Programme : page d'ouverture plus neutre, carte du jour mise en évidence dans les sept jours, avec un accès direct aux détails. Les statuts et séries enregistrées restent dans le flux.
- Renforcement : réduction de la redondance avant les exercices ; détail des consignes disponible dans l'exercice actif, séries cochées comme en V3.9, unités en secondes ou répétitions conservées, associations Apple Watch inchangées.
- Activités : filtre « Muscu » autonome en plus de Course, Marche et Tout.
- Progrès : suppression d'une carte de simple promesse « Analyse en construction », remplacée par une mise en garde contextualisée.

## Non modifié
- Pas de réinitialisation ni de migration des données privées ou du compte ChatGPT.
- Aucune modification du programme de 7 jours ou des objectifs enregistrés.
- Pas de réorganisation destructive des cinq onglets : leur architecture doit être validée en test utilisateur avant fusion.
- Les graphiques et le Liquid Glass de V3.9 restent préservés.

## Validation
- Tous les tests existants et smoke tests passent (assertions de navigation actualisées uniquement lorsque la nouvelle UX remplace un ancien libellé).
- Build iOS signé réussi.
- Installation directe sur l'iPhone et lancement réussis, journal musculaire (2 Ko) et archive Santé (4,3 Mo) conservés.

## Restant avant une V4 finale
- Vérifier la nouvelle hiérarchie en conditions réelles et l'accessibilité (VoiceOver, gros caractères, clair/sombre).
- Évaluer le mode musculation avec une seule main, les animations et l'enchaînement automatique.
- Repenser les parcours Progrès/Nutrition/Coach et les cinq onglets avec des tests avant un changement majeur de navigation.
- Concevoir une synthèse longitudinale croisant mesure, récupération et ressenti sans annoncer de conclusions non étayées.

Il s'agit explicitement des **fondations V4.0**, pas d'une certification exhaustive du produit.
