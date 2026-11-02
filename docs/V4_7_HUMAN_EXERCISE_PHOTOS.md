# PACE LAB V4.7 — Photos humaines d'exercices

## Déploiement
- 22 photographies intégrées dans Assets.xcassets : 11 exercices avec les deux phases du mouvement.
- 12 photos sont des recadrages de six diptyques originaux générés par IA dans ce projet : squat goblet, squat sur chaise, rowing unilatéral, développé au sol unilatéral, pont fessier et planche latérale.
- 10 photos sont issues de la bibliothèque libre free-exercise-db / Everkinetic : planche avant, fente statique, développé épaules unilatéral, pompes surélevées et dead bug.
- Les trois autres exercices conservent les schémas existants : mollets, charnière de hanches avec un haltère et marche du fermier à un haltère. Il est interdit de substituer des photographies montrant deux charges.

## Provenance et licence
Les images externes sont créditées à Everkinetic, via https://github.com/yuhonas/free-exercise-db, sous licence CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/). Modifications : conversion JPEG, redimensionnement, ajout d'un fond sombre flouté et séquençage des phases. Les dérivés concernés restent soumis aux conditions de cette licence et une attribution est visible dans l'app.

Les créations IA sont originales et indiquées comme visuels générés. Elles ne constituent pas une validation biomécanique médicale ni une certification de la bonne exécution. Les conseils de mouvement dans l'application conservent leur priorité.

## Technique et données personnelles
- Deux positions distinctes par exercice lorsque pertinent ; pour les mouvements statiques le visuel peut présenter l'installation puis la tenue.
- Aucune donnée Santé ou personnelle n'a été utilisée pour les images.
- Matériel de musculation : un seul haltère ; table ou chaise stable seulement dans les variantes prévues.
- Les illustrations anciennes sont sauvegardées localement sous .generated-exercise-photo-backup pour faciliter le retour arrière.

## Vérifications
- 25 tests de contrat réussis, compilation Xcode réussie, app installée et lancée sur l'iPhone branché.
- Validation tactile et visuelle sur l'écran de l'iPhone recommandée ; l'installation seule ne valide pas la qualité technique de chaque pose.
- Origines et état des 14 exercices consignés dans assets/photo-sources.json.

## À poursuivre
Créer et valider les six photos manquantes pour les trois exercices restants sans représenter un équipement incorrect. L'objectif complet de 28/28 photos humaines n'est PAS encore atteint.
