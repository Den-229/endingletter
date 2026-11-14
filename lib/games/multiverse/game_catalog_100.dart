import 'package:flutter/material.dart';

// Flagships
import '../cards/uno/uno_screen.dart';
import '../cards/blackjack/blackjack_screen.dart';
import '../board/chess/chess_screen.dart';
import '../board/checkers/checkers_screen.dart';
import '../board/ludo/ludo_screen.dart';
import '../board/connect4/connect4_screen.dart';
import '../board/tictactoe/tictactoe_screen.dart';
import '../logic/game_2048/game_2048_screen.dart';
import '../logic/minesweeper/minesweeper_screen.dart';
import '../logic/memory/memory_screen.dart';
import '../logic/simon/simon_screen.dart';
import '../math/math_sprint/math_sprint_screen.dart';
import '../arcade/flappy/flappy_screen.dart';
import '../arcade/brick_breaker/brick_breaker_screen.dart';
import '../arcade/snake/snake_screen.dart';
import '../cyber_horizon/cyber_horizon_screen.dart';
import '../gravi_portal/gravi_portal_screen.dart';

// Minigames pack
import 'minigames_pack.dart';
import 'micro_game_runner.dart';
import '../arcade/whack_a_mole/whack_a_mole_screen.dart';
import '../arcade/piano_tiles/piano_tiles_screen.dart';
import '../logic/wordle/wordle_screen.dart';
import '../casino/fortune_wheel/fortune_wheel_screen.dart';
import '../cards/solitaire/solitaire_screen.dart';
import '../racing/nitro_dr_driver/nitro_dr_driver_screen.dart';
import '../words/ending_letter/ending_letter_screen.dart';
import '../sports/football/football_menu_screen.dart';

enum CatalogCategory { all, cards, board, logic, math, arcade, reflex, sports }

class CatalogGame {
  final int id;
  final String title;
  final String subtitle;
  final CatalogCategory category;
  final IconData icon;
  final Color accentColor;
  final String badge;
  final Widget Function(BuildContext) builder;

  CatalogGame({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.accentColor,
    required this.badge,
    required this.builder,
  });
}

