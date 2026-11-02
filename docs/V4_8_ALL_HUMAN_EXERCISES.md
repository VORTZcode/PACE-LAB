# PACE-LAB V4.8 — 28 visuels humains dans l’application

## Livraison
- Les 14 exercices possèdent désormais deux images humaines (28 fichiers JPEG).
- V4.7 : 12 images issues de six compositions IA originales ; 10 images provenant d’Everkinetic via free-exercise-db, sous licence CC BY-SA 4.0, avec attribution visible dans l’application.
- V4.8 : 6 images de mollets, charnière de hanches et marche du fermier, issues d’une composition générée par IA, recadrée et agrandie.
- Les 28 images sont intégrées aux 28 `Movement_{figure}_{Start|End}.imageset` existants. Les images précédentes sont sauvegardées localement dans `.generated-exercise-photo-backup`.

## Limitations de qualité
- Les six derniers fichiers ont des sources initiales de 94 à 217 pixels de large, agrandies en 900 × 550. Le redimensionnement n'invente pas les détails manquants ; il s'agit de maquettes provisoires et non de photos studio natives.
- Les textes de position intégrés à certaines images ne sont pas idéaux dans une interface déjà dotée d’un sélecteur Départ / Arrivée.
- La représentation de la prise et du nombre de charges sur la charnière de hanches requiert une vérification manuelle. L’application affiche un avertissement ciblé : les consignes textuelles prévalent.
- Ne pas présenter ces images comme démonstrations biomécaniques certifiées.

## Validation
- Tous les fichiers JPEG doivent exister et être référencés par leurs `Contents.json`.
- `node tests/photoreal-asset-contract.mjs` valide les 14 exercices, la provenance, le statut provisoire et les avertissements.
- Exécuter tous les tests, compiler le schéma PaceLabCompanion pour l’iPhone physique, puis installer et lancer l’application.
- Consulter `assets/photo-sources.json` pour les sources et les images restant à revoir.

## Amélioration suivante
- Remplacer les six dernières sources basse définition par des rendus individuels haute résolution, sans texte incrusté.
- Vérifier les appuis, l’alignement des articulations et l’utilisation du seul haltère disponible avant de retirer les avertissements.