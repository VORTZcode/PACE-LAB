# PACE-LAB V6.4 — Carte d'activité et caméra de survol

## Retour utilisateur et défaut identifié

La carte de la séance V6.2 était petite et placée après un long bloc de statistiques et le bilan. Le survol semblait « faire des droites-gauches » : la caméra reprenait l'angle géodésique entre deux points GPS consécutifs, puis le remplaçait sans transition toutes les 100 ms. L'angle pouvait changer rapidement à chaque mesure GPS ou virage.

## Correctifs livrés

- Le parcours arrive maintenant immédiatement après l'en-tête et les chiffres principaux de l'activité, avant le bilan IA, sans masquer les autres données.
- La carte principale est agrandie (328 points), avec un tracé contrasté, une légende compacte et une commande « Survol 3D » visible sur la carte.
- Une icône ouvre une carte plein écran avec pan/zoom natifs et accès au replay.
- Direction de caméra déduite d'une portion de trajet de 8 à 18 secondes autour du point courant, plutôt qu'un segment GPS point à point ; micro-déplacements inférieurs à 8 mètres ignorés pour cette estimation.
- Lissage circulaire des angles (359° → 1° devient +2°), vitesse de rotation plafonnée à 78°/s et interpolation exponentielle du centre de caméra.
- Point de visée légèrement anticipé ; un déplacement manuel explicite de la barre de lecture peut recentrer immédiatement la caméra.
- Fréquence cible du rafraîchissement de 30 images/s au lieu de 10. Il s'agit d'un objectif de cadence, pas d'une garantie de fréquence du moteur MapKit.
- La trace et les mesures originales restent intactes. Les coordonnées GPS ne sont pas transmises au Coach IA.
- Le correctif de crash HealthKit est conservé : la simple ouverture d'une activité n'affiche pas de demande d'autorisation GPS ; la demande explicite inclut le type parent « entraînement ».

## Validation technique

- Build simulateur Xcode : réussi.
- Build iOS signé : réussi.
- Installation et lancement sur iPhone 16 Pro : confirmés sans désinstallation ni changement de Bundle ID.
- 4 fixtures Swift (dont lissage de caméra, passages 359°/1°, limitation angulaire et repositionnement sur seek) : réussies.
- Tests de contrat JavaScript : vérifiés dans l'itération de livraison.

## Ce qui n'est pas prouvé

- Le rendu exact et la fluidité finale du replay sur les itinéraires réels de l'utilisateur ne sont pas encore mesurés, faute de contrôle interactif de la séquence GPS réelle sur l'iPhone.
- Les niveaux de détail 3D dépendent de MapKit et de la couverture locale ; le framerate peut baisser selon le modèle d'appareil et les tuiles 3D.
- Aucune vidéo de survol exportable n'est produite.

La priorité suivante reste un contrôle visuel du replay sur un vrai itinéraire, en particulier les demi-tours, les arrêts et les passages avec signal GPS bruité.
