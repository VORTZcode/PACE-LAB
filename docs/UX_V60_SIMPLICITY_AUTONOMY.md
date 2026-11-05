# PACE-LAB V6.0 — Simplicité, dialogue, lecture du programme

Date : 5 novembre 2026. Application : SwiftUI natif, iPhone, Apple Santé et ChatGPT.

## Décisions produit

| Élément | Problème constaté | Décision V6.0 |
|---|---|---|
| Conversation Coach | Le champ de saisie se retrouvait après l'historique et pouvait sortir de l'écran. | Zone de saisie fixe en bas du Coach ; messages et saisie indépendants. |
| Lecture des nouveaux messages | Une longue conversation demandait de faire défiler manuellement. | Retour au dernier message à l'ouverture, à l'envoi et lors de la réponse en cours, avec défilements progressifs. |
| Historique | Seulement 24 messages conservés localement pour l'affichage et la reprise. | Jusqu'à 100 messages conservés localement avec protection de fichier après premier déverrouillage ; le contexte distant reste limité pour réduire les partages inutiles. |
| Accueil du Coach | La bannière de fonctionnement autonome consommait de l'espace même quand tout allait bien. | Affichage seulement si mode manuel, bilan en attente, intervention ou nouveau programme à examiner. Les réglages restent en haut. |
| Messages des bilans | Résumés trop longs ou coupés sans ponctuation. | Messages d'initiative raccourcis et coupés sur une frontière de mot ; le rapport exhaustif reste dans Bilans et la fiche Activité. |
| ChatGPT | Réponses génériques ou répétitives sans hiérarchie des informations. | Consignes de dialogue : répondre d'abord, adapter la profondeur à la demande, ne citer que les chiffres utiles et distinguer mesure, hypothèse et décision. |
| Programme hebdomadaire | « 1 activité Apple Santé » ne permettait pas d'identifier la sortie. | Afficher catégorie, distance et durée lorsqu'une seule activité du type attendu est associable au jour. |
| Association séance/activité | Plusieurs enregistrements du même type le même jour rendaient le rapprochement ambigu. | Une unique fonction partagée refuse d'inférer le rattachement s'il existe plusieurs candidates ; aucune association assimilée à une validation du plan. |
| Fiche d'une séance future | Message d'absence d'enregistrement affiché avant l'entraînement, sans utilité. | Masquer l'état Apple Santé tant qu'il n'existe aucune activité et qu'aucune validation manuelle n'a eu lieu. |
| File d'analyse automatique | Après un échec espacé de 30 min ou 2 h, l'application ouverte pouvait attendre un nouvel événement Santé. | Vérification légère toutes les 65 secondes en premier plan, toujours subordonnée aux consentements et aux protections contre les appels répétés. |
| Première connexion | Explications de confidentialité et promesses répétées. | Un paragraphe redondant supprimé. |

## Logique d'autonomie inchangée et importante

L'IA commente chaque séance admissible lorsque le partage a été autorisé. Le journal automatique peut publier un résumé unique ; son analyse complète demeure accessible sans noyer l'accueil. L'utilisateur peut toujours demander une analyse détaillée en conversation. Le Coach n'a pas la liberté d'inventer des données ou d'appliquer des charges plus fortes sans validation : la stabilité du programme et les gardes-fous locaux priment sur des variations isolées.

Les reprises périodiques en premier plan ne constituent **pas une garantie d'exécution lorsque iOS suspend l'application**. Le rattrapage au retour au premier plan reste indispensable.

## Contrôles

- Compilation iOS simulateur : réussie.
- Compilation iOS signée pour l'iPhone : réussie.
- 34 fichiers de tests de contrat JavaScript : réussis.
- Capture du Coach non connecté sur simulateur : lancement et interface visibles ; une première capture prise durant le chargement était blanche.
- Installation et lancement sur l'iPhone 16 Pro connecté : confirmés par devicectl, avec le même Bundle ID `com.pacelab.healthcompanion`.

## À vérifier en conditions réelles

1. Rédiger plusieurs messages, faire défiler et utiliser le clavier, puis vérifier que la zone de saisie reste accessible et que le fil revient à la réponse récente.
2. Enregistrer une nouvelle sortie Apple Watch et confirmer chaîne Apple Santé → bilan GPT validé → message spontané → bilan détaillé → éventuel ajustement prudent.
3. Vérifier la session sur l'iPhone avec le compte connecté et les autorisations existantes. La capture du simulateur non connecté ne permet pas d'observer cet état.
4. Poursuivre les essais d'accessibilité VoiceOver et caractères agrandis, en particulier sur petit écran.

**Principe de conception :** réduire les gestes et le texte inutiles, sans sacrifier la preuve des décisions ni la confidentialité.
