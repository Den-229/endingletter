# OMNI-GAMES MEGA : La Méga-Suite des 125+ Jeux Mobiles (Flutter)

Une plateforme arcade mobile colossale de **125+ jeux complets et jouables en 1 clic**, développée avec **Flutter**, équipée d'un système de scoring persistant, d'un sélecteur de jeu aléatoire au dé 🎲, d'un moteur de micro-défis et d'un Temple de la Renommée (*Gamer Level & XP*).

---

## 🎮 Architecture du Catalogue des 125+ Jeux (Numérotés de #1 à #125)

### 🎴 1. Cartes & Casino
- **#1 UNO Classic & IA** : Règles officielles, cartes action (+2, Reverse, Skip), Super Jokers (+4, Wild) et annonce **"CRIER UNO !"**.
- **#2 Blackjack 21 Royale** : Table de casino avec croupier IA, calcul d'As (1 ou 11) et double mise.
- **#22 Hi-Lo Cartes** : Pariez si la prochaine carte est plus haute ou plus basse pour bâtir une série record.
- **#26 Roue de la Fortune Néon** : Tournez la roue physique avec flèche de décélération pour gagner des bonus d'XP.

### ♟️ 2. Plateau & Stratégie
- **#3 Échecs & IA** : Mouvements officiels complets, surbrillance, promotion en Dame, 2J ou vs IA Bot.
- **#4 Jeu de Dames** : Diagonales, sauts, prises multiples et Dames couronnées.
- **#5 Ludo Petits Chevaux** : Dé 3D virtuel (1 à 6), sortie sur un 6 et renvoi à l'écurie.
- **#6 Puissance 4 Néon** : Grille 7x6 avec gravité et alignement tactique de 4 jetons.
- **#7 Morpion Néon (Tic-Tac-Toe)** : Grille 3x3 rétro-éclairée avec IA Minimax.
- **#27 Jeu des 15 Allumettes (Nim)** : Le duel mathématique mythique contre l'ordinateur.

### 🧠 3. Casse-Tête & Logique
- **#8 2048 Quantum** : Glissement 4 directions et fusion des puissances de 2.
- **#9 Démineur Rétro** : Grille 9x9, 10 mines, mode Drapeau et révélation récursive en cascade.
- **#10 Mémoire Paires** : Retrouvez les cartes jumelles sous chronomètre.
- **#19 Lights Out** : Éteindre toutes les ampoules connectées.
- **#20 Taquin 15-Puzzle** : Remettre les 15 chiffres dans l'ordre.
- **#25 Wordle Cyber** : Devinez le mot secret de 5 lettres en 6 essais avec clavier virtuel dynamique.

### ⚡ 4. Mathématiques & Cerveau
- **#12 Math Sprint ⚡** : Calcul mental ultra-rapide sous chronomètre de 40s (+, -, ×, ÷) avec combos.
- **#26 Suites Numériques** : Déduisez le chiffre manquant dans des suites arithmétiques et géométriques.

### 🚀 5. Arcade & Rétro
- **#13 Cyber Flap Néon** : Slalom aérien entre tuyaux avec physique d'inertie.
- **#14 Casse-Briques Rétro** : Raquette tactile, rebond angulaire et 5 rangées de briques multicolores.
- **#15 Snake Cyber Néon** : Le serpent mythique sur grille 20x20 avec pommes quantiques et accélération.
- **#16 Cyber-Horizon 3D** : Rail-shooter spatial en 3D vectorielle à 120 FPS avec ralenti Bullet-Time.
- **#17 Gravi-Portal 4D** : Labyrinthe à gravité dynamique 4D et téléporteurs quantiques.
- **#18 Pong Rétro** : Le duel originel 1P vs IA et 2 Joueurs.

### ⏱️ 6. Réflexes & Micro-Défis
- **#11 Simon Néon** : Répétition de séquences musicales et lumineuses.
- **#21 Test Réflexes Millisecondes** : Mesure ultra-précise de votre temps de réaction humaine en ms.
- **#23 Tape-Taupe Cyber** : Touchez les robots néon dès qu'ils sortent de leurs terriers avant qu'ils ne disparaissent !
- **#24 Piano Tiles Néon** : Touchez les tuiles musicales en rythme sans manquer de note.
- **#27+ à #125** : Micro-défis de vitesse, d'agilité Stroop, de visée sniper et de logique arithmétique !

---

## 🏆 Temple de la Renommée & Profil Joueur
Accessible via le bouton **Trophée 🏆** en haut à droite :
- **Niveau Joueur & XP Globale** : Tous les points marqués dans les 125+ jeux sont convertis en points d'expérience (XP).
- **Historique des Records** : Vos records dans chaque jeu sont sauvegardés automatiquement sur l'appareil.

---

## 📲 Comment Lancer et Installer

```bash
cd /home/asus/.gemini/antigravity/scratch/neo_chroma_games

# 1. Tester directement sur Linux :
flutter run -d linux

# 2. Tester sur Google Chrome :
flutter run -d chrome

# 3. Compiler l'APK Android prêt à installer :
flutter build apk --release
```
L'APK se trouvera dans `build/app/outputs/flutter-apk/app-release.apk`.
