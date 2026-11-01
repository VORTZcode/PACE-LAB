# PACE LAB V3.3 — Adaptation post-séance et profil confortable

## Changements UX
Les champs d'objectifs du profil ont été remplacés par de vrais éditeurs multiligne en pleine largeur, avec une typographie iOS standard et une hauteur minimale d'environ 100–142 points. Les étiquettes sont positionnées au-dessus du texte plutôt que latéralement. Les domaines traités : course, composition corporelle, motivation, contraintes, gênes éventuelles, habitudes alimentaires.

Le programme initial réel `pace-programme.json` contient **3 séances de course + 3 séances de musculation + 1 récupération** (lundi musculation, mardi course, mercredi musculation, jeudi course, vendredi musculation, samedi récupération, dimanche sortie longue). Les suggestions par défaut du profil sont alignées à **3 + 3**. Une préférence déjà enregistrée par l'utilisateur n'est pas écrasée.

## Réaction native à une nouvelle activité
Une fois les données Apple Santé reçues et la sortie terminée depuis au moins 3 minutes, PACE LAB réalise un point **sur l'iPhone, sans requête ChatGPT** :
- Données subjectives incomplètes : demande au coureur l'effort perçu et une éventuelle gêne (0 = aucune, jusqu'à 10). Le ressenti n'est jamais inventé depuis le cardio.
- Ressenti modéré et absence de signal significatif : maintenir le programme. Ne pas augmenter une intensité automatiquement après une bonne séance.
- RPE >= 8/10 ou gêne faible déclarée, ou distance de séance supérieure à 110 % du maximum des 30 jours antérieurs : proposition de réduire la durée de la prochaine course d'environ 20 % et de la faire facilement. Ce sont des *heuristiques d'alerte*, pas des seuils médicaux validés. Le comparatif de distance est inspiré d'une cohorte de 5 205 coureurs.
- Gêne déclarée >= 4/10 : proposition de pause pour la prochaine course, avec recommandation de consulter si douleur importante/persistante. Une gêne n'est pas un diagnostic.

Ces règles servent à **éviter d'accentuer une charge potentiellement mal tolérée**, pas à calculer une « forme » ou à garantir la performance. Elles sont codées indépendamment du modèle ChatGPT. Chaque recommandation conserve ses raisons explicites.

Le panneau « Après ta dernière sortie » apparaît dans Coach > Ma séance. L'utilisateur décide de noter son ressenti, conserver le programme ou accepter la seule adaptation proposée. Les modifications n'affectent **qu'une future séance de course non validée**, jamais les repas, les jours déjà effectués ni le reste du cycle. Une annulation est accessible dans Programme.

## IA et programme
Le bilan ChatGPT reste distinct du moteur déterministe et peut contextualiser les statistiques sélectionnées. La création complète d'une semaine exige toujours un profil confirmé, des objectifs, les mesures de charge disponibles, des distances et intensités proposées, un motif explicite et une vérification locale avant adoption. Aucun remplacement silencieux ni augmentation automatique n'est autorisé.

L'option de bilan automatique existante dépend de l'autorisation de l'utilisateur, de la réception des mesures par HealthKit et des contraintes iOS en arrière-plan. L'analyse locale se déclenche à la réception des mises à jour et au prochain réveil de l'application ; **un déclenchement précis à 3 minutes en arrière-plan n'est pas garanti**.

## Données privées
Les notes et le ressenti sont enregistrés localement. Les propositions et adaptations approuvées sont conservées dans `Application Support` avec protection de fichiers iOS. Rien n'est publié dans GitHub et ces données ne sont pas envoyées à OpenAI par la seule utilisation du moteur local. Elles ne sont communiquées au coach distant que si le partage pertinent est autorisé.

## Vérification et références
Le moteur a été exercé sur des séances synthétiques : faible effort (conserver), effort difficile (alléger), gêne importante (pause), dépassement de distance (alléger), ressenti absent (demander), et propositions nécessitant accord explicite. Ces tests de logiciel ne sont pas des expérimentations d'entraînement sur le sportif.

Fondements à lire :
- Étude de cohorte 2025, 5205 coureurs, distance d'une sortie et surutilisation : https://pubmed.ncbi.nlm.nih.gov/40623829/
- ACSM, position stand renforcement musculaire 2026 : https://www.apta.org/patient-care/evidence-based-practice-resources/cpgs/american-college-of-sports-medicine-position-stand-resistance-training-prescription-for-muscle-function-hypertrophy-and-physical-performance-in-healthy-adults-an-overview-of-reviews

Aucun protocole, algorithme ou produit logiciel ne peut garantir un gain de performance individuel. La stratégie privilégie des méthodes étayées, une progression prudente et le suivi longitudinal des réponses.
