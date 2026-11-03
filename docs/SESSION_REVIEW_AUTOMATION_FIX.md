# PACE-LAB — Correctif des bilans automatiques après course

## Symptôme observé sur iPhone

- Apple Santé a synchronisé une course et affiche les métriques de sommeil.
- L'écran Coach indique « Nouvelle sortie disponible pour le bilan » et propose encore une action manuelle « Analyser cette sortie ».
- L'analyse peut échouer avec le message général « Le bilan proposé manque de précautions ou de données ».

## Diagnostic du code

1. Le message provenait de `PaceCoachSessionReport.extract`, qui exige un JSON complet : titre, synthèse, 1 à 6 observations, 1 à 5 recommandations, 1 à 5 incertitudes et une conséquence sur l'entraînement. Une réponse ChatGPT vide ou incomplète pour une rubrique était rejetée, sans indiquer laquelle.
2. Le déclenchement `beginAutomaticReview` était désactivé lorsque le mode Coach autonome était activé, alors que le moteur autonome était principalement chargé d'examiner les ajustements prudents du programme. La détection de nouvelles courses pouvait donc rester visible sans produire automatiquement le compte rendu de séance.
3. Les deux options de génération automatique étaient présentées comme indépendantes, sans expliquer que l'activation du mode autonome devait également couvrir l'analyse des nouvelles sorties.

## Correctifs

- Les erreurs de validation indiquent désormais **quelle rubrique manque** : observations, recommandations, incertitudes, synthèse ou conséquence sur le programme.
- Lorsque la première réponse contient un bilan incomplet, une **seconde génération au maximum** est tentée, avec le même contexte déjà autorisé et une consigne explicite de ne jamais inventer les mesures absentes. Le validateur reste strict : aucun bilan incomplet n'est accepté et aucune séance n'est modifiée sur cette base.
- Le consentement « Coach autonome » autorise aussi la génération automatique des bilans de course. Le choix séparé « Préparer automatiquement un bilan » reste proposé lorsque le mode autonome est désactivé.
- L'application enchaîne l'analyse de la nouvelle course et le réexamen autonome du programme plutôt que de laisser deux appels IA concurrents.
- Les tentatives sont déclenchées à l'actualisation Santé, au premier plan, lors de l'activation du mode autonome ou de l'autorisation de connexion, sans garantir le réveil immédiat sous iOS.
- L'écran Coach affiche **bilan en cours**, **bilan disponible**, **analyse automatique activée** ou **bilan incomplet**, avec un bouton secondaire de relance. Le bouton manuel principal reste disponible en mode non automatique.

## Garanties conservées

- L'absence de données ne devient ni une mesure inventée ni une conclusion médicale.
- Les autorisations de partage préexistantes sont toujours nécessaires.
- L'analyse d'une sortie n'applique pas directement une modification de la semaine.
- Les adaptations de séance restent soumises au moteur indépendant de contrôle local et à ses règles de stabilité.
- En cas de nouvel échec, les détails signalent les rubriques manquantes. Une nouvelle tentative manuelle reste possible.

## Validation et limite actuelle

- Le validateur Swift du bilan a été compilé et testé avec des exemples synthétiques : bilan correct, observations vides, incertitudes vides, effet sur le programme absent et JSON invalide.
- Les contrats de non-régression sont ajoutés dans `tests/coach-v56-automatic-session-contract.mjs` et `tests/session-report-fixture.swift`.
- **À compiler et tester sur iPhone réel :** le Mac de développement était hors ligne lors de l'application du correctif. Ce code est publié sur la branche de développement, mais **n'est pas installé sur le téléphone** tant que le Mac ne se reconnecte pas et qu'une nouvelle compilation Xcode n'est pas lancée.

## Vérification de bout en bout sur iPhone

1. Vérifier que le compte ChatGPT est connecté et que les résumés sportifs sont autorisés.
2. Activer le mode Coach autonome dans les réglages du Coach.
3. Synchroniser une nouvelle course et observer la génération du bilan sans action manuelle.
4. Confirmer qu'une réponse incomplète conduit à une tentative de correction, puis à un bilan conforme ou à un message précisant la rubrique manquante.
5. Vérifier qu'aucune modification du programme n'est appliquée sans les preuves exigées par les garde-fous existants.
