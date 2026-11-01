# PACE LAB 2.4 — Simplicité et cohérence UX

## Objectifs
Rendre les informations sportives compréhensibles immédiatement sans retirer les fonctionnalités détaillées. Respecter le design Apple natif et préserver la confidentialité des données Apple Santé.

## Modifications
- **Fiche de course progressive** : fréquence cardiaque en premier; analyses supplémentaires cachées derrière « Découvrir les mesures avancées »; graphiques interactifs conservés mais préparés uniquement pour le type choisi.
- **Intervalles et comparaison** : fermés par défaut, accessibles d'un toucher; le menu de navigation ouvre la section correspondante avant le défilement.
- **Explications** : bouton d'information pour chaque courbe (cardio, allure, puissance, longueur de pas, contact au sol, oscillation verticale), sans diagnostic ni promesse de progression.
- **Aujourd'hui** : disparition de la grande carte de confidentialité et du doublon « Dernière sortie » (la dernière séance est déjà accessible en haut); introduction de la distance du mois.
- **Progrès** : la série des fréquences cardiaques correspond désormais à l'année sélectionnée, comme la distance et le nombre de courses.
- **Nutrition** : sélection du jour prévu si ce jour se trouve dans le programme; sinon prochaine journée future (ou dernière journée lorsque le cycle est dépassé); il n'est plus présenté comme « aujourd'hui » lorsqu'il ne l'est pas.
- **Liste de courses** : regroupement par nom d'ingrédient et addition de toutes les quantités en grammes. Les cases enregistrées auparavant sont respectées via les identifiants de lignes d'origine. Une seule case pilote toutes les occurrences d'un produit.
- **Programme et Santé** : lorsqu'une séance Apple Santé de type correspondant existe à la même date, l'application propose de la reconnaître; **validation toujours explicite** et aucune supposition sur les consignes réellement respectées.
- **Terminologie** : « Difficulté ressentie » au lieu de « RPE » dans le formulaire; « mesures supplémentaires » au lieu de « télémétrie » dans Réglages.

## Tests
- Validation PWA, smoke, contrat HealthKit, contrat SwiftUI, contrat de quantités des courses.
- L'agrégation préserve les 98 lignes du programme sous 39 ingrédients distincts. Ce contrôle est purement fondé sur les recettes publiques et n'utilise aucune donnée de santé.
- Compilation Xcode et installation iOS à vérifier sur le Mac et l'iPhone réels.
- La vérification tactile de tous les menus et l'accessibilité dynamique complète demandent encore des essais interactifs.

## Limites
La correspondance Apple Santé n'est pas une preuve que la séance prévue a été exécutée intégralement : il s'agit d'une **suggestion à confirmer**. La comparaison de courses ne compense pas la météo, la pente ou la fatigue. Aucune information personnelle n'est synchronisée via GitHub.
