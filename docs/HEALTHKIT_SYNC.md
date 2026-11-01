# PACE LAB — Apple Santé sans serveur (projet iOS en développement)

## Architecture

- **iPhone natif SwiftUI + WKWebView** : interface PACE LAB incluse dans l'application et chargée depuis son bundle signé. Seule une page `file://` intégrée au bundle peut recevoir les résumés HealthKit.
- **HealthKit** : demande un consentement en lecture pour workouts, fréquence cardiaque, distance, énergie, récupération minute 1. La lecture est directe, sans SDK ni serveur d'un prestataire.
- **Fichiers locaux protégés** : `Application Support/local-healthkit-workouts.json`, protection iOS `completeUntilFirstUserAuthentication`. Les séries détaillées restent sur le téléphone.
- **Pont interne Swift → JavaScript** : uniquement des résumés de courses ; `source_uuid` stable permet les mises à jour idempotentes, y compris après ajout de données de récupération.
- **PWA GitHub Pages** : fonctionne pour le planning, les repas, les mesures manuelles et les imports JSON, mais n'a **pas** accès à HealthKit et n'est pas synchronisée automatiquement avec la version native.
- **Aucun Supabase, aucun compte utilisateur, aucune transmission d'informations de santé vers Internet.**

## Récupération cardiaque et cadence de mise à jour

L'Apple Watch échantillonne généralement activement la FC dans les trois minutes après un entraînement (support.apple.com/guide/watch/end-and-view-a-summary-of-your-workout-apd95450de2a/watchos). Notre requête cherche les vraies mesures jusqu'à T+5 min, sans extrapolation. Aucune mesure à T+4 ou T+5 n'est garantie. Le statut `partial` n'est donc pas une erreur.

`HKObserverQuery` et `enableBackgroundDelivery` réveillent l'app en arrière-plan **au mieux**. `BGAppRefreshTask` ne garantit pas une exécution à T+5. Au prochain lancement, les séances récentes sont relues automatiquement. Une montre déconnectée ou verrouillée peut retarder la synchronisation.

## Compiler et installer

1. Mac avec Xcode récent, XcodeGen (`brew install xcodegen` facultatif). Depuis la racine du dépôt : `xcodegen generate --spec ios/project.yml --project ios`.
2. Dans Xcode, sélectionner une équipe Apple, adapter le bundle ID à son équipe. Vérifier HealthKit et Background Delivery et le dossier **WebApp** comme *folder reference* dans Copy Bundle Resources.
3. Compiler sur **vrai iPhone**, associé à l'Apple Watch. Les notifications HealthKit arrière-plan ne sont pas testables correctement avec le simulateur.
4. Ouvrir PACE LAB → onglet Apple Santé → Autoriser la lecture. Revenir au premier onglet : les courses autorisées apparaissent.
5. Effectuer une sortie test : fermer l'écran, terminer l'activité depuis l'Apple Watch, puis comparer les valeurs à celles de Santé après 1, 3, 5 et 15 min. Réouvrir PACE LAB si la notification est retardée.

## Limitations avant production

- Ce code est un **prototype non compilé sur macOS** dans cette session ; uniquement analyse syntaxique Swift et tests JS locaux. Il faut valider effectivement le projet Xcode, les entitlements et les autorisations Apple.
- La première lecture recherche les **40 dernières séances sur 30 jours** ; les entraînements antérieurs restent importables par JSON. Étendre l'historique avec `HKAnchoredObjectQuery` paginé avant lancement.
- Les suppressions d'activités dans Santé ne sont pas encore propagées automatiquement : adopter `HKAnchoredObjectQuery` avec `HKDeletedObject`.
- Le programme et les repas sont actuellement conservés dans le `localStorage` du WKWebView ; la suppression de l'application supprime aussi ces données. Prévoir export/restauration et sauvegarde locale chiffrée.
- Une application native signée devra être redéployée via Xcode/TestFlight pour les mises à jour iOS ; GitHub Actions/Pages met à jour uniquement la **version web**. Aucun déploiement natif automatique n'est actif.
- Ne pas utiliser iCloud/CloudKit comme stockage de données de santé personnelles : les directives Apple de publication des apps l’interdisent. En cas de besoin multi-appareil, réévaluer le périmètre des données et la solution juridique/technique avant implémentation.
