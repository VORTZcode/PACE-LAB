# PACE LAB V3 — Coach ChatGPT, abonnement personnel et adaptation

## Architecture

PACE LAB V3 utilise « Sign in with ChatGPT » pour les applications open source et locales, via le flux officiel OAuth avec enregistrement dynamique (agent `dynamic_agent_client`). Ce flux permet aux utilisateurs ChatGPT Plus ou Pro éligibles d'autoriser des requêtes Responses sur leur abonnement.

Il ne donne **aucun accès automatique** aux conversations, souvenirs, fichiers ni autres données du compte ChatGPT. Le coach reçoit uniquement le contexte préparé par PACE LAB, sur des autorisations explicites.

Aucun Supabase, aucune clé API intégrée à l'application, aucun stockage personnel sur GitHub.

Documentation officielle :
- https://developers.openai.com/siwc/token-sharing-open-source/sign-in
- https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference
- https://developers.openai.com/siwc/token-sharing-open-source/errors-and-recovery
- https://help.openai.com/fr-fr/articles/20001542-using-your-chatgpt-plan-in-other-apps-and-sites

## Connexion à l'abonnement

1. Sur l'iPhone, ouvrir PACE LAB → carte « Ton coach ChatGPT ».
2. Toucher « Continuer avec ChatGPT ». Le navigateur ouvre l'autorisation officielle d'OpenAI.
3. Se connecter, sélectionner le compte et **accepter explicitement l'utilisation de l'abonnement**.
4. Le callback OAuth revient sur une écoute HTTP locale 127.0.0.1 avec PKCE, state et nonce. L'ID token est vérifié contre le JWKS officiel (signature RS256, issuer, audience, nonce et expiration).
5. Les jetons d'accès et de renouvellement sont enregistrés dans le trousseau protégé de l'iPhone. Les modèles disponibles sont découverts auprès de `https://api.openai.com/v1/models`. Aucun secret n'est enregistré dans les sources.
6. Les appels IA ont `store=false`, `stream=true` et ne sont acceptés comme réussis qu'après `response.completed`. En cas de refus ou de limite ChatGPT, aucune requête supplémentaire n'est automatiquement redirigée vers une facturation API séparée.

**La connexion réelle et l'attribution de permissions doivent être testées par l'utilisateur sur son iPhone.** La compilation seule ne prouve pas que l'autorisation a abouti.

## Confidentialité et consentement

Par défaut, les trois réglages de partage sont désactivés : résumés des huit dernières courses, dernier poids déclaré et quelques intitulés de repas. L'utilisateur peut consulter un aperçu des données de sport envoyées avant la première requête. Les courbes cardiaques brutes, positions GPS et parcours ne sont jamais transmis.

L'option « Préparer automatiquement un bilan » est également **désactivée par défaut**. Si elle est activée après les autorisations et la connexion au compte, une nouvelle course ne peut déclencher l'analyse qu'après l'arrêt et la fenêtre initiale de récupération (~3 minutes), lorsque l'application reçoit les données HealthKit (délai iOS non garanti). Une requête automatique pour la même course n'est pas répétée en boucle.

Les conversations du coach restent dans le conteneur privé de l'iPhone, chiffré/protégé par la protection des fichiers iOS, et n'utilisent pas l'historique des conversations ChatGPT. L'envoi du contexte sportif choisi constitue une transmission aux services OpenAI et n'est donc pas un traitement purement hors ligne.

## Proposition et validation

Le coach peut :
- discuter des sorties, de l'endurance, de la récupération et de l'alimentation ;
- proposer **sept journées consécutives** d'entraînement et **quatorze repas** ;
- signaler des précautions et expliquer les changements ;
- attendre la validation explicite avant de remplacer le programme affiché ;
- restaurer le programme précédent sur demande.

Le programme est vérifié localement : dates, format, nombre de jours, temps de séance, présence d'au moins une journée de repos/récupération, repas complets et valeurs énergétiques plausibles. L'application n'établit aucun diagnostic médical et ne doit pas prescrire une restriction alimentaire extrême.

Le contenu accepté reste local dans PACE LAB ; la version d'origine reste récupérable. Les cycles de nouvelles séances ne sont pas publiés sur GitHub.

## Limites actuelles

- Pas d'accès à la mémoire ni aux conversations précédentes de ChatGPT depuis l'application.
- Pas de garantie de déclenchement exact en arrière-plan : dépend des notifications HealthKit, du verrouillage et du réseau iOS.
- L'application doit obtenir le consentement utilisateur et une réponse OAuth valide avant toute analyse distante. Cette étape ne peut pas être complétée sans le propriétaire du compte.
- La validation tactile du sign-in, de la liste des modèles et de la première requête réelle reste nécessaire sur l'iPhone.
- Le plan est proposé et vérifié, mais reste du conseil sportif général : douleur, blessure, malaise et symptômes inhabituels nécessitent une évaluation humaine.
