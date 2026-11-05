# PACE-LAB V5.9 — Audit produit, navigation et autonomie du Coach

**Date :** 5 novembre 2026. **Support :** SwiftUI iPhone natif, Apple Santé, intégration ChatGPT. **Champ :** 5 destinations, écrans de détail, collecte, raisonnement autonome et parcours utilisateur.
**Principe de conception :** une priorité à l'écran, les données utiles en deuxième niveau, les détails techniques uniquement à la demande. Une donnée indisponible n'est ni inventée ni présentée comme un échec sportif.

## 1. Verdict général

La structure à cinq onglets reste appropriée : Aujourd'hui pour agir, Activités pour constater, Programme pour planifier, Coach pour comprendre/échanger et Nutrition pour préparer les repas. Les problèmes ne justifiaient pas une sixième rubrique, mais un nouveau tri de l'information.

Problèmes observés dans le code avant cette révision :
- un statut d'automatisation, un bilan local et une analyse ChatGPT pouvaient coexister sur l'accueil sans hiérarchie ;
- la page Coach affichait plusieurs cartes, introductions et justifications répétées **avant** une conversation ;
- le journal d'une décision réunissait en un paragraphe sa raison, ses alternatives, son effet attendu et ses incertitudes, puis répétait ces trois derniers champs ;
- la détection automatique examinait surtout l'activité HealthKit la plus récente : une séance plus ancienne, mais récemment synchronisée, pouvait passer derrière ;
- une réponse ChatGPT complète n'apparaissait pas spontanément dans la discussion avec le Coach ;
- une activité validée était visible dans Programme, mais suivie de l'intégralité des consignes initiales, même après l'effort ;
- le programme suivant et ses quatorze repas demandaient une demande explicite, alors que le Coach autonome pourrait préparer une proposition révisable.

## 2. Inventaire : conserver, simplifier, déplacer ou automatiser

