# PACE LAB — Projet 30

Application web progressive (PWA) pour programme sportif, entraînements, nutrition et évolution des performances. **Version de lancement : programme du 2 au 8 novembre 2026.**

## Installer localement

La V1 n'a **aucune dépendance à installer**. Depuis ce dossier :

```bash
python -m http.server 8080
```

Puis ouvrir `http://localhost:8080` et utiliser le menu **Réglages**. Pour tester le code et vérifier l'absence de données privées :

```bash
node tests/validate.mjs
node tests/smoke.mjs
```

## Confidentialité : à lire avant publication

**Ce dépôt ne contient PAS l'historique Apple Santé, les poids, la VO₂ max ou les données d'entraînement personnelles.** L'application est livrée avec le programme et les recettes seulement. Les données personnelles s'importent depuis un fichier JSON **à conserver hors dépôt** avec Réglages > Importer. Les données saisies sont enregistrées dans le stockage local du navigateur : ce n'est pas une sauvegarde cloud et ce n'est pas une protection forte sur un appareil partagé. Les sauvegardes JSON restent sous la responsabilité de l'utilisateur.

Ne jamais committer `PACE_LAB_Donnees_Personnelles_A_Importer.json`, `export.zip` ou des exports Apple Santé. GitHub Pages est un hébergement public même si l'interface semble privée. Pas de comptes, pas de connexion directe Apple Santé, pas de synchronisation serveur.

## Mises à jour automatiques

Après la création du dépôt GitHub :

1. Ajouter les fichiers du projet à la branche `main` (sans fichiers personnels).
2. Dans **Settings → Pages → Build and deployment**, choisir **GitHub Actions**. Sur les dépôts privés, vérifier les conditions de disponibilité de Pages selon la formule GitHub et les paramètres du compte.
3. Chaque `push` sur `main` exécute `.github/workflows/deploy.yml` : validation, assemblage statique, version du service worker, publication. Vérifier dans l'onglet **Actions** la première exécution puis ouvrir l'URL de déploiement fournie.
4. Sur iPhone : Safari → Partager → **Sur l'écran d'accueil**. La PWA sera mise à jour via les nouveaux déploiements (rafraîchir ou fermer/réouvrir si une ancienne version reste en cache).

> Le déploiement automatique ne signifie **pas** que le plan sportif est généré seul chaque semaine ou que les données Apple Santé se synchronisent. Il automatise la publication des changements de code, de programme et de recettes poussés sur `main`.

## Structure

```text
index.html                   Application
assets/styles.css            Apparence iPhone / ordinateur
assets/app.js                Interactions, sauvegardes, import privé
assets/programme.js          Programme public de la semaine et 14 recettes
manifest.webmanifest         Configuration PWA
sw.js                        Cache offline versionné automatiquement par CI
icon.svg                     Icône PWA
.github/workflows/deploy.yml Validation et publication GitHub Pages
tests/validate.mjs           Vérifications sans dépendances
```

## Ajouter la semaine suivante

Modifier `assets/programme.js` (tableaux `plan`, `force`, `recipes`), valider les 7 jours et les recettes, lancer `node tests/validate.mjs`, ouvrir en local puis pousser sur `main`. Attention : cette première version a encore une semaine de programme, sans moteur automatique de planification.

## Sauvegardes et migration

Pour retrouver les anciennes courses Apple sur un nouvel appareil : importer le fichier personnel JSON remis séparément via la page Réglages. **Ne pas l'envoyer dans GitHub**, ni l'utiliser dans les exemples ou les tickets d'incident. Exporter régulièrement une sauvegarde complète depuis Réglages. Si une sauvegarde contient une donnée médicale, la traiter comme une donnée privée.

## Intégration Apple Santé / Apple Watch — chantier en cours

Une première implémentation expérimentale se trouve dans `ios/` et `assets/cloud-sync.js`.
Elle vise à importer automatiquement les séances enregistrées par l'Apple Watch et les séries cardiaques, y compris **les mesures réellement disponibles pendant les cinq minutes après la fin**.

**Important : l'automatisation de bout en bout n'est pas encore opérationnelle.** La PWA seule ne sait pas accéder à HealthKit. Il reste à configurer un projet Supabase dédié, construire et signer l'app native iOS, lui accorder les permissions Santé, puis effectuer des essais sur iPhone / Apple Watch réels. Les notifications d'arrière-plan et le réveil cinq minutes plus tard ne sont pas garantis par iOS ; les mesures manquantes restent absentes.

Voir [le guide de synchronisation](docs/HEALTHKIT_SYNC.md). Aucune donnée personnelle n'est incluse dans GitHub.
