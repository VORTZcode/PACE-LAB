# PACE LAB V4.3 — Mode musculation recentré sur l'effort

## Évolution de l'interface
- Sur l'exercice actif, le repère technique principal est affiché directement.
- Les schémas et instructions détaillées sont regroupés sous « Voir le mouvement et les erreurs à éviter », ce qui évite d'occuper la totalité de l'écran pendant une séance.
- Conservation intégrale des champs de séries, charges, répétitions et durées en secondes.

## Récupération
- Lorsqu'une série intermédiaire est validée, un compte à rebours facultatif de récupération apparaît en fonction de la durée prescrite pour l'exercice.
- Il utilise une date d'échéance réelle et TimelineView plutôt qu'une minuterie permanente : le temps écoulé est recalculé lors du retour dans l'application.
- L'utilisateur peut ignorer le décompte, prolonger son repos ou lancer une nouvelle série à son rythme.
- Pas de notification, de vibration ou d'alarme automatique ; le repos n'est pas imposé.
- Le repos n'apparaît pas après la dernière série d'un exercice.

## Vérification
- Tous les tests de contrat et validations précédentes + contrat V4.3 : succès.
- Compilation iOS signée, installation et lancement sur iPhone physique : succès.
- Journal des séries et archive Santé conservés.
- Contrôle tactile des gestes et de la minuterie encore à réaliser par l'utilisateur.

Cette version privilégie une expérience de séance moins encombrée ; elle n'introduit aucune interprétation médicale.
