# PACE-LAB V5.0 — Coach longitudinal et boucle de suivi des programmes

## Livré

- Analyse locale des **56 derniers jours**, découpés en huit fenêtres de sept jours, avec comparaison des volumes sur deux périodes de 28 jours uniquement lorsque les données sont suffisantes (au moins quatre sorties réparties sur trois semaines dans chaque période et un volume de référence exploitable).
- Séances Apple Santé dédoublonnées par identifiant et filtrage des dates futures, durées non positives et distances invalides ; les séances manquantes restent des informations inconnues.
- RPE et gêne **déclarés par l'utilisateur** pris en compte : signal prioritaire en cas de gêne importante déclarée pendant les sept derniers jours, puis analyse de plusieurs efforts difficiles rapprochés. Aucun score clinique ou diagnostic.
- Accueil avec les quatre volumes hebdomadaires les plus récents, qualité de l'historique et proportion de ressentis complets.
- Profil proposé : **3 courses + 2 musculation**. Les profils personnels déjà enregistrés ne sont pas écrasés ; leurs fréquences peuvent être modifiées dans Mon profil sportif.
- Les propositions de programmes par IA ne peuvent plus dépasser les fréquences confirmées. Une réduction des séances doit être expliquée ; plusieurs sorties intenses sont bloquées sur une semaine de trois courses ou moins.
- ChatGPT, lorsque l'utilisateur a autorisé le partage des résumés sportifs, reçoit le contexte longitudinal disponible, les incertitudes et la dernière proposition acceptée. Les notes RPE/douleur ne sont partagées que si leur option de partage est activée.
- Après adoption explicite d'une proposition, PACE-LAB conserve en local le nombre de courses, de séances de renforcement et le volume prévisionnel, avec la référence des 28 jours précédents.
- **À l'issue des sept jours**, l'app compare la proposition aux courses observées dans Santé et indique leur nombre et leur distance, sans conclure automatiquement à une réussite ou à un échec. Les données sont stockées dans Application Support, sous protection iOS ; les douze dernières propositions acceptées sont conservées.

## Validations

- 26 tests JavaScript existants ou nouveaux.
- Test exécutable en Swift avec données simulées pour les huit fenêtres, la déduplication, les mesures invalides, les ressentis, l'incertitude et le calcul de comparaison.
- Compilation signée vers iPhone physique, schéma PaceLabCompanion.
- Aucun accès réseau requis pour les règles locales. Les appels ChatGPT conservent les autorisations et contrôles déjà existants.

## Limitations connues

- La comparaison observé/prévu dépend des séances réellement synchronisées avec Santé ; une séance non enregistrée n'est pas forcément une séance non effectuée.
- Les séries de musculation sont enregistrées dans le suivi existant mais leur progression par exercice et charge n'est pas encore reliée à ce bilan de plans acceptés.
- Une tendance de kilomètres n'est pas une prédiction de performance ni un estimateur validé du risque de blessure.
- iOS ne garantit pas une analyse continue en arrière-plan ; les bilans se mettent à jour lors des événements et synchronisations pris en charge.
- L'IA propose ; les règles locales contrôlent ; l'utilisateur approuve. Aucun changement silencieux du plan.

## Prochain niveau

- Boucle explicite de feedback sur les recommandations acceptées/refusées, avec motifs et résultats plusieurs semaines après.
- Détection descriptive de la progression en musculation par exercice (charge, séries, RIR quand saisi) et récupération déclarée, puis contrôle des évolutions proposées.
- Agrégation personnalisable de sommeil, FC au repos et HRV avec consentement séparé, contrôles de qualité et sans score de récupération pseudo-scientifique.
- Évaluation sur données de plusieurs semaines pour réduire les recommandations instables et tester les corrections avant diffusion.