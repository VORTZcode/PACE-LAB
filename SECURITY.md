# Politique de confidentialité technique

- Dépôt et site statique : aucune donnée médicale préchargée.
- Import Santé : réalisé dans le navigateur ; stockage localStorage sur cet appareil.
- Aucun backend, compte, synchronisation, secret serveur ou chiffrement de bout en bout n'existe encore.
- GitHub Pages publie les fichiers statiques publiquement. Ne jamais déposer un export Santé, une sauvegarde JSON ou un identifiant personnel dans le dépôt.
- Les sauvegardes sont à conserver hors du dépôt dans un espace privé choisi par l'utilisateur.
- Pour la synchronisation multi-appareils, prévoir ultérieurement authentification, autorisations RLS et stockage serveur sécurisé.

### Synchronisation Apple Santé (expérimentale)

Le répertoire `ios/` ne contient ni donnée de santé ni clé secrète. Les fichiers de synchronisation nécessitent un projet Supabase dédié avec Auth + RLS et n'utilisent que la clé **publishable**. Aucune clé `service_role` ne doit être utilisée sur iPhone ou dans GitHub Pages. Des jetons personnels sont conservés dans le trousseau iOS et localement sur le navigateur connecté. Avant la mise en production, valider les politiques de suppression RGPD, les règles Apple HealthKit, le comportement lors du changement de compte, les conflits de synchronisation et les tests sur iPhone réel.
