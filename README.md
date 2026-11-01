# PACE LAB — Projet 30

## PACE LAB V3 — Coach ChatGPT

La branche de travail V3 ajoute un coach ChatGPT à la version iOS native. Il utilise la connexion « Sign in with ChatGPT » du projet open source local, avec autorisation explicite et jetons protégés sur l’iPhone. Les propositions de séances et de repas ne sont appliquées qu’après validation. Voir [le guide V3](docs/V3_COACH_CHATGPT.md).

## Application native iOS V2 (branche de développement)

La V2 est reconstruite en SwiftUI, avec cinq onglets iOS, navigation native Liquid Glass, historique Apple Santé local, graphiques Swift Charts, programme et nutrition. L'interface Web/PWA reste disponible séparément et n'a pas accès à HealthKit. Voir [le guide de la V2 native](docs/V2_NATIVE.md). Les informations Apple Santé ne sont jamais publiées sur GitHub.

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

La version iPhone native expérimentale se trouve dans `ios/` avec le pont `assets/native-health.js`. Elle lit HealthKit directement et conserve localement les séances, les séries de fréquence cardiaque et les mesures réellement disponibles pendant **les trois premières minutes de récupération**.

**État :** compilée, signée, installée et testée sur un iPhone réel avec un historique pluriannuel (statistiques personnelles non publiées). Reste à valider la synchronisation automatique après une NOUVELLE activité Watch, y compris en arrière-plan. Aucun Supabase, backend ni compte externe n'est nécessaire. La PWA sur GitHub Pages ne peut pas lire HealthKit ni partager automatiquement les données locales de l'app iOS. Les notifications d'arrière-plan n'ont pas de délai garanti.

Voir [le guide de synchronisation](docs/HEALTHKIT_SYNC.md). Aucune donnée personnelle n'est incluse dans GitHub.

V3.1 : bilans ciblés avec partage facultatif de métriques cardiaques agrégées et de notes, comparaison de charge sur quatre semaines, proposition sans modification automatique du programme. Voir [le guide Coach V3.1](docs/V3_1_COACH_ANALYTICS.md).

V3.2 — Coach : profil sportif local confirmé, ergonomie native, moteur de revue de charge avant adoption et références scientifiques. [Guide V3.2](docs/V3_2_SCIENCE_AND_UX.md).

V3.3 — Coach adaptatif : éditeurs de profil lisibles, organisation initiale 3 courses + 3 musculation, détection locale post-séance et adaptation d’une seule future course avec validation/annulation. [Guide V3.3](docs/V3_3_ADAPTIVE_COACH.md).
