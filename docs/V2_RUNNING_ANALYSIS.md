# PACE LAB 2.2 — analyse avancée de la course

## Objectif
La fréquence cardiaque et la récupération sont déjà importées depuis Apple Santé. Cette branche ajoute la vitesse, la puissance, la longueur du pas, le temps de contact au sol et l'oscillation verticale, uniquement si l'Apple Watch les a enregistrées. Aucune donnée personnelle ne figure dans GitHub.

## Autorisations explicites
Depuis les Réglages ou la fiche de course, l'utilisateur peut autoriser la lecture de la télémétrie. Une demande HealthKit réussie ne signifie pas que tous les types de données sont autorisés. Une mesure absente reste indisponible.

## Fiche de course
- Graphique Swift Charts avec sélection tactile : Cardio, Allure, Puissance, Foulée, Contact au sol, Oscillation verticale.
- Toutes les valeurs viennent d'échantillons Apple Santé, avec unités cohérentes.
- Moyennes simples des échantillons, pas nécessairement pondérées par le temps.
- Cadence dérivée de la vitesse et longueur de pas moyennes, explicitement étiquetée ESTIMATION.
- Tranches de 5 minutes calculées localement (pas les tours Apple ni des kilomètres intermédiaires).
- Comparaison descriptive avec une course précédente de distance similaire (±15 %) et notes RPE; sans interprétation causale.
- Récupération cardiaque conservée sur trois minutes, séparée de la courbe pendant l'effort.

## Conservation et migration
Les nouveaux champs du modèle sont optionnels; les sorties V2.1 restent lisibles. L'enrichissement se fait par lots de 15 courses à chaque synchronisation au premier plan. Le curseur HealthKit, l'historique des séances et le journal local sont préservés. Les données de course ne partent vers aucun serveur.

## Vérifications
Tests validation, smoke, HealthKit et interface native, compilation Xcode puis validation sur iPhone de l'autorisation et des graphiques. Les permissions doivent être confirmées par l'utilisateur sur iPhone. Les mises à jour iOS en arrière-plan n'ont pas de délai garanti.

## Limites
Les graphiques de vitesse utilisent les échantillons effectivement présents, et la cadence affichée est un calcul indicatif. Les comparaisons ne neutralisent ni terrain, ni météo, ni fatigue; elles ne sont pas un diagnostic physiologique. Cartographie GPS et vrais splits kilométriques seront des développements distincts.
