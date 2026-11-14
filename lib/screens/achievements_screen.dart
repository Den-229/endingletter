import 'package:flutter/material.dart';
import '../services/storage_service.dart';

enum TrophyTier { bronze, silver, gold, platinum }

class Trophy {
  final String id;
  final String title;
  final String description;
  final TrophyTier tier;
  final IconData icon;

  Trophy({
    required this.id,
    required this.title,
    required this.description,
    required this.tier,
    required this.icon,
  });

  Color get color {
    switch (tier) {
      case TrophyTier.bronze: return const Color(0xFFCD7F32);
      case TrophyTier.silver: return const Color(0xFFC0C0C0);
      case TrophyTier.gold: return const Color(0xFFFFD700);
      case TrophyTier.platinum: return const Color(0xFF00FFCC);
    }
  }

  String get tierLabel {
    switch (tier) {
      case TrophyTier.bronze: return 'BRONZE';
      case TrophyTier.silver: return 'ARGENT';
      case TrophyTier.gold: return 'OR';
      case TrophyTier.platinum: return 'PLATINE';
    }
  }
}

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  List<Trophy> _getTrophies() {
    return [
      Trophy(
        id: 'debutant',
        title: 'Premiers Pas',
        description: 'Lancer l\'application OmniGames Mega',
        tier: TrophyTier.bronze,
        icon: Icons.flight_takeoff,
      ),
      Trophy(
        id: 'cards_init',
        title: 'As du Tapis',
        description: 'Jouer une partie complète de Solitaire ou Blackjack',
        tier: TrophyTier.bronze,
        icon: Icons.style,
      ),
      Trophy(
        id: 'checkmate',
        title: 'Grand Maître Échiquéen',
        description: 'Mettre l\'adversaire en échec et mat',
        tier: TrophyTier.silver,
        icon: Icons.shield,
      ),
      Trophy(
        id: 'connect_win',
        title: 'Alignement Parfait',
        description: 'Gagner une partie au Puissance 4 officiel',
        tier: TrophyTier.silver,
        icon: Icons.circle,
      ),
      Trophy(
        id: 'snake_100',
        title: 'Python Insatiable',
        description: 'Dépasser 100 points au Snake Cyber',
        tier: TrophyTier.silver,
        icon: Icons.timeline,
      ),
      Trophy(
        id: 'uno_shout',
        title: 'Cris de Victoire',
        description: 'Déclarer "UNO !" et vider sa main face à l\'IA',
        tier: TrophyTier.gold,
        icon: Icons.flash_on,
      ),
      Trophy(
        id: 'bricks_clear',
        title: 'Démolisseur Expert',
        description: 'Détruire toutes les rangées de briques néon',
        tier: TrophyTier.gold,
        icon: Icons.sports_tennis,
      ),
      Trophy(
        id: 'solitaire_king',
        title: 'Patience Royale',
        description: 'Compléter les 4 fondations du Solitaire Klondike',
        tier: TrophyTier.gold,
        icon: Icons.emoji_events,
      ),
      Trophy(
        id: 'centurion',
        title: 'Légende du Multiverse',
        description: 'Atteindre le Niveau 10 et totaliser 5000+ XP',
        tier: TrophyTier.platinum,
        icon: Icons.military_tech,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final trophies = _getTrophies();
    final unlockedIds = StorageService.getUnlockedAchievements();
    final unlockedCount = trophies.where((t) => unlockedIds.contains(t.id)).length;

    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10172D),
        elevation: 0,
        title: const Text(
          '🏆 SALLE DES TROPHÉES',
          style: TextStyle(
            color: Color(0xFFFFD166),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Bandeau Statut
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF231B4D), Color(0xFF0F122B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD166).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFFFFD166), Color(0xFFFF9F1C)]),
                  ),
                  child: const Icon(Icons.emoji_events, color: Colors.black, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$unlockedCount SUR ${trophies.length} TROPHÉES OBTENUS',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: unlockedCount / trophies.length,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD166)),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Liste des Trophées
          ...trophies.map((t) {
            final isUnlocked = unlockedIds.contains(t.id);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10172D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUnlocked ? t.color.withValues(alpha: 0.7) : Colors.white10,
                  width: isUnlocked ? 1.5 : 1.0,
                ),
                boxShadow: isUnlocked
                    ? [BoxShadow(color: t.color.withValues(alpha: 0.2), blurRadius: 10)]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isUnlocked ? t.color.withValues(alpha: 0.2) : Colors.white10,
                    ),
                    child: Icon(
                      isUnlocked ? t.icon : Icons.lock_outline,
                      color: isUnlocked ? t.color : Colors.white38,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              t.title,
                              style: TextStyle(
                                color: isUnlocked ? Colors.white : Colors.white60,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: t.color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t.tierLabel,
                                style: TextStyle(
                                  color: t.color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          t.description,
                          style: TextStyle(
                            color: isUnlocked ? Colors.white70 : Colors.white30,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isUnlocked)
                    const Icon(Icons.check_circle, color: Color(0xFF00FFCC), size: 20),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
