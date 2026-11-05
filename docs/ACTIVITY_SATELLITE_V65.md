# PACE-LAB V6.5 — Imagerie satellite, commandes de vitesse et lecture immersive

Le 5 novembre 2026, livraison sur iPhone 16 Pro.

## Retour pris en compte

- Le menu déroulant des vitesses affichait les options mais leur sélection pouvait échouer.
- Le fond cartographique classique ne ressemblait pas suffisamment au paysage réel.
- La carte devait utiliser presque toute la largeur disponible dans la fiche de séance.
- Le survol 3D devait gagner en qualité visuelle, sans retirer la fluidité améliorée en V6.4.

## Modifications

- MapKit utilise maintenant `MKImageryMapConfiguration(elevationStyle: .realistic)`. L'imagerie satellite est chargée via Apple Plans, avec terrain/bâtiments en relief lorsque la couverture le permet.
- Le menu de vitesses est remplacé par quatre boutons directs et accessibles (0,5× / 1× / 2× / 4×). Ils contrôlent la durée du replay, sans menus contextuels au-dessus d'un `MKMapView` continuellement mis à jour.
- La carte occupe la largeur de la fiche d'activité, avec une hauteur portée à 360 points et des commandes intégrées.
- Le replay passe en présentation plein écran avec interface sombre épurée, gradients discrets, lecture/pause, distance parcourue, barre de progression et recentrage.
- Le lissage caméra et la lecture à cadence cible 30 Hz de la V6.4 sont conservés, tout comme la lecture HealthKit prudente après le crash d'autorisation.
- Aucun tracé GPS n'est automatiquement transféré au Coach IA.

## Contrôles vérifiés

- Compilation simulateur réussie.
- 37 fichiers de tests de contrat réussis.
- Compilation iOS signée réussie.
- Installation et lancement confirmés par `devicectl` sur iPhone 16 Pro, avec l'identifiant `com.pacelab.healthcompanion`, sans désinstaller les données.
- L'aperçu de survol dans le simulateur n'a pas pu être validé par une capture probante dans ce passage : la capture obtenue affichait l'accueil. Il n'est donc pas considéré comme un test visuel validé.

## Vérification utilisateur à réaliser

Ouvrir une course extérieure disposant d'une trace GPS, lancer « Survol 3D » et essayer chaque vitesse, notamment 0,5× et 4×. Vérifier que la vue satellite chargée localement via Apple Plans correspond aux attentes et que l'interface reste lisible sur l'iPhone. La couverture 3D et la fluidité dépendent aussi du chargement des tuiles et de l'appareil.
