# PACE-LAB V5.3 — Changer uniquement quand cela a du sens

## Principe : stabilité par défaut, intervention motivée

ChatGPT produit une analyse de la dernière course dans le contexte longitudinal sur 56 jours, des éventuelles notes de ressenti et du sommeil autorisé. Le modèle n'écrit pas dans le programme : il recommande **conserver, alléger ou examiner**. L'application est responsable des vérifications et de l'application de tout changement.

## Modification du contrat de décision IA

La réponse structurée inclut obligatoirement :
- `reason` : pourquoi une action est envisagée ;
- `evidence` et `evidenceIDs` : mesures et identifiants contrôlables ;
- `alternativeConsidered` : ce qui serait préférable ou non dans le statu quo ;
- `expectedEffect` : effet attendu et observable à la prochaine séance, sans promesse de résultat ;
- `uncertainty` : informations manquantes et limites de l'interprétation.

Une décision incomprise ou mal formée ne déclenche aucune adaptation.

## Preuves indépendantes — règles conservatrices

Les données disponibles sont regroupées en trois domaines. Deux indicateurs issus de la même déclaration ne sont **jamais** deux preuves indépendantes.

- `subjective` : effort perçu élevé (8 à 10 sur 10) OU gêne légère déclarée (1 à 3 sur 10), avec une gêne significative (au moins 4/10) exclue de toute adaptation automatique.
- `training` : comparaison de volume sur 28 jours par rapport aux 28 précédents, **uniquement** lorsque les huit semaines sont suffisamment renseignées. Une variation supérieure à 40 % est un indicateur interne de réexamen, pas un seuil scientifique de blessure.
- `sleep` : comparaison de la durée moyenne récente au sommeil propre de l'athlète, avec au moins quatre journées récentes et dix sur quatorze, un recul d'au moins 45 minutes et une moyenne récente inférieure à sept heures. Aucune décision fondée sur une seule mauvaise nuit. Les montres sont imparfaites pour mesurer la durée et les phases.

L'allègement n'est envisageable que si deux **domaines distincts** sont documentés, que GPT cite exactement les identifiants correspondants, et que la décision passe toutes les autres limites existantes (pas de séance ajoutée, durée réduite d'environ 20 % au maximum, pas de modification d'un jour passé, pas de modification sans autorisation).

Un précédent changement automatique dans les sept jours bloque tout nouvel ajustement. Cette durée est un choix prudent de stabilité logicielle, **pas une règle clinique validée**.

## Préserver le contrôle

- Une révocation de l'autorisation de partage, un changement de programme ou une nouvelle donnée de séance reçue pendant la requête ChatGPT annule la tentative.
- Le journal indique désormais les données invoquées, l'alternative examinée, l'effet attendu et les incertitudes.
- À l'issue d'une séance adaptée, l'application recherche la sortie correspondante dans Apple Santé et ajoute une observation descriptive : distance et effort déclaré s'ils existent, ou absence d'enregistrement **sans conclure qu'il n'y a pas eu d'entraînement**.
- L'utilisateur peut consulter l'historique et revenir sur une adaptation dans Programme.

## Vérification

- `tests/autopilot-fixture.swift` couvre les domaines indépendants, les cas sans données, le manque d'historique de sommeil, la déduplication des preuves IA, la gêne importante, la fenêtre et le délai de stabilité.
- `tests/coach-v53-significance-contract.mjs` vérifie les nouveaux échanges IA, le filtre de preuves, la boucle d'observation et l'enregistrement de l'interface.
- Ces règles sont **des mécanismes de prudence à évaluer** : elles n'établissent pas scientifiquement qu'une réduction de durée améliore les performances.
- L'application ne garantit pas que HealthKit réveillera iOS immédiatement ; l'analyse est reprise lors des événements autorisés. L'activation du Coach autonome reste facultative.

## Prochaine étape scientifique

Calibrer les critères selon l'historique réellement observé, les séries de musculation et le RPE sur plusieurs semaines, évaluer le coût des fausses adaptations et comparer les résultats avec les semaines où le programme n'a pas changé. La performance de ChatGPT ne doit pas être jugée au nombre de modifications, mais à la pertinence des décisions et à la stabilité de la progression.