| Destination / élément | Pourquoi il existe | Diagnostic / décision V5.9 |
| --- | --- | --- |
| Barre inférieure (5 onglets) | Fournit une carte mentale stable | **Conserver.** Aucun nouveau menu ou sous-onglet principal. |
| Accueil — prochaine séance | Permet de savoir quoi faire sans réfléchir | **Conserver au premier plan.** Bouton unique vers le détail. |
| Accueil — série d'exercices | Permet de reprendre le renforcement en cours | **Conserver lorsqu'une séance de musculation est prévue**, pas sur toutes les cartes. |
| Accueil — statut autonome en phrase | Indique que le Coach fonctionne | **Supprimé de l'accueil** : le statut est consultable dans Coach. |
| Accueil — « Coach évolutif » détaillé | Donne une lecture locale de l'historique | **Remplacé par un signal prioritaire conditionnel**. Ne rien montrer si aucun événement utile. |
| Accueil — humeur/ressenti manquant | Encourage une donnée importante après l'effort | **Conserver seulement si la course est récente** (moins de 36 heures) et si aucune information plus urgente ne prévaut. |
| Accueil — bilan GPT disponible | Permet de consulter un compte rendu nouveau | **Conserver** pendant la période pertinente, deux lignes maximum, détail à une touche. |
| Accueil — décision de modification | Informe d'une adaptation effective | **Priorité élevée**, avec renvoi pour contrôle/annulation. |
| Accueil — distance 7 jours et mois | Suivi simple de la régularité | **Conserver** sous la séance et les actions, liens vers les vues détaillées. |
| Accueil — rappel de confidentialité | Évite une interprétation erronée du transfert | **Déplacé hors de l'accueil** : informations conservées dans les autorisations, où elles peuvent être comprises et modifiées. |
| Activités — filtres Course/Muscu/Marche/Tout | Retrouver les données selon l'activité | **Conserver**, pas de réorganisation fréquente. |
| Activités — Progression | Accès à l'historique et aux tendances | **Réduire à une entrée compacte**, conserver toute l'analyse en deuxième niveau. |
| Activités — année et historique | Accéder aux séances réelles enregistrées | **Conserver** avec pagination ; ne pas réduire à une période arbitraire. |
| Détail d'activité — durée, distance, allure | Faits mesurés prioritaires | **Conserver en haut** ; ne pas les confondre avec les objectifs du programme. |
| Détail — graphique cardiaque | Lire la réponse cardiovasculaire pendant l'effort | **Conserver**, sous forme de courbe temps/bpm vérifiée sur iPhone réel (V5.8), sans valeurs inventées dans les lacunes de mesure. |
| Détail — comparaison à une autre course | Contextualiser les tendances | **Conserver si distances comparables** ; avertissement sur terrain, fatigue, météo et pauses. |
| Détail — profil cardiaque minute par minute | Peut enrichir l'analyse IA | **Partager uniquement sur autorisation spécifique** ; une FC ne fournit pas seule un diagnostic. |
| Détail — récupération | Décrire les mesures après l'arrêt | **Conserver**, mais pas de score clinique de « readiness » calculé sans validation. |
| Détail — bilan du Coach | Relier l'activité à la prochaine décision | **Conserver en haut, bref**, distinction explicite GPT vs mesures locales, développement à la demande. |
| Programme — bilan hebdomadaire | Distinguer réalisé, non réalisé et prévu | **Conserver** ; les séances manquées ne sont pas des séances terminées. |
| Programme — fréquence différente du profil | Signale un vrai conflit d'entraînement | **Réduit à une ligne actionnable** ; la semaine en cours n'est pas modifiée sans justification. |
| Programme — activité réellement enregistrée | Évite que l'utilisateur doive revenir dans Activités | **Conserver immédiatement après l'en-tête** de la séance ; association prudente en cas de multiples activités. |
| Programme — consignes de la séance | Guider l'exécution | **Conserver avant l'effort ; replier après enregistrement ou validation** pour ne pas masquer la restitution réelle. |
| Programme — séries de musculation | Permettre suivi précis répétitions/temps/charge | **Conserver**, car ce sont des données que la montre ne déduit pas. |
| Programme — « non réalisée » et motif | Représente un imprévu sans culpabilisation | **Conserver**, réversible ; aucune séance punitive ni rattrapage par défaut. |
| Nutrition — choix du jour | Relier repas et entraînement | **Conserver** accessible immédiatement. |
| Nutrition — liste de courses | Aide à exécuter le programme | **Conserver**, intitulé court, visible. |
| Nutrition — double titre introductif | Ne changeait aucune action | **Supprimé** ; une ligne « Repas de la semaine » suffit. |
| Nutrition — kcal/protéines | Donne un repère pour les menus | **Conserver uniquement comme estimation**, jamais comme consommation réelle. |
| Nutrition — mention féculents crus | Évite une erreur de pesée | **Conserver une seule fois**, près des informations alimentaires. |
| Coach — introduction et promesses répétées | Présentait une valeur déjà comprise après connexion | **Masquée quand le profil est confirmé**. |
| Coach — statut | Comprendre activation et blocages | **Conserver compact** : actif, activités en attente, cas demandant une reprise. |
| Coach — bouton de configuration | Permet consentements et désactivation | **Conserver dans l'en-tête et les réglages**, pas de longues cartes répétées. |
| Coach — discussion | Dialogue naturel et suivi de la progression | **Destination par défaut**, bulles différenciées et réponse progressive. |
| Coach — bilans | Analyser l'activité sélectionnée | **Conserver en rubrique secondaire** ; résumé et action avant observations/limites détaillées. |
| Coach — programme | Préparer et inspecter le prochain cycle | **Conserver**, proposition prioritaire et données/méthode repliées. |
| Coach — détails de sommeil/charge | Justifient les propositions lorsque disponibles | **Derrière une rubrique dépliable**, pas avant le dialogue. |
| Coach — journal de décisions | Audit, responsabilité et possibilité de revenir en arrière | **Conserver** sans répétitions textuelles ; détails structurés visibles sur demande. |
| Coach — paragraphes d'avertissement répétés | Surcharge visuelle peu utile | **Supprimer là où les réglages et la validation suffisent**, conserver les informations de sécurité au point de décision. |

## 3. Nouvelle stratégie d'automatisation

**La file d'analyse** parcourt jusqu'à huit activités récentes admissibles de la dernière semaine, avec une identité de séance explicite (UUID), au lieu d'analyser toujours « la dernière activité ». Les sessions sont traitées progressivement, avec une attente de 25 secondes au minimum entre démarrages. Les réponses valides et déjà enregistrées sont ignorées.

**Échecs et reprise** : la première erreur laisse un compte rendu mesuré local clairement étiqueté. Le Coach réessaie au maximum trois fois par séance (30 min après le premier essai, puis 2 h après le second). Un troisième échec demande un examen manuel : pas de boucles d'appels IA. Ce sont des délais opérationnels, pas des seuils médicaux. Les échecs d'une séance ne bloquent pas toutes les autres. Les tentatives sont enregistrées localement par UUID.