class GameCatalog100 {
  static List<CatalogGame> getAllGames() {
    List<CatalogGame> list = [];

    // --- 1 À 22 : LES GRANDS CLASSIQUES DÉDIÉS ---
    list.add(CatalogGame(
      id: 1,
      title: 'UNO Classic & IA',
      subtitle: 'Couleurs, chiffres, +2, +4, Jokers & cri UNO',
      category: CatalogCategory.cards,
      icon: Icons.style,
      accentColor: const Color(0xFFFF0055),
      badge: 'TOP CULTE',
      builder: (_) => const UnoScreen(),
    ));

    list.add(CatalogGame(
      id: 2,
      title: 'Blackjack 21 Royale',
      subtitle: 'Table de casino, croupier IA & double mise',
      category: CatalogCategory.cards,
      icon: Icons.monetization_on,
      accentColor: const Color(0xFF00FFCC),
      badge: 'CASINO',
      builder: (_) => const BlackjackScreen(),
    ));

    list.add(CatalogGame(
      id: 3,
      title: 'Échecs & IA',
      subtitle: 'Stratégie royale • 2 Joueurs ou vs Bot',
      category: CatalogCategory.board,
      icon: Icons.shield,
      accentColor: const Color(0xFF00F0FF),
      badge: 'STRATÉGIE',
      builder: (_) => const ChessScreen(),
    ));

    list.add(CatalogGame(
      id: 4,
      title: 'Jeu de Dames',
      subtitle: 'Sauts diagonaux, prises & couronnement',
      category: CatalogCategory.board,
      icon: Icons.change_circle,
      accentColor: const Color(0xFFFF007F),
      badge: 'CLASSIQUE',
      builder: (_) => const CheckersScreen(),
    ));

    list.add(CatalogGame(
      id: 5,
      title: 'Ludo Petits Chevaux',
      subtitle: 'Lancer de dés, circuit & renvoi à l\'écurie',
      category: CatalogCategory.board,
      icon: Icons.casino,
      accentColor: const Color(0xFF05FFA1),
      badge: 'FAMILLE',
      builder: (_) => const LudoScreen(),
    ));

    list.add(CatalogGame(
      id: 6,
      title: 'Puissance 4 Néon',
      subtitle: 'Alignez 4 jetons • Gravité & IA tactique',
      category: CatalogCategory.board,
      icon: Icons.grid_on,
      accentColor: const Color(0xFFFFD166),
      badge: 'DUEL',
      builder: (_) => const Connect4Screen(),
    ));

    list.add(CatalogGame(
      id: 7,
      title: 'Morpion Néon',
      subtitle: 'Tic-Tac-Toe 3x3 • 2 Joueurs ou vs IA',
      category: CatalogCategory.board,
      icon: Icons.close,
      accentColor: const Color(0xFF00FFCC),
      badge: 'RAPIDE',
      builder: (_) => const TicTacToeScreen(),
    ));

    list.add(CatalogGame(
      id: 8,
      title: '2048 Quantum',
      subtitle: 'Fusionnez les tuiles puissances de 2',
      category: CatalogCategory.logic,
      icon: Icons.grid_view,
      accentColor: const Color(0xFF00F0FF),
      badge: 'LOGIQUE',
      builder: (_) => const Game2048Screen(),
    ));

    list.add(CatalogGame(
      id: 9,
      title: 'Démineur Rétro',
      subtitle: 'Chiffres, drapeaux & détection de bombes',
      category: CatalogCategory.logic,
      icon: Icons.flag,
      accentColor: const Color(0xFFFFD166),
      badge: 'RÉTRO',
      builder: (_) => const MinesweeperScreen(),
    ));

    list.add(CatalogGame(
      id: 10,
      title: 'Mémoire Paires',
      subtitle: 'Retrouvez les cartes jumelles sous chrono',
      category: CatalogCategory.logic,
      icon: Icons.psychology,
      accentColor: const Color(0xFFE056FD),
      badge: 'MÉMOIRE',
      builder: (_) => const MemoryScreen(),
    ));

    list.add(CatalogGame(
      id: 11,
      title: 'Simon Néon',
      subtitle: 'Répétez la séquence musicale et visuelle',
      category: CatalogCategory.reflex,
      icon: Icons.touch_app,
      accentColor: const Color(0xFF05FFA1),
      badge: 'RÉFLEXE',
      builder: (_) => const SimonScreen(),
    ));

    list.add(CatalogGame(
      id: 12,
      title: 'Math Sprint ⚡',
      subtitle: 'Calcul mental ultra-rapide & combos',
      category: CatalogCategory.math,
      icon: Icons.calculate,
      accentColor: const Color(0xFFFF4040),
      badge: 'MATHS',
      builder: (_) => const MathSprintScreen(),
    ));

    list.add(CatalogGame(
      id: 13,
      title: 'Cyber Flap Néon',
      subtitle: 'Slalomez entre les tuyaux avec l\'oiseau',
      category: CatalogCategory.arcade,
      icon: Icons.airplay,
      accentColor: const Color(0xFFFFD166),
      badge: 'HIT MONDIAL',
      builder: (_) => const FlappyScreen(),
    ));

    list.add(CatalogGame(
      id: 14,
      title: 'Casse-Briques Rétro',
      subtitle: 'Détruisez les briques néon avec la balle',
      category: CatalogCategory.arcade,
      icon: Icons.sports_tennis,
      accentColor: const Color(0xFFFF2A6D),
      badge: 'ARCADE',
      builder: (_) => const BrickBreakerScreen(),
    ));

    list.add(CatalogGame(
      id: 15,
      title: 'Snake Cyber Néon',
      subtitle: 'Mangez les pommes et grandissez',
      category: CatalogCategory.arcade,
      icon: Icons.timeline,
      accentColor: const Color(0xFF05FFA1),
      badge: 'CULTE',
      builder: (_) => const SnakeScreen(),
    ));

    list.add(CatalogGame(
      id: 16,
      title: 'Cyber-Horizon 3D',
      subtitle: 'Rail-Shooter spatial • Bullet-Time 3D',
      category: CatalogCategory.arcade,
      icon: Icons.flight_takeoff,
      accentColor: const Color(0xFF00F0FF),
      badge: 'MOTEUR 3D',
      builder: (_) => const CyberHorizonScreen(),
    ));

    list.add(CatalogGame(
      id: 17,
      title: 'Gravi-Portal 4D',
      subtitle: 'Physique quantique & gravité 4D dynamique',
      category: CatalogCategory.arcade,
      icon: Icons.sync_alt,
      accentColor: const Color(0xFFFF007F),
      badge: 'PHYSIQUE',
      builder: (_) => const GraviPortalScreen(),
    ));

    list.add(CatalogGame(
      id: 18,
      title: 'Pong Rétro',
      subtitle: 'Le duel de tennis de table originel 1P & 2P',
      category: CatalogCategory.arcade,
      icon: Icons.sports_tennis,
      accentColor: const Color(0xFF00FFCC),
      badge: 'RÉTRO',
      builder: (_) => const PongScreen(),
    ));

    list.add(CatalogGame(
      id: 19,
      title: 'Lights Out',
      subtitle: 'Casse-tête des ampoules à éteindre',
      category: CatalogCategory.logic,
      icon: Icons.lightbulb,
      accentColor: const Color(0xFFFFD166),
      badge: 'CASSE-TÊTE',
      builder: (_) => const LightsOutScreen(),
    ));

    list.add(CatalogGame(
      id: 20,
      title: 'Taquin 15-Puzzle',
      subtitle: 'Remettez les 15 chiffres dans l\'ordre',
      category: CatalogCategory.logic,
      icon: Icons.format_list_numbered,
      accentColor: const Color(0xFF00F0FF),
      badge: 'PUZZLE',
      builder: (_) => const SlidingPuzzleScreen(),
    ));

    list.add(CatalogGame(
      id: 21,
      title: 'Test Réflexes Millisecondes',
      subtitle: 'Mesurez votre temps de réaction humaine en ms',
      category: CatalogCategory.reflex,
      icon: Icons.flash_on,
      accentColor: const Color(0xFF05FFA1),
      badge: 'CHRONO MS',
      builder: (_) => const ReactionTimerScreen(),
    ));

    list.add(CatalogGame(
      id: 22,
      title: 'Hi-Lo Cartes',
      subtitle: 'Devinez si la prochaine carte est plus haute',
      category: CatalogCategory.cards,
      icon: Icons.unfold_more,
      accentColor: const Color(0xFFFFD166),
      badge: 'CHANCE',
      builder: (_) => const HiLoScreen(),
    ));

    list.add(CatalogGame(
      id: 23,
      title: 'Tape-Taupe Cyber',
      subtitle: 'Touchez les robots néon dès qu\'ils sortent',
      category: CatalogCategory.reflex,
      icon: Icons.adb,
      accentColor: const Color(0xFFFF2A6D),
      badge: 'SPEED',
      builder: (_) => const WhackAMoleScreen(),
    ));

    list.add(CatalogGame(
      id: 24,
      title: 'Piano Tiles Néon',
      subtitle: 'Touchez les tuiles musicales en rythme',
      category: CatalogCategory.reflex,
      icon: Icons.music_note,
      accentColor: const Color(0xFF00FFCC),
      badge: 'RYTHME',
      builder: (_) => const PianoTilesScreen(),
    ));

    list.add(CatalogGame(
      id: 25,
      title: 'Wordle Cyber',
      subtitle: 'Devinez le mot secret en 6 essais',
      category: CatalogCategory.logic,
      icon: Icons.text_fields,
      accentColor: const Color(0xFF05FFA1),
      badge: 'MOTUS',
      builder: (_) => const WordleScreen(),
    ));

    list.add(CatalogGame(
      id: 26,
      title: 'Roue de la Fortune',
      subtitle: 'Tournez la roue et gagnez des bonus XP',
      category: CatalogCategory.cards,
      icon: Icons.rotate_right,
      accentColor: const Color(0xFFFFD166),
      badge: 'LUCKY',
      builder: (_) => const FortuneWheelScreen(),
    ));

    list.add(CatalogGame(
      id: 27,
      title: 'Solitaire Klondike',
      subtitle: 'Patience classique • 7 colonnes, 4 fondations & défausse',
      category: CatalogCategory.cards,
      icon: Icons.view_carousel,
      accentColor: const Color(0xFF00FFCC),
      badge: 'CULTE',
      builder: (_) => const SolitaireScreen(),
    ));

    list.add(CatalogGame(
      id: 28,
      title: 'Nitro Velocity & Dr. Parking',
      subtitle: 'Conduite de précision volant & shifter PRND + Course Asphalt Nitro',
      category: CatalogCategory.sports,
      icon: Icons.directions_car,
      accentColor: const Color(0xFFFF0055),
      badge: 'COURSE 3D',
      builder: (_) => const NitroDrDriverScreen(),
    ));

    list.add(CatalogGame(
      id: 29,
      title: 'Ending Letter Word Chain',
      subtitle: 'Jeu de vocabulaire anglais • Enchaînez la dernière lettre avec chrono',
      category: CatalogCategory.logic,
      icon: Icons.spellcheck,
      accentColor: const Color(0xFF00F0FF),
      badge: 'MOTS ANGLAIS',
      builder: (_) => const EndingLetterScreen(),
    ));

    list.add(CatalogGame(
      id: 30,
      title: 'PES Pro Striker 2026',
      subtitle: 'Simulateur football réaliste • Joystick analogique, passes, tirs & tactique',
      category: CatalogCategory.sports,
      icon: Icons.sports_soccer,
      accentColor: const Color(0xFF00FFCC),
      badge: 'FOOTBALL PES',
      builder: (_) => const FootballMenuScreen(),
    ));

    // --- DE 31 À 125+ : LES MICRO-DÉFIS ET VARIANTES MULTIVERSE ---
    final microGamesDefs = [
      // REFLEXES & SPEED
      {'title': 'Tap Speedometer 10s', 'type': MicroGameType.tapSpeed, 'cat': CatalogCategory.reflex, 'icon': Icons.speed, 'desc': 'Tapez le plus vite possible pendant 10 secondes !', 'badge': 'SPEED'},
      {'title': 'Neuro-Stroop Agilité', 'type': MicroGameType.stroopColor, 'cat': CatalogCategory.reflex, 'icon': Icons.palette, 'desc': 'Touchez la couleur de l\'encre, pas le mot écrit !', 'badge': 'NEURO'},
      {'title': 'Sniper Cibles Précision', 'type': MicroGameType.aimPrecision, 'cat': CatalogCategory.reflex, 'icon': Icons.gps_fixed, 'desc': 'Touchez les cibles radar dès qu\'elles apparaissent', 'badge': 'AIM'},
      {'title': 'Suites Numériques', 'type': MicroGameType.numberSequence, 'cat': CatalogCategory.math, 'icon': Icons.trending_up, 'desc': 'Identifiez le nombre manquant dans la suite logique', 'badge': 'LOGIQUE'},
      {'title': 'Jeu des 15 Allumettes (Nim)', 'type': MicroGameType.nimMatches, 'cat': CatalogCategory.board, 'icon': Icons.fireplace, 'desc': 'Prenez 1, 2 ou 3 allumettes sans prendre la dernière !', 'badge': 'DUEL IA'},
    ];

    int currentId = 31;
    final colors = [
      const Color(0xFF00FFCC),
      const Color(0xFFFF007F),
      const Color(0xFF00F0FF),
      const Color(0xFFFFD166),
      const Color(0xFF05FFA1),
      const Color(0xFFE056FD),
      const Color(0xFFFF4040),
    ];

    // Génération structurée des jeux jusqu'à 125+
    while (currentId <= 125) {
      for (final def in microGamesDefs) {
        if (currentId > 125) break;
        final type = def['type'] as MicroGameType;
        final baseTitle = def['title'] as String;
        final desc = def['desc'] as String;
        final cat = def['cat'] as CatalogCategory;
        final icon = def['icon'] as IconData;
        final badge = def['badge'] as String;
        final col = colors[currentId % colors.length];

        final gameNumber = currentId;
        final variantSuffix = gameNumber > 27 ? ' Nv.${(gameNumber - 20) ~/ 5 + 1}' : '';

        list.add(CatalogGame(
          id: gameNumber,
          title: '$baseTitle$variantSuffix',
          subtitle: desc,
          category: cat,
          icon: icon,
          accentColor: col,
          badge: badge,
          builder: (_) => MicroGameRunnerScreen(
            gameNumber: gameNumber,
            title: '$baseTitle$variantSuffix',
            instruction: desc,
            type: type,
            accentColor: col,
          ),
        ));

        currentId++;
      }
    }

    return list;
  }
}

