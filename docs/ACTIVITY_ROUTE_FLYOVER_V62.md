# PACE-LAB V6.2 — Parcours GPS et Survol 3D

Date : 5 novembre 2026 · Application iOS native.

## But

Intégrer une lecture du parcours GPS et un replay 3D inspirés du *Flyover* de Strava, sans dépendance à Strava, sans abonnement, sans exporter des coordonnées personnelles dans les requêtes du Coach.

## Dans la fiche d'une activité

Pour les courses, marches et activités cyclistes, une section « Parcours » :
- Demande la lecture des itinéraires Apple Santé (type `HKSeriesType.workoutRoute()`).
- Recherche la séance par son UUID HealthKit puis ses `HKWorkoutRoute` liés.
- Lit les coordonnées par `HKWorkoutRouteQuery` jusqu'à la fin des lots.
- Filtre les coordonnées invalides et d'une précision horizontale supérieure à 150 m.
- Affiche le parcours avec MapKit, une ligne et un marqueur de position, ou un état « Aucun tracé GPS accessible » sans inventer d'itinéraire.
- Donne accès au bouton « Survol 3D ».

## Lecture du Survol 3D

- Caméra MapKit inclinée et orientée selon la trajectoire, avec terrain réaliste si disponible.
- Déplacement interpolé en fonction des dates GPS réelles.
- Un marqueur, ligne d'itinéraire complète atténuée et portion déjà parcourue accentuée.
- Pause / lecture, vitesses 0,5×, 1×, 2×, 4×, barre de progression déplaçable, recentrage.
- Lecture accélérée (75 secondes à 1×), **pas une vidéo exportable**. La distance affichée est la distance reconstruite du GPS, qui peut être différente de la distance d'activité enregistrée par Apple Santé.
- Lecture 3D soumise à la couverture terrain/bâtiments disponible dans Plans ; elle n'est pas identique au rendu vidéo de Strava.

## Confidentialité et limites

- La lecture du GPS est demandée via HealthKit et doit être accordée par l'utilisateur.
- Le parcours n'est chargé qu'en ouvrant une fiche d'activité et n'est conservé qu'en mémoire durant cette consultation.
- Aucune route brute ni coordonnée précise n'est ajoutée aux prompts ChatGPT, aux fichiers de sortie ou au dépôt Git.
- MapKit peut télécharger des cartes depuis les services Apple pour les afficher ; l'absence d'envoi au Coach IA ne signifie pas une cartographie hors connexion.
- Certaines sorties Apple Watch n'ont aucun itinéraire (indoor, GPS désactivé, autorisation refusée, etc.). Une mesure GPS absente reste absente.

## Contrôles effectués

- Compilation simulateur Xcode : réussie.
- Test visuel en simulateur avec un itinéraire artificiel temporaire : la carte 3D, la caméra et les commandes s'affichent et le marqueur avance. Cette fixture a été retirée du code livré.
- Compilation signée iPhone : réussie.
- 36 fichiers de tests de contrat : réussis.
- Installation et lancement de la compilation finale propre sur l'iPhone 16 Pro connecté : confirmés.

**Reste à tester :** autorisation et disponibilité d'une vraie trace de course, qualité du suivi sur un parcours réel avec pauses et changements brusques de direction, comportement de MapKit selon la couverture 3D.