**Initiative du Coach** : un bilan GPT valide est transmis une seule fois au fil de discussion, avec synthèse et action prioritaire ; les résultats des séances ne nécessitent donc plus de question répétitive. Les décisions réellement importantes (adaptation appliquée ou examen demandé) apparaissent également une fois dans le dialogue. Les simples maintiens ne produisent pas une nouvelle bulle.

**Raisonnement et non inflation de décisions** : l'analyse de chaque séance reste distincte du contrôle du programme. Si deux domaines indépendants localement validés ne sont pas présents, un nouvel appel GPT « faut-il changer le programme ? » est évité, car une modification ne serait de toute façon pas autorisée. Une gêne importante peut bloquer localement l'adaptation et déclencher une information pertinente, sans partage de la douleur lorsque ce partage est refusé.

**Préparation automatique de la prochaine semaine** : à deux jours au plus de la fin du cycle, lorsque l'autonomie est activée et les autorisations obtenues, le Coach peut préparer de lui-même une nouvelle proposition : sept journées, midi et soir. Une tentative au plus par 24 heures et par cycle, jamais une adoption automatique du nouveau programme ou des menus. L'athlète doit encore examiner et valider la proposition.

**Consentement et prévention** : aucune invention de symptômes, aucune interprétation médicale automatique, pas de hausse de charge autonome ni d'ajout d'une séance de compensation après une absence. Les notifications liées à la sécurité parlent de l'action à consulter, sans afficher de données médicales privées sur l'écran verrouillé.

## 4. Ce qui manque encore pour un « coach sans friction » complet

1. **Vérification réelle d'un cycle complet** : Apple Watch → récupération Santé → génération d'un bilan GPT valable → conversation → décision justifiée → modification réversible → observation après la séance suivante. Les compilations et tests unitaires ne suffisent pas.
2. **Garantie d'exécution hors application** : iOS peut suspendre les tâches de fond ; l'application rattrape les analyses à la prochaine activation, mais ne peut promettre un service continu comme un serveur.
3. **Évaluation scientifique** : le temps, les kilomètres, la FC et le sommeil ne prouvent pas automatiquement qu'un changement de programme a causé une progression. Suivre les tendances sur plusieurs semaines avant de recalibrer les règles.
4. **Édition complète d'un programme autonome** : les allègements prudents peuvent déjà être appliqués ; les refontes hebdomadaires et nutritionnelles restent des projets proposés à confirmer.
5. **Accessibilité et ergonomie en conditions extrêmes** : tests VoiceOver, taille maximale des textes, couleurs de contraste, téléphone utilisé d'une seule main, très longues réponses du Coach et très nombreuses séances.
6. **Exercices et illustrations** : poursuivre la vérification anatomique de toutes les positions et remplacer les images provisoires qui ne correspondent pas exactement au matériel disponible. Ce sujet est identifié, pas résolu par cette version.

## 5. Critères de réception V5.9

- [x] Le modèle d'automatisation peut traiter plusieurs séances, sans réutiliser le mauvais UUID lors de la génération.
- [x] Les échecs sont limités et mémorisés, les comptes rendus locaux sont distincts des réponses ChatGPT.
- [x] Un bilan GPT produit une intervention unique du Coach ; pas de bulle supplémentaire pour chaque statut « maintenir ».
- [x] La discussion est prioritaire et affiche les réponses progressivement.
- [x] L'accueil est silencieux en l'absence d'événement nécessitant une action.
- [x] Les détails de mesures et de méthode sont accessibles, mais repliés par défaut.
- [x] Le programme suit l'activité réellement réalisée, sans imposer une explication technique après chaque séance.
- [x] Les boutons de l’accueil conduisent au bilan, au programme ou aux réglages concernés, et non à un onglet générique.
- [x] Le prochain cycle peut être proposé automatiquement, sans remplacement silencieux.
- [x] Les notifications ne contiennent pas le détail des renseignements médicaux.
- [ ] Validation de bout en bout sur une nouvelle séance réelle avec la connexion ChatGPT fonctionnelle.
- [ ] Mesures de lisibilité détaillées avec VoiceOver / Dynamic Type / utilisateur final.

## 6. Documentation de contrôle

Tests dans `tests/coach-v59-product-audit-contract.mjs`, `tests/autopilot-fixture.swift` et contrats hérités mis à jour. Les captures de données Apple Santé personnelles ne sont pas publiées sur GitHub. Le code Xcode est validé puis installé sur le dispositif physique pour contrôle du démarrage.

**Conclusion :** le produit ne doit pas faire « parler » l'IA en permanence. Il doit analyser automatiquement quand cela a une utilité, formuler des décisions concises et montrer comment elles affectent le programme. Le silence et la stabilité sont parfois les bonnes réponses.
