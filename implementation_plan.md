# Projet : Ending Letter (Jeu de Mots)

L'objectif de cette révision est de transformer l'application existante, qui était une expérience d'écriture de lettres narratives, en un jeu de mots dynamique appelé **Ending Letter**. Dans ce jeu, un joueur propose un mot en anglais, et le joueur suivant doit proposer un mot en anglais commençant par la dernière lettre du mot précédent.

## User Review Required

> [!IMPORTANT]  
> Ce plan implique la **suppression complète de l'ancien code** (écrans de lettres, modèles narratifs) pour le remplacer par le jeu. Veuillez confirmer que vous êtes d'accord pour effacer l'ancienne logique.

> [!NOTE]  
> Le jeu validera les mots anglais en utilisant une API publique gratuite (comme `dictionaryapi.dev`). Cela signifie qu'une connexion internet sera requise pour jouer.

## Open Questions

> [!WARNING]  
> 1. **Mode de jeu** : Souhaitez-vous que le jeu soit un mode "Pass & Play" (joueurs locaux sur le même téléphone) ou voulez-vous que le joueur joue contre une Intelligence Artificielle (IA) ? Pour le moment, je propose un mode Pass & Play local à 2 joueurs.
> 2. **Chronomètre** : Souhaitez-vous ajouter une limite de temps pour chaque tour (ex: 30 secondes) pour augmenter le défi ?

## Proposed Changes

### Configuration et Dépendances
#### [MODIFY] [pubspec.yaml](file:///home/asus/Documents/endingletter/pubspec.yaml)
- Ajout du package `http` pour les requêtes à l'API du dictionnaire.
- Conservation de `google_fonts` et `flutter_animate` pour une interface utilisateur esthétique et dynamique.

---

### Suppression de l'Ancien Code
#### [DELETE] [lib/screens/home_screen.dart](file:///home/asus/Documents/endingletter/lib/screens/home_screen.dart)
#### [DELETE] [lib/screens/letters_screen.dart](file:///home/asus/Documents/endingletter/lib/screens/letters_screen.dart)
#### [DELETE] [lib/screens/write_screen.dart](file:///home/asus/Documents/endingletter/lib/screens/write_screen.dart)
#### [DELETE] [lib/models/letter.dart](file:///home/asus/Documents/endingletter/lib/models/letter.dart)

---

### Nouvelle Architecture du Jeu

#### [NEW] [lib/services/dictionary_service.dart](file:///home/asus/Documents/endingletter/lib/services/dictionary_service.dart)
- Création d'un service qui vérifie si un mot soumis est un mot anglais valide via une requête HTTP (`https://api.dictionaryapi.dev/api/v2/entries/en/{word}`).

#### [MODIFY] [lib/screens/splash_screen.dart](file:///home/asus/Documents/endingletter/lib/screens/splash_screen.dart)
- Nouvel écran de démarrage présentant le logo du jeu "Ending Letter" avec des animations élégantes (Flutter Animate).

#### [NEW] [lib/screens/main_menu.dart](file:///home/asus/Documents/endingletter/lib/screens/main_menu.dart)
- Écran d'accueil avec un bouton "Jouer" et "Règles du jeu".

#### [NEW] [lib/screens/game_screen.dart](file:///home/asus/Documents/endingletter/lib/screens/game_screen.dart)
- **Logique** : 
  - Suivi des mots déjà utilisés pour empêcher les répétitions.
  - Détermination de la lettre de départ pour le tour en cours.
  - Tour par tour entre Joueur 1 et Joueur 2.
- **Interface** :
  - Affichage de la lettre de départ requise en grand.
  - Champ de texte (TextField) pour entrer le nouveau mot.
  - Bouton "Soumettre".
  - Liste défilante des mots déjà joués (historique).

#### [MODIFY] [lib/main.dart](file:///home/asus/Documents/endingletter/lib/main.dart)
- Mise à jour du thème principal (couleurs vibrantes, typographie moderne) et définition de `MainMenu` comme page d'accueil après le `SplashScreen`.

## Verification Plan

### Automated Tests
- Je n'ajouterai pas de tests unitaires poussés à ce stade MVP, mais je m'assurerai que l'application compile correctement avec `flutter analyze`.

### Manual Verification
- Lancement de l'application via les outils de build locaux (ou demande à l'utilisateur de tester sur émulateur).
- Saisie d'un mot valide -> le jeu passe au joueur suivant.
- Saisie d'un mot invalide ou déjà joué -> message d'erreur clair avec animation de secousse (shake).
- Vérification que le dictionnaire API fonctionne.
