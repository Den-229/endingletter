import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _avatar;
  late String _title;

  static const List<String> _avatars = ['👾', '🥷', '👑', '🦊', '🐉', '⚡', '🧙‍♂️', '🚀'];
  static const List<String> _titles = [
    'Gamer d\'Élite',
    'Grand Stratège',
    'Maître des Cartes',
    'As de l\'Arcade',
    'Légende Vivante',
    'Prodige du Multiverse',
  ];

  @override
  void initState() {
    super.initState();
    _avatar = StorageService.getPlayerAvatar();
    _title = StorageService.getPlayerTitle();
  }

  void _chooseAvatar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10172D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CHOISIR VOTRE AVATAR GAMER',
              style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _avatars.map((a) {
                final isSelected = a == _avatar;
                return GestureDetector(
                  onTap: () {
                    StorageService.setPlayerAvatar(a);
                    FeedbackService.triggerSelection();
                    setState(() => _avatar = a);
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00FFCC).withValues(alpha: 0.25) : const Color(0xFF16203D),
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? const Color(0xFF00FFCC) : Colors.white12, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(a, style: const TextStyle(fontSize: 28)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _chooseTitle() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10172D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Material(
        color: const Color(0xFF10172D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CHOISIR VOTRE TITRE HONORIFIQUE',
                style: TextStyle(color: Color(0xFFFFD166), fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
              ),
              const SizedBox(height: 14),
              ..._titles.map((t) {
                final isSelected = t == _title;
                return ListTile(
                  title: Text(t, style: TextStyle(color: isSelected ? const Color(0xFFFFD166) : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  trailing: isSelected ? const Icon(Icons.check, color: Color(0xFFFFD166)) : null,
                  onTap: () {
                    StorageService.setPlayerTitle(t);
                    FeedbackService.triggerSelection();
                    setState(() => _title = t);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalXp = StorageService.getTotalXP();
    final level = StorageService.getPlayerLevel();
    final gamesPlayed = StorageService.getTotalGamesPlayed();
    final streak = StorageService.getDailyStreak();
    final unlockedTrophies = StorageService.getUnlockedAchievements().length;

    final scores = [
      {'game': 'Cyber-Horizon 3D', 'score': StorageService.getCyberHighScore(), 'icon': Icons.flight_takeoff, 'color': const Color(0xFF00F0FF)},
      {'game': 'Solitaire Klondike', 'score': StorageService.getSolitaireHighScore(), 'icon': Icons.view_carousel, 'color': const Color(0xFF00FFCC)},
      {'game': 'Cyber Flap Néon', 'score': StorageService.getFlappyHighScore(), 'icon': Icons.airplay, 'color': const Color(0xFFFFD166)},
      {'game': 'Snake Cyber', 'score': StorageService.getSnakeHighScore(), 'icon': Icons.timeline, 'color': const Color(0xFF05FFA1)},
      {'game': 'Casse-Briques', 'score': StorageService.getBricksHighScore(), 'icon': Icons.sports_tennis, 'color': const Color(0xFFFF2A6D)},
      {'game': '2048 Quantum', 'score': StorageService.get2048HighScore(), 'icon': Icons.grid_view, 'color': const Color(0xFF00FFCC)},
      {'game': 'Math Sprint ⚡', 'score': StorageService.getMathHighScore(), 'icon': Icons.calculate, 'color': const Color(0xFFFF4040)},
      {'game': 'Simon Néon', 'score': StorageService.getSimonHighScore(), 'icon': Icons.touch_app, 'color': const Color(0xFFE056FD)},
      {'game': 'Gravi-Portal', 'score': StorageService.getGraviHighScore(), 'icon': Icons.sync_alt, 'color': const Color(0xFFFF007F)},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10172D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'PROFIL & STATISTIQUES GAMER',
          style: TextStyle(
            color: Color(0xFF00FFCC),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Carte Gamer Pro & Avatar personnalisable
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF23164D), Color(0xFF0C1938)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FFCC).withValues(alpha: 0.2),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar interactif
                GestureDetector(
                  onTap: _chooseAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [Color(0xFF00FFCC), Color(0xFF7000FF)]),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(_avatar, style: const TextStyle(fontSize: 38)),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Color(0xFF00FFCC), shape: BoxShape.circle),
                          child: const Icon(Icons.edit, size: 14, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _chooseTitle,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                _title.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit, size: 14, color: Colors.white38),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Niveau $level • $totalXp XP',
                        style: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (totalXp % 500) / 500.0,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF00FFCC)),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Grille de Statistiques
          Row(
            children: [
              Expanded(
                child: _buildStatCard('PARTIES', '$gamesPlayed', Icons.sports_esports, const Color(0xFF00FFCC)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('SÉRIE', '$streak j', Icons.local_fire_department, const Color(0xFFFF9F1C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('TROPHÉES', '$unlockedTrophies', Icons.emoji_events, const Color(0xFFFFD166)),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Titre Records
          const Text(
            'TABLEAU DE VOS MEILLEURS RECORDS',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
          ),

          const SizedBox(height: 12),

          // Liste des scores
          ...scores.map((s) {
            final score = s['score'] as int;
            final color = s['color'] as Color;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10172D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(s['icon'] as IconData, color: color, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s['game'] as String,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Text(
                    score > 0 ? '$score PTS' : '—',
                    style: TextStyle(
                      color: score > 0 ? color : Colors.white30,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10172D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
