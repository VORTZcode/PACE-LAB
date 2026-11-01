# PACE LAB V3.4 — Courbes synchronisées pour ChatGPT

## Pourquoi cette version

L'Apple Watch enregistre davantage d'informations qu'un résumé « distance + cardio moyen » : fréquence cardiaque, vitesse/allure, puissance, longueur de pas, temps de contact au sol et oscillation verticale. Le projet enregistrait déjà ces séries dans le conteneur privé de l'iPhone, et les présentait dans les fiches de course, mais le Coach ne transmettait que leurs moyennes, sauf pour le cardio. Les captures Apple Fitness utilisées auparavant pouvaient montrer ces six axes ; cette version apporte un contexte numérique plus complet.

## Extraction et confidentialité

Une option facultative **« Analyse croisée de toutes les courbes »** est ajoutée aux réglages **Coach → Compte et données → Confidentialité et données**. Elle est **désactivée par défaut** et exige l'autorisation générale des résumés de course.

Lorsqu'elle est activée, PACE LAB produit un profil simultané pour les six mesures :
- Fréquence cardiaque, en bpm.
- Vitesse enregistrée par HealthKit, traduite en allure min/km.
- Puissance, en watts.
- Longueur de pas/foulée, en mètres.
- Temps de contact au sol, en millisecondes.
- Oscillation verticale, en centimètres.

Les échantillons sont regroupés **par tranches temporelles alignées sur le début de la séance** (1 minute pour les séances courtes, intervalles plus larges pour les longues sorties), au maximum 120 intervalles. Les moyennes sont calculées **sur l'iPhone** ; les valeurs indisponibles restent absentes et ne sont jamais interpolées. Le nombre de points sources par mesure est conservé dans le résumé pour préciser la couverture. Ce n'est pas un transfert exhaustif des échantillons bruts ni une exportation d'une trace GPS.

L'utilisateur peut cliquer sur « Voir le résumé sportif partagé » pour afficher le **contenu exact du contexte généré** à partir des préférences de partage et de la séance sélectionnée. Une fois la requête lancée, ce résumé est envoyé à OpenAI avec l'accord de l'utilisateur. Enregistrer des données HealthKit localement et les faire analyser par ChatGPT sont deux opérations distinctes.

Les cases de partage existantes restent indépendantes : cardio minute par minute ; moyennes de puissance/foulée/récupération ; notes/RPE/gêne ; dernier poids ; nutrition ; profil athlète. Il n'est jamais nécessaire de transmettre automatiquement l'intégralité des données de santé.

## Interprétation scientifique

L'analyse croisée permet de voir la variation conjointe d'allure, puissance, fréquence cardiaque et mouvement pendant une même sortie. Elle ne suffit pas, à elle seule, à évaluer l'efficacité énergétique, une dérive cardiaque physiologique ou la fatigue sans connaître les intervalles, le dénivelé, le terrain, les conditions, les pauses et les autres facteurs susceptibles d'influer sur ces données.

La cadence reste **une estimation** dans PACE LAB tant qu'aucune mesure directe n'est enregistrée ; les valeurs brutes inexistantes ne sont pas fabriquées.

## Validation

- Compilation Xcode SwiftUI en utilisant les champs de données HealthKit déjà présents.
- Test Swift autonome sur séries fictives : alignement temporel, moyennes, conversion en allure, respect des intervalles manquants et absence de données de localisation.
- Contrats PWA, HealthKit, UX, OAuth et options de partage.
- Installation signée sur iPhone et présence vérifiée du conteneur HealthKit existant.

## Suite

Le point réellement important à valider avec l'utilisateur est la qualité d'une réponse ChatGPT lorsque l'option de courbes synchronisées est activée, et si des données avancées sont disponibles pour sa séance. Si des courbes sont absentes, vérifier les autorisations **Réglages → Apple Santé → accès PACE LAB** et la synchronisation des mesures supplémentaires sans supposer qu'une Apple Watch enregistre toutes les mesures sur toutes les activités.
