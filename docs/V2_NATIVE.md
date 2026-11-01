# PACE LAB V2 — iOS natif

## Objectif de cette branche
Reconstruction du cockpit iPhone en **SwiftUI véritable**. La V1 WKWebView est conservée dans le dépôt pour la PWA GitHub Pages, mais **n'est plus utilisée par l'application native V2**.

## Design
- Navigation iOS `TabView` : Aujourd'hui, Activités, Programme, Progrès, Nutrition.
- `NavigationStack`, grands titres iOS, polices système, SF Symbols, prise en charge claire/sombre, Dynamic Type.
- Liquid Glass natif **pour la navigation et les commandes**, pas une accumulation de cartes transparentes.
- Surfaces de contenu mates, contrastées, espacements réguliers, actions secondaires discrètes.
- Graphiques Swift Charts (FC réelle, kilomètres mensuels, évolution du poids saisi).

## Fonctionnalités
- **Aujourd'hui** : prochaine séance du plan, cumul annuel, dernière course, FC moyenne.
- **Activités** : historique HealthKit, filtres course/marche/toutes, détail temps/allure/cardio/récupération.
- **Programme** : semaine du 2 au 8 novembre 2026, 18 exercices et validation persistée localement.
- **Progrès** : histogramme mensuel, FC des dernières courses (non ajustée de l'allure), poids et tour de taille saisis localement.
- **Nutrition** : 14 recettes, ingrédients, préparation et validation persistée.
- **Réglages** : état HealthKit, synchronisation manuelle et contrôles de confidentialité.
- **Iconographie** : nouvel icône monogramme P, généré localement et inclus en asset catalog.

## Source de données et confidentialité
Le bundle ne contient que `ios/PaceLabCompanion/AppData/pace-programme.json` (planning, exercices, recettes publics). Il **ne contient aucun historique Apple Santé**. Les activités sont lues directement depuis HealthKit et stockées dans l'espace privé de l'application sur l'iPhone; aucun compte ni serveur tiers. L'identifiant d'application est inchangé : `com.pacelab.healthcompanion`, pour préserver le stockage local de la V1.

Les actions nutrition, séances et les mesures personnelles V2 sont enregistrées dans `UserDefaults` de l'application; **elles ne sont pas synchronisées avec la PWA**, et ne sont pas une sauvegarde multi-appareils. Le WKWebView de la V1 et son `localStorage` sont conservés sur le téléphone, mais ne sont pas automatiquement migrés vers les nouveaux composants SwiftUI. Ne pas désinstaller l'application pour une mise à jour.

## Tester sur un Mac
```bash
cd ~/Developer/PACE-LAB
xcodegen generate --spec ios/project.yml --project ios
node tests/validate.mjs
node tests/smoke.mjs
node tests/healthkit-contract.mjs
node tests/native-ui-contract.mjs
xcodebuild -project ios/PaceLabCompanion.xcodeproj -scheme PaceLabCompanion -configuration Debug -destination 'platform=iOS,id=YOUR_IPHONE_UDID' DEVELOPMENT_TEAM=YOUR_APPLE_TEAM CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
```
Ouvrir `ios/PaceLabCompanion.xcodeproj` dans Xcode, choisir l'iPhone et Exécuter.

## Limites connues
- Le plan détaillé fourni n'a qu'une semaine; les semaines suivantes ne sont pas générées automatiquement.
- La synchronisation des nouvelles séances en arrière-plan dépend d'iOS; les délais exacts ne sont pas garantis.
- Les points de récupération cardiaque sont réels et peuvent être absents selon Apple Santé.
- L'app V2 n'a pas encore de suivi GPS ni de routes, ni de calcul fiable de forme/fatigue tenant compte de l'allure et du terrain.
- L'icône et les cinq onglets sont validés à la compilation et sur un iPhone réel. Les parcours complets de tous les sous-écrans nécessitent une validation tactile utilisateur.
