# PACE LAB — Apple Santé sans serveur (projet iOS en développement)

## Architecture

- **iPhone natif SwiftUI + WKWebView** : interface PACE LAB incluse dans l'application et chargée depuis son bundle signé. Seule une page `file://` intégrée au bundle peut recevoir les résumés HealthKit.
- **HealthKit** : demande un consentement en lecture pour workouts, fréquence cardiaque, distance, énergie, récupération minute 1. La lecture est directe, sans SDK ni serveur d'un prestataire.
- **Fichiers locaux protégés** : `Application Support/local-healthkit-workouts.json`, protection iOS `completeUntilFirstUserAuthentication`. Les séries détaillées restent sur le téléphone.
- **Pont interne Swift → JavaScript** : uniquement des résumés de courses ; `source_uuid` stable permet les mises à jour idempotentes, y compris après ajout de données de récupération.
- **PWA GitHub Pages** : fonctionne pour le planning, les repas, les mesures manuelles et les imports JSON, mais n'a **pas** accès à HealthKit et n'est pas synchronisée automatiquement avec la version native.
- **Aucun Supabase, aucun compte utilisateur, aucune transmission d'informations de santé vers Internet.**

## Historique intégral et mises à jour automatiques

- Première synchronisation : `HKAnchoredObjectQuery` paginé, sans limitation à 30 jours ou 40 entraînements.
- Les résumés de toutes les activités arrivent d'abord, pour reconstruire les cumuls annuels sans attendre le chargement de toutes les courbes.
- L'enrichissement cardio récupère les vrais échantillons par activité et reprend après interruption. Un drapeau interne évite de retraiter inutilement les séances terminées.
- La position incrémentale HealthKit est enregistrée localement après chaque page. Les mises à jour et suppressions utilisent l'UUID HealthKit sans doublons.
- La lecture détaillée a été validée sur un iPhone physique avec un historique pluriannuel. Les totaux réels et toute donnée de santé restent strictement hors du dépôt.

## Récupération cardiaque et cadence de mise à jour

L'Apple Watch échantillonne généralement activement la FC dans les trois minutes après un entraînement (support.apple.com/guide/watch/end-and-view-a-summary-of-your-workout-apd95450de2a/watchos). Le statut de récupération vérifie les mesures disponibles autour de T+3 min, sans extrapolation. Les échantillons à T+4 et T+5 peuvent être stockés s'ils existent, mais ne sont plus nécessaires pour classer la récupération complète.

`HKObserverQuery` et `enableBackgroundDelivery` réveillent l'app en arrière-plan **au mieux**. `BGAppRefreshTask` ne garantit pas une exécution à T+3. Au prochain lancement, les séances récentes sont relues automatiquement. Une montre déconnectée ou verrouillée peut retarder la synchronisation.

## Compiler et installer

1. Mac avec Xcode récent, XcodeGen (`brew install xcodegen` facultatif). Depuis la racine du dépôt : `xcodegen generate --spec ios/project.yml --project ios`.
2. Dans Xcode, sélectionner une équipe Apple, adapter le bundle ID à son équipe. Vérifier HealthKit et Background Delivery et le dossier **WebApp** comme *folder reference* dans Copy Bundle Resources.
3. Compiler sur **vrai iPhone**, associé à l'Apple Watch. Les notifications HealthKit arrière-plan ne sont pas testables correctement avec le simulateur.
4. Ouvrir PACE LAB → onglet Apple Santé → Autoriser la lecture. Revenir au premier onglet : les courses autorisées apparaissent.
5. Effectuer une sortie test : fermer l'écran, terminer l'activité depuis l'Apple Watch, puis comparer les valeurs à celles de Santé après 1, 3 et 15 min. Réouvrir PACE LAB si la notification est retardée.

## Limitations avant production

- **Compilé, signé et installé sur un vrai iPhone** ; il reste à vérifier le comportement automatique après une nouvelle séance Watch, avec iPhone verrouillé et mode hors ligne.
- Les suppressions HealthKit sont traitées via `HKDeletedObject` et retirées de l'interface ; scénario de suppression réelle à tester.
- Les séances sans mesures cardiaques disponibles restent sans fréquence calculée : jamais de valeur inventée.
- Le programme et les repas sont actuellement conservés dans le `localStorage` du WKWebView ; la suppression de l'application supprime aussi ces données. Prévoir export/restauration et sauvegarde locale chiffrée.
- Une application native signée devra être redéployée via Xcode/TestFlight pour les mises à jour iOS ; GitHub Actions/Pages met à jour uniquement la **version web**. Aucun déploiement natif automatique n'est actif.
- Ne pas utiliser iCloud/CloudKit comme stockage de données de santé personnelles : les directives Apple de publication des apps l’interdisent. En cas de besoin multi-appareil, réévaluer le périmètre des données et la solution juridique/technique avant implémentation.
