# PACE LAB — Synchronisation automatique Apple Santé (prototype technique)

## Ce qui est réellement pris en charge

- L'application web PWA n'a **pas** accès à HealthKit. Aucun code JavaScript de GitHub Pages ne peut lire les données Apple Santé directement.
- `ios/` contient le **code source** d'un compagnon iOS natif SwiftUI. Il lit les exercices HealthKit autorisés, observe les nouvelles séances, et conserve une file d'attente locale chiffrée/protégée par le système de fichiers iOS tant que l'envoi n'aboutit pas.
- `supabase/schema/healthkit.sql` crée la table privée destinée à recevoir les activités et les fréquences cardiaques, avec RLS fondée exclusivement sur `auth.uid()`.
- La PWA propose dans Réglages une connexion privée Supabase. Elle récupère les nouvelles courses dès qu'elle est ouverte/connectée, avec actualisation au retour au premier plan.

**Non réalisé / non vérifié :** aucun projet Supabase PACE LAB n'a encore été créé, le schéma n'est pas déployé, le projet Xcode n'a pas été compilé sur macOS ni signé/installé sur iPhone, et aucun test réel de livraison Apple Watch → Santé → PACE LAB → Supabase → PWA n'a été exécuté.

## Fonctionnement après configuration

1. Une séance Apple Watch est sauvegardée dans Apple Santé.
2. L'app compagnon reçoit une notification `HKObserverQuery` lorsque HealthKit enregistre une activité (activation `enableBackgroundDelivery`). Le système peut la retarder ; observer queries **ne garantissent pas de notification à la seconde**.
3. Le compagnon relit les séances avec `HKSampleQuery`, collecte les échantillons cardio `heartRate` pendant l'entraînement et jusqu'à **300 secondes après** sa fin. Les séquences cardiaques sont transmises avec leur vraie date/heure, sans interpolation.
4. Une première copie de la séance est mise en file d'attente locale puis envoyée au backend avec identifiant HealthKit UUID stable et upsert idempotent.
5. Une lecture complémentaire est demandée via `BGAppRefreshTaskRequest` (au plus tôt 5 min), les nouvelles mesures HR (observées au mieux) et à chaque ouverture de l'app. Les minuteries de `BGTaskScheduler` ne constituent **pas une garantie** d'exécution exactement à T+5 min.
6. Le statut de récupération vaut `pending` tant que les cinq minutes ne sont pas passées, `partial` si la minute 5 n'a pas été mesurée, `complete` si une vraie mesure proche de T+5 min existe. Un statut `partial` ne signifie **pas un échec**, mais qu'il manque un échantillon.
7. Les champs `recovery_hr_1min`, `2min`, `3min`, `5min` proviennent de la mesure la plus proche dans une fenêtre de ±35 secondes, ou sont `null`. Le champ `apple_recovery_1min_delta` est la **mesure distincte** fournie par Apple (différence entre pic et 1 minute), quand elle existe.
8. La PWA récupère les activités associées au compte authentifié et n'affiche dans son onglet Courses que les activités de type course à pied. Les autres activités restent présentes dans la base pour la prochaine vue multi-sport.

> Apple indique que le capteur de fréquence cardiaque reste actif environ **3 minutes** après la fin d'un entraînement dans l'application Exercice. Les mesures 4 et 5 minutes ne sont pas assurées : impossible d'exiger cinq minutes continues sans envisager une app watchOS dédiée et le consentement explicite de l'utilisateur pour maintenir une session active.

## Mise en route restante (sur appareils et comptes réels)

1. Créer un **projet Supabase PACE LAB distinct** (ne pas mélanger NailPilot / Uniligue / Quest). Région UE. Vérifier le devis du projet avant toute création facturable.
2. Activer Supabase Auth (email + mot de passe ou autre méthode autorisée, confirmations recommandées) ; appliquer `supabase/schema/healthkit.sql` après revue. Vérifier les politiques RLS et l'exposition de l'API avec un utilisateur authentifié puis un autre.
3. Installer `XcodeGen` sur un Mac, puis `xcodegen generate --spec ios/project.yml --project ios` depuis la racine. Vérifier la valeur `CODE_SIGN_ENTITLEMENTS` et ajouter les capacités **HealthKit**, **HealthKit Background Delivery**, **Background fetch**. Dans Xcode, sélectionner une équipe Apple et adapter le Bundle Identifier à un domaine appartenant à l'équipe.
4. Tester uniquement sur **un iPhone physique avec Apple Watch**, pas sur le simulateur iOS pour les notifications HealthKit. Autoriser l'accès **en lecture seule** aux entraînements, au cardio, aux distances, à l'énergie active et au recul FC 1 minute.
5. Renseigner dans le compagnon l'URL du projet Supabase et sa **clé publique** (jamais de clé secrète/service-role), se connecter avec un compte privé.
6. Ouvrir la PWA, Réglages > Apple Santé, renseigner le même projet et se connecter avec le même compte, puis cliquer « Actualiser depuis Santé ».
7. Sur Apple Watch : enregistrer une marche/course test, terminer, rester 5 minutes, puis contrôler les mesures réellement sauvegardées, la file d'attente, une ligne unique par `source_uuid` en base, puis l'affichage dans la PWA.
8. Refaire le test écran verrouillé et téléphone hors-ligne, puis remise en ligne, et après un redémarrage. Mesurer le délai effectif d'apparition. Corriger les écarts éventuels.

## Sécurité et confidentialité

- **Ne pas committer** les exports Apple Santé, identifiants d'utilisateur, JWT, URL privées contenant un secret ni données GPS.
- La clé publique de Supabase peut être présente dans l'application ; les **jetons utilisateurs** doivent rester dans Keychain côté iOS et dans le stockage du navigateur uniquement après consentement.
- Le schéma active RLS et refuse toute lecture anonyme. Une requête `POST` est authentifiée par le JWT et insère `user_id = auth.uid()` côté base.
- La PWA est sur GitHub Pages, un site public. **Les données de santé ne doivent jamais être publiées via GitHub Pages ou GitHub Actions**.
- Les routes GPS sont volontairement **non collectées** par ce prototype. Les détails de fréquence cardiaque sont des données sensibles.
- Une application distribuée avec HealthKit doit respecter les règles Apple et les exigences RGPD (consentement clair, export, suppression de données, transparence, durée de conservation, etc.). Aucune utilisation publicitaire.

## API utilisée

`POST /rest/v1/health_workouts?on_conflict=user_id,source_uuid` avec headers `apikey` (clé publique), `Authorization: Bearer <user JWT>`, `Prefer: resolution=merge-duplicates,return=minimal`.

`GET /rest/v1/health_workouts?select=...&order=started_at.desc&limit=500` avec les mêmes en-têtes d'authentification.

À compléter avant sortie publique : synchronisation des suppressions de Santé, mécanisme de re-synchronisation sur 30 jours, parcours clair de réauthentification, historique complet de toutes les séries, et suppression du compte / données.
