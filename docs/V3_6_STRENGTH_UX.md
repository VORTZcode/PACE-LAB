# PACE LAB — Entraînement V3.6 : saisie musculation

## Défaut observé
Le précédent suivi V3.5 mettait dans une seule ligne une case de validation et deux champs étroits (54×35 et 66×35 points). Les zones de répétitions étaient difficiles à toucher, notamment pendant le rowing, et le clavier numérique n'avait pas de commande explicite de fermeture.

## Corrections iOS
- Chaque série possède une cellule séparée, avec un titre et un bouton natif de validation occupant au moins 44 points de hauteur.
- Deux champs disposés sur une ligne séparée, en largeur flexible, hauteur minimale 52 points, police arrondie large, contraste propre à PACE LAB, contour turquoise quand le champ est sélectionné.
- FocusState partagé au niveau de la fiche de séance, identité stable (ID exercice + numéro de série) et état de saisie local à chaque cellule. La mise à jour de l'ObservableObject du stockage ne doit pas changer le texte édité ou faire perdre le focus.
- Clavier numérique/décimal avec bouton « Terminé » dans la barre d'outils, et défilement de la page qui masque le clavier. Le fond de la page possède un geste destiné à fermer le clavier en cas de toucher hors contenu.
- Le stockage local est inchangé : `Application Support/pace-strength-sets.json`. Les validations, répétitions et charges V3.5 sont récupérées par la nouvelle interface. Pas de modification de HealthKit ni du modèle d'authentification.

## Contrôles
- Compilation iOS Debug signée réussie.
- Installation et lancement sur iPhone physique validés.
- Fichier privé `pace-strength-sets.json` présent avant et après réinstallation, 2 Ko ; archive locale HealthKit conservée, 4,3 Mo.
- Tests PWA, HealthKit, contrat Coach jusqu'à V3.4, séries V3.5, UX V3.6 passés.

## À valider par l'utilisateur
- Ouverture d'un champ « Répétitions » ou « Charge » dans chaque exercice, notamment rowing.
- « Terminé » du clavier, tap sur zone vide, défilement vertical.
- Conservation d'une valeur après fermeture/réouverture et cochage d'une série.
- Comportement avec grands caractères et petit écran ; ces interactions ne sont pas mesurées par les tests statiques et la compilation.
