# PACE LAB V4.6 — Exercices Studio

Cette itération remplace les anciens visuels pastel par 28 rendus de studio sombres et cohérents, avec silhouettes ombrées, trajectoires de mouvement et principaux groupes musculaires. Les poses sont réalisées à partir de points articulaires définis par exercice, avec un seul haltère lorsque le mouvement l'exige.

Les images demeurent des **illustrations schématiques** : il ne s'agit ni de photographies ni d'une animation anatomique validée. Les textes de consignes sont les références prioritaires avant l'exécution. Une validation biomécanique individuelle est nécessaire avant une diffusion commerciale comme démonstrations techniques.

L'écran d'exercice montre désormais **une grande image à la fois** avec sélecteur `01 · Départ / 02 · Arrivée`, et un agrandissement accessible. Cette présentation évite de réduire deux images sur un iPhone.

### Reproductibilité
- Lancer `python3 scripts/make_premium_exercise_art.py` depuis la racine du dépôt.
- Ce générateur s'appuie sur les coordonnées de `scripts/make_original_exercise_art.py`, produit les sources SVG dans `assets/exercise-vectors`, puis les JPEG de `Assets.xcassets`.
- Les 22 tests de contrat valident les ressources et le parcours, puis une compilation Xcode sur iPhone contrôle le bundle.

### Qualité encore à atteindre
- Remplacer à terme les silhouettes stylisées par des visuels humains photoréalistes dédiés à chaque phase, avec le même modèle, sans changer le matériel ni confondre les exercices.
- Pour chaque mouvement, vérification des appuis, articulations, trajectoire, sécurité et présentation sur petit écran.
- Des maquettes promotionnelles ou des collages ne doivent pas être présentés comme des démonstrations techniques exactes.
