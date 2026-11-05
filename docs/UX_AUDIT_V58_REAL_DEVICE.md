# PACE-LAB V5.8 — Audit sur iPhone réel et améliorations du parcours

## Constat et méthode
Le 5 novembre 2026, captures contrôlées de PACE-LAB depuis un iPhone physique relié au Mac. Une première capture a montré une autre application : elle a été immédiatement exclue de l'audit et supprimée. Ensuite, des vues diagnostiques temporaires ont ouvert le graphique et la séance du jour avec les vraies données Apple Santé. Les captures contenant des données privées restent hors de GitHub. Toutes les routes diagnostiques ont été retirées avant la compilation finale.

## Graphique cardio
- L'ancien graphique privilégiait une ligne brute et une couleur, avec des axes mal lisibles et des libellés occupant une partie de la zone utile.
- La vue montre désormais les FC moyenne et maximale mesurées, une courbe rouge et un remplissage léger, la durée réelle sur l'axe X, une plage des mesures, la valeur et l'instant sélectionnés.
- Échelles temporelles et cardiaques explicites ; aucune interpolation à travers les interruptions de mesure ; aucune valeur fictive pendant les trous.
- Une capture a confirmé que la graduation supérieure était coupée. Correction de l'espacement supérieur, puis nouvelle capture confirmant son affichage.
- Zones cardiaques personnelles non déduites sans étalonnage.

## Programme ↔ activité réelle
- Le jour du programme affiche désormais en premier les activités réellement enregistrées dans Apple Santé, et non après toute la liste d'exercices.
- Chaque activité peut être ouverte pour consulter ses mesures : heure, durée, distance, allure et FC si disponible.
- L'association repose sur la date locale et la catégorie d'activité ; une coïncidence ne vaut pas validation de toutes les consignes.
- Les activités restent visibles même si le jour a été marqué terminé ; plusieurs activités de même type ne sont pas associées automatiquement de façon ambiguë.
- Une capture sur le vrai jour programmé confirme la présence et l'accès à l'activité enregistrée.

## Coach et intelligence de l'analyse
- Contexte explicite de la séance prévue versus réalisée, et jusqu'à trois activités antérieures de distance voisine quand elles existent.
- Analyse demandée : faits mesurés, comparaisons pertinentes, hypothèses, incertitudes, puis une recommandation avec son effet observable attendu.
- Les séances manquées sont traitées comme des absences, jamais comme des efforts ; aucun rattrapage punitif.
- Le bilan de ChatGPT ou le bilan local de secours peut se lire directement dans la fiche d'activité. Le rapport intégral reste accessible via Coach.
- Les ajustements automatiques restent soumis aux garde-fous antérieurs ; l'analyse de séance seule ne modifie pas le programme.

## Validation et limites
- 32 tests de contrat + validation du programme/PWA/confidentialité réussis.
- Compilation Xcode pour l'iPhone physique signée : réussite.
- Installation et lancement de l'application normale, sans mode diagnostic : réussite.
- Un cycle réel complet HealthKit → ChatGPT → rapport réussi → adaptation éventuelle → séance suivante reste à valider.
- iOS ne garantit pas l'exécution immédiate d'une analyse lorsque l'application est suspendue.
