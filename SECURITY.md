# Politique de confidentialité technique

- Dépôt et site statique : aucune donnée médicale préchargée.
- Import Santé : réalisé dans le navigateur ; stockage localStorage sur cet appareil.
- Aucun backend, compte, synchronisation, secret serveur ou chiffrement de bout en bout n'existe encore.
- GitHub Pages publie les fichiers statiques publiquement. Ne jamais déposer un export Santé, une sauvegarde JSON ou un identifiant personnel dans le dépôt.
- Les sauvegardes sont à conserver hors du dépôt dans un espace privé choisi par l'utilisateur.
- La version actuelle n'a pas de synchronisation entre appareils. Les données de santé ne sont pas téléversées sur GitHub ou vers un serveur.

### Synchronisation Apple Santé (expérimentale)

Le répertoire `ios/` contient uniquement du code. L'application native autorise l'accès HealthKit après consentement et conserve les données sur l'iPhone, dans le stockage d'application protégé par iOS. Aucune clé Supabase ni aucun compte ne sont nécessaires. Valider sur un iPhone réel les autorisations Santé, le traitement des suppressions d'entraînements, la restauration après suppression de l'app, et le comportement en arrière-plan avant tout usage quotidien.
