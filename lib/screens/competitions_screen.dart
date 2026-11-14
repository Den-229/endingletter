import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../games/sports/football/football_menu_screen.dart';
import '../games/board/chess/chess_screen.dart';
import '../games/racing/nitro_dr_driver/nitro_dr_driver_screen.dart';

class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen> {
  int _selectedCupIndex = 0;

  final List<Map<String, dynamic>> _cups = [
    {
      'title': 'PES Champions Cup 2026',
      'icon': '⚽',
      'category': 'Football',
      'color': Color(0xFF00FFCC),
      'participants': '8 Équipes Pro',
      'reward': '🏆 Trophée Or + 500 XP',
      'matches': [
        {'teamA': 'Madrid Royals', 'teamB': 'London Lions', 'score': '2 - 1', 'winner': 'Madrid Royals', 'round': 'Quart 1'},
        {'teamA': 'Paris Lumière', 'teamB': 'Milan Stars', 'score': '3 - 0', 'winner': 'Paris Lumière', 'round': 'Quart 2'},
        {'teamA': 'Rio Samba FC', 'teamB': 'Tokyo Neo FC', 'score': '1 - 0', 'winner': 'Rio Samba FC', 'round': 'Quart 3'},
        {'teamA': 'Berlin Blitz', 'teamB': 'Ajax Stars', 'score': '2 - 3', 'winner': 'Ajax Stars', 'round': 'Quart 4'},
      ],
      'semiMatches': [
        {'teamA': 'Madrid Royals', 'teamB': 'Paris Lumière', 'score': 'En attente', 'winner': null, 'round': 'Demi-finale 1'},
        {'teamA': 'Rio Samba FC', 'teamB': 'Ajax Stars', 'score': 'En attente', 'winner': null, 'round': 'Demi-finale 2'},
      ],
      'finalMatch': {
        'teamA': 'Vainqueur Demi 1',
        'teamB': 'Vainqueur Demi 2',
        'score': 'Finale',
        'winner': null,
      },
    },
    {
      'title': 'Grand Slam Chess Masters',
      'icon': '♟️',
      'category': 'Échecs',
      'color': Color(0xFF00F0FF),
      'participants': '8 Maîtres IA',
      'reward': '👑 Titre Grand-Maître + 450 XP',
      'matches': [
        {'teamA': 'Kasparov IA', 'teamB': 'Stockfish Lite', 'score': '1 - 0', 'winner': 'Kasparov IA', 'round': 'Quart 1'},
        {'teamA': 'AlphaBot', 'teamB': 'DeepBlue Neo', 'score': '1 - 0', 'winner': 'AlphaBot', 'round': 'Quart 2'},
        {'teamA': 'Carlsen Bot', 'teamB': 'Ruy Lopez IA', 'score': '1 - 0', 'winner': 'Carlsen Bot', 'round': 'Quart 3'},
        {'teamA': 'Hikaru Speed', 'teamB': 'Gambit Master', 'score': '1 - 0', 'winner': 'Hikaru Speed', 'round': 'Quart 4'},
      ],
      'semiMatches': [
        {'teamA': 'Kasparov IA', 'teamB': 'AlphaBot', 'score': 'En attente', 'winner': null, 'round': 'Demi-finale 1'},
        {'teamA': 'Carlsen Bot', 'teamB': 'Hikaru Speed', 'score': 'En attente', 'winner': null, 'round': 'Demi-finale 2'},
      ],
      'finalMatch': {
        'teamA': 'Vainqueur Demi 1',
        'teamB': 'Vainqueur Demi 2',
        'score': 'Grande Finale',
        'winner': null,
      },
    },
    {
      'title': 'Asphalt Velocity Grand Prix',
      'icon': '🏎️',
      'category': 'Course',
      'color': Color(0xFFFF0055),
      'participants': '8 Pilotes Nitro',
      'reward': '🚀 Apex Hypercar + 600 XP',
      'matches': [
        {'teamA': 'Apex GT', 'teamB': 'Venom Sport', 'score': '1er', 'winner': 'Apex GT', 'round': 'Élimination 1'},
        {'teamA': 'Phantom R', 'teamB': 'Thunder RS', 'score': '1er', 'winner': 'Thunder RS', 'round': 'Élimination 2'},
        {'teamA': 'Dr. Cruiser', 'teamB': 'Viper Turbo', 'score': '1er', 'winner': 'Viper Turbo', 'round': 'Élimination 3'},
        {'teamA': 'Cyber Racer', 'teamB': 'Nitro King', 'score': '1er', 'winner': 'Nitro King', 'round': 'Élimination 4'},
      ],
      'semiMatches': [
        {'teamA': 'Apex GT', 'teamB': 'Thunder RS', 'score': 'En attente', 'winner': null, 'round': 'Demi-finale 1'},
        {'teamA': 'Viper Turbo', 'teamB': 'Nitro King', 'score': 'En attente', 'winner': null, 'round': 'Demi-finale 2'},
      ],
      'finalMatch': {
        'teamA': 'Finaliste 1',
        'teamB': 'Finaliste 2',
        'score': 'Finale Duel',
        'winner': null,
      },
    },
  ];

  @override
  Widget build(BuildContext context) {
    final currentCup = _cups[_selectedCupIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'COMPÉTITIONS & TOURNOIS 🏆',
          style: TextStyle(
            color: Color(0xFF00FFCC),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sélecteur de Tournoi (Chips horizontaux)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_cups.length, (idx) {
                  final cup = _cups[idx];
                  final isSel = idx == _selectedCupIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSel,
                      label: Text('${cup['icon']} ${cup['title']}', style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      backgroundColor: const Color(0xFF13192B),
                      selectedColor: cup['color'],
                      onSelected: (_) {
                        FeedbackService.triggerSelection();
                        setState(() => _selectedCupIndex = idx);
                      },
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            // Bannière de la compétition active
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    (currentCup['color'] as Color).withValues(alpha: 0.25),
                    const Color(0xFF101626),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: (currentCup['color'] as Color).withValues(alpha: 0.6), width: 1.5),
              ),
              child: Row(
                children: [
                  Text(currentCup['icon'], style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(currentCup['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(currentCup['reward'], style: TextStyle(color: currentCup['color'], fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('Format : Knockout direct • ${currentCup['participants']}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Arbre du Tournoi (Tournament Bracket)
            const Text('TABLEAU DU TOURNOI (KNOCKOUT)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 10),

            // Quarts de finale
            _buildBracketSectionTitle('QUARTS DE FINALE (TERMINÉS)'),
            const SizedBox(height: 6),
            ...((currentCup['matches'] as List).map((m) => _buildMatchCard(m, currentCup['color']))),

            const SizedBox(height: 14),

            // Demi-finales
            _buildBracketSectionTitle('DEMI-FINALES (EN COURS)'),
            const SizedBox(height: 6),
            ...((currentCup['semiMatches'] as List).map((m) => _buildMatchCard(m, currentCup['color']))),

            const SizedBox(height: 14),

            // Grande finale
            _buildBracketSectionTitle('GRANDE FINALE 🏆'),
            const SizedBox(height: 6),
            _buildMatchCard(currentCup['finalMatch'], currentCup['color']),

            const SizedBox(height: 24),

            // Bouton Rejoindre le Match du Tournoi
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: currentCup['color'],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                FeedbackService.triggerImpact();
                if (_selectedCupIndex == 0) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FootballMenuScreen()));
                } else if (_selectedCupIndex == 1) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChessScreen()));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NitroDrDriverScreen()));
                }
              },
              child: const Text('DISPUTER MON MATCH DE TOURNOI', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBracketSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1));
  }

  Widget _buildMatchCard(Map<String, dynamic> match, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101626),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              match['teamA'],
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: match['winner'] == match['teamA'] ? accentColor : Colors.white70,
                fontWeight: match['winner'] == match['teamA'] ? FontWeight.w900 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(6)),
            child: Text(
              match['score'],
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              match['teamB'],
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: match['winner'] == match['teamB'] ? accentColor : Colors.white70,
                fontWeight: match['winner'] == match['teamB'] ? FontWeight.w900 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
