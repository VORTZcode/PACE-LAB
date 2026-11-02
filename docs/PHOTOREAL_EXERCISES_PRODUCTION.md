# PACE-LAB — Pack photographique humain (travail en cours)

## État de livraison
Les 28 illustrations vectorielles existantes sont conservées dans l'application. Aucun remplacement global par des photographies ne peut encore être validé : les quelques images issues des maquettes promotionnelles ne sont pas des prises de vue autonomes suffisamment définies, et certaines ne représentent pas les exercices exacts.

Deux photographies prototypes du squat, extraites d'une image générée, ont été transférées dans le dossier LOCAL `.generated-exercise-photo-staging` sur le Mac. Elles sont sous le seuil de résolution et restent volontairement hors de l'application.

## Mouvements inclus
14 mouvements du programme réel, dont la prise de matériel est contrôlée : squat avec **un** haltère, squat chaise, rowing **un** bras, développé au sol **un** bras, pont fessier, planche latérale, planche avant, mollets, fente statique assistée, développé épaules **un** bras, charnière de hanches **un** haltère, pompes surélevées sur appui stable, dead bug et marche du fermier **un** haltère. Chacun doit disposer d'une photo initiale et finale.

## Production de 28 photographies
- `python3 scripts/generate_photoreal_exercise_pack.py` : liste des mouvements et prompts, sans requête payante.
- `OPENAI_API_KEY=... python3 scripts/generate_photoreal_exercise_pack.py --generate` : utilise l'API Images séparément facturée pour produire un athlète fictif de référence et les 28 prises de vue; ne pas lancer sans accord sur cette facturation.
- Les générations sont sauvegardées dans `.generated-exercise-photo-staging` avec un manifeste `approved:false` par défaut et un contrôle de correspondance par mouvement.
- Les images doivent faire au minimum 1024 x 768 pixels; l'identité, les appuis, la charge, le nombre d'haltères et la position articulaire doivent être contrôlés manuellement avant toute approbation.
- `python3 scripts/install_approved_exercise_photos.py` : validation complète sans modification.
- `python3 scripts/install_approved_exercise_photos.py --install` : installe les 28 photos uniquement si toutes sont présentes, haute résolution et approuvées, après sauvegarde locale des anciens assets.

## Pourquoi bloquer l'intégration partielle ?
Les illustrations ne sont pas des décorations. Une vidéo ou une photo de squat avec une prise erronée ou une flexion du genou impossible peut induire une exécution incorrecte. L'application doit maintenir une nomenclature exacte, préserver les données Santé et les préférences utilisateur et rester cohérente d'un exercice à l'autre.

## À ne pas présenter comme accompli
Le générateur OpenAI fourni dans la conversation a répété des collages d'interface plutôt que 28 photographies indépendantes. Aucun appel payant à l'API Images n'a été réalisé, et l'application installée n'a pas reçu le pack photo complet.