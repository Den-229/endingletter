import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../games/sports/football/football_menu_screen.dart';
import '../games/board/connect4/connect4_screen.dart';
import '../games/board/tictactoe/tictactoe_screen.dart';
import '../games/board/checkers/checkers_screen.dart';
import '../games/multiverse/minigames_pack.dart';

class MultiplayerHubScreen extends StatefulWidget {
  const MultiplayerHubScreen({super.key});

  @override
  State<MultiplayerHubScreen> createState() => _MultiplayerHubScreenState();
}

class _MultiplayerHubScreenState extends State<MultiplayerHubScreen> {
  bool _isSearchingMatch = false;
  String _roomCode = '742 819';
  final TextEditingController _joinCodeController = TextEditingController();

  void _startRandomMatchmaking() {
    FeedbackService.triggerImpact();
    setState(() => _isSearchingMatch = true);

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _isSearchingMatch = false);
      _showMatchFoundDialog();
    });
  }

  void _generateNewRoom() {
    FeedbackService.triggerSelection();
    final rnd = math.Random();
    setState(() {
      _roomCode = '${rnd.nextInt(900) + 100} ${rnd.nextInt(900) + 100}';
    });
  }

  void _showMatchFoundDialog() {
    FeedbackService.triggerSuccess();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1524),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF00FFCC), width: 1.5),
        ),
        title: const Center(
          child: Text(
            'ADVERSAIRE TROUVÉ !',
            style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: Color(0xFF1E2842),
              child: Text('🥷', style: TextStyle(fontSize: 38)),
            ),
            const SizedBox(height: 10),
            const Text('CyberNinja_99', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const Text('Rang : Diamant III • 1 840 Elo', style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi, color: Color(0xFF00FFCC), size: 16),
                  SizedBox(width: 8),
                  Text('Ping : 24 ms • Prêt', style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('REFUSER', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FFCC),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FootballMenuScreen()),
              );
            },
            child: const Text('COMBATTRE', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'HUB MULTIJOUEUR ⚔️',
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Bannière Matchmaking Aléatoire
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B0E33), Color(0xFF330E26), Color(0xFF090D22)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFFFF007F).withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF007F).withValues(alpha: 0.2), blurRadius: 16),
                ],
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.public, color: Color(0xFFFF007F), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'MATCHMAKING MONDIAL EN LIGNE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Affrontez des joueurs de votre niveau dans le Multiverse',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _isSearchingMatch
                      ? const Column(
                          children: [
                            CircularProgressIndicator(color: Color(0xFFFF007F)),
                            SizedBox(height: 10),
                            Text('Recherche d\'un adversaire en cours...', style: TextStyle(color: Color(0xFFFF007F), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF007F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _startRandomMatchmaking,
                          icon: const Icon(Icons.flash_on),
                          label: const Text('LANCER RECHERCHE RAPIDE', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // 2. Salon Privé & Code de Salle
            const Text('SALONS PRIVÉS ENTRE AMIS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101626),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Votre code de salle :', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Color(0xFF00FFCC), size: 18),
                        onPressed: _generateNewRoom,
                        tooltip: 'Générer un nouveau code',
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.5)),
                    ),
                    child: Center(
                      child: Text(
                        _roomCode,
                        style: const TextStyle(
                          color: Color(0xFF00FFCC),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _joinCodeController,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'Entrez un code ami...',
                            hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            filled: true,
                            fillColor: const Color(0xFF172036),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FFCC),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          if (_joinCodeController.text.isNotEmpty) {
                            FeedbackService.triggerSuccess();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Connexion au salon ${_joinCodeController.text}...')),
                            );
                          }
                        },
                        child: const Text('REJOINDRE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // 3. Mode Duel Local (Pass & Play sur le même écran)
            const Text('DUELS LOCAUX (MÊME ÉCRAN 1 VS 1)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildLocalDuelCard(
                    title: 'Football PES',
                    icon: Icons.sports_soccer,
                    color: const Color(0xFF00FFCC),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FootballMenuScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildLocalDuelCard(
                    title: 'Puissance 4',
                    icon: Icons.grid_on,
                    color: const Color(0xFFFFD166),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Connect4Screen())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildLocalDuelCard(
                    title: 'Jeu de Dames',
                    icon: Icons.change_circle,
                    color: const Color(0xFFFF007F),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckersScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildLocalDuelCard(
                    title: 'Pong Rétro',
                    icon: Icons.sports_tennis,
                    color: const Color(0xFF00F0FF),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PongScreen())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildLocalDuelCard(
                    title: 'Morpion Néon',
                    icon: Icons.close,
                    color: const Color(0xFF05FFA1),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TicTacToeScreen())),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalDuelCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        FeedbackService.triggerImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF101626),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const Icon(Icons.play_arrow, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}
