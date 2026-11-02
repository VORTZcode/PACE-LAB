# PACE LAB V3.9 — Audit de lisibilité, fiabilité graphique et Liquid Glass

## Écrans couverts
Accueil, Activités (courses, marche et renforcement), Programme et exercices, Progression et composition corporelle, Nutrition, Coach, détails de la course et tableaux de tranches de cinq minutes.

## 1. Graphique du renforcement
**Problème constaté dans le code :** l'axe X utilisait l'index brut des points cardiaques, pas leur temps. Le stockage HealthKit conserve une fenêtre allant jusqu'à cinq minutes après la séance pour pouvoir calculer la récupération ; la courbe de renforcement incluait cette fenêtre comme si elle appartenait à l'effort. Cela peut donner des graduations trompeuses ou un rendu mal réparti.

**V3.9 :** calcul de l'axe sur les minutes réellement écoulées depuis le début de l'activité. Seules les mesures incluses entre ses dates de début et de fin, avec une FC valide, sont tracées. Les valeurs sont triées, et les interruptions de plus de deux minutes sont coupées plutôt que reliées artificiellement. La courbe se termine à la dernière mesure ; une absence en fin de séance est explicitement annoncée. Axes en minutes et bpm, domaine Y autour des valeurs disponibles. Les mesures de récupération restent conservées dans Santé pour leur objectif propre, sans être tracées comme des mesures pendant l'effort.

**Validation :** test Swift autonome avec valeurs synthétiques : dates inversées, une mesure hors séance avant/après, une mesure invalide, interruption, fin sans données, série complète, formats ISO8601 fractionnaires. Toutes les assertions réussies. Pour la dernière activité réelle, une vérification locale privée a montré que des mesures hors plage existaient, ce qui confirme la pertinence du filtrage. Les données privées n'ont pas été intégrées au dépôt.

## 2. Courbes de course
**Avant :** les séries longues étaient réduites en prenant un point tous les N échantillons ; des pics brefs pouvaient être cachés et des interruptions reliées visuellement. L'axe mentionnait « minutes d'effort », bien que les positions des échantillons soient fondées sur l'heure écoulée.

**V3.9 :** tri chronologique, validation de la plage de chaque capteur, séparation des ruptures, réduction à environ 320 points maximum par courbe en préservant les minima et maxima de petits groupes temporels ainsi que les extrémités. Axe X « Minutes écoulées », axe Y avec unité réelle (bpm, min/km, W, m, ms ou cm). Lorsqu'une allure est sélectionnée, l'affichage indique « m:ss /km » et rappelle qu'une valeur plus faible signifie une course plus rapide.

**Attention :** réduction visuelle ne signifie pas réduction de l'historique Santé. Une courbe décimée est descriptive ; les mesures ne permettent pas à elles seules de déduire une cause physiologique.

## 3. Graphiques de progression et de poids
- Volume mensuel en kilomètres : axe Y « km » et origine zéro conservée pour les barres.
- FC moyenne des dernières courses : unité « bpm », libellé explicite sur le nombre de courses mesurées. Une FC isolée n'est pas une mesure d'amélioration.
- Poids : axe « kg » et dates conservées.
- « Séances » renommé « Courses » pour éviter de compter implicitement le renforcement dans un total composé uniquement des courses.
- Moyennes de cardio, vitesse et puissance par cinq minutes : les valeurs hors des plages physiologiques raisonnables ou non finies sont désormais exclues.

## 4. Design
Les `PaceCard` et `PaceMetric` communs, plus les cartes autonomes de l'accueil, des activités, du Coach, du Programme et de la Nutrition, partagent le même matériau :
- iOS 26+ : Liquid Glass natif `.glassEffect(.regular, in: .rect(cornerRadius: ...))`.
- iOS antérieur : `.regularMaterial` et rectangle arrondi.
- Le contenu garde sa couleur système et ses accents turquoise compatibles clair/sombre.

Les petits contrôles de saisie, boutons sélectionnés et pastilles ne sont pas tous rendus en verre : leur opacité et leur contraste sont utiles à la manipulation et évitent un effet « tout translucide » illisible. Le verre n'est pas artificiellement rendu interactif pour les simples cartes de lecture.

## Vérifications
- Contrats de développement antérieurs V2–V3.8 et nouveau contrat V3.9.
- Tests Swift du calcul temporel sur données synthétiques.
- Build iOS signé, installation sur iPhone physique et lancement.
- Journal de musculation et archive Apple Santé présents après mise à jour.
- Aucun fichier personnel ni OAuth token inclus dans GitHub.

## Limites et prochaines vérifications
1. Faire confirmer au toucher et à l'écran les différentes variantes clair/sombre, taille du texte et le graphique cardiaque du renforcement ; la compilation ne constitue pas une preuve complète d'accessibilité ou de préférence esthétique.
2. Ne pas interpréter l'oscillation verticale, le contact au sol ou la fréquence cardiaque sans contexte d'allure, terrain, météo et ressenti.
3. La cadence de course est encore estimée lorsque sa valeur directe n'existe pas. Aucun modèle ne doit présenter cette estimation comme une mesure native.
4. Un programme d'entraînement efficace s'appuie sur un ensemble de mesures et leur progression, pas uniquement sur la forme des courbes.
