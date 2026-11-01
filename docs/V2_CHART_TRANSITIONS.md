# PACE LAB 2.5 — Fluidité des graphiques et statistiques interactives

## Problèmes signalés
- Le changement de métrique dans les graphiques de course produisait un clignotement, une attente et un saut de hauteur.
- Les quatre cartes principales de progression sur l'accueil n'ouvraient aucune analyse.
- L'accueil manquait de finition Liquid Glass et d'indications visuelles d'interactivité.

## Corrections
- Les six séries Apple Santé sont préparées **en une fois** hors du fil d'interface lors de l'ouverture de la fiche et lors d'un changement effectif du contenu HealthKit.
- La mesure sélectionnée est une simple lecture d'un cache local, sans effacer le graphique ni afficher un nouveau spinner.
- La zone de graphique conserve une hauteur de 238 points, même lorsque des mesures sont indisponibles.
- Rendu Swift Charts limité à 320 points par série pour la fluidité, sans inventer de valeur ; sélection tactile et points réels conservés. L'animation des centaines de marques est désactivée, tout en gardant la transition douce des boutons.
- Les cartes du tableau de bord sont des NavigationLink natives vers quatre détails : année, mois, cardio, sept jours. Chaque écran contient un graphique pertinent lorsque disponible, les séances concernées et une navigation vers la fiche d'une course.
- Liquid Glass interactif sur les deux cartes de navigation principales de l'accueil ; surfaces mates sur les autres données pour conserver contraste et clarté. Fallback matériau natif sur iOS antérieur à 26.
- Version affichée dans Réglages : 2.5.

## Confidentialité et sécurité
L'identifiant du bundle iOS ne change pas. Les données Santé et journaux privés restent uniquement dans le conteneur de l'application iPhone. Aucun JSON personnel n'est publié dans GitHub ni transféré vers un backend.

## Validation
- Compilation SwiftUI signée et installation réelle sur l'iPhone.
- Tests PWA, smoke, contrat HealthKit, contrat UI, test d'ergonomie V2.4 et contrat V2.5 : vérifiés localement.
- Capture du véritable accueil et conservation du total annuel dans l'interface.
- Reste **à vérifier au toucher** : la fluidité ressentie lors de changements rapides de métriques, l'accessibilité et la navigation dans chaque écran récapitulatif. La réussite des tests de code ne vaut pas mesure de latence réelle sur iPhone.

## Choix de design
Apple recommande de limiter les mises à jour coûteuses de body SwiftUI et d'appliquer Liquid Glass aux éléments d'interface interactifs de manière lisible. Il n'est pas nécessaire d'en couvrir chaque carte.
