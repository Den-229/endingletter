import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class QuestItem {
  final String id;
  final String title;
  final String description;
  final int rewardXp;
  final int currentProgress;
  final int target;
  final IconData icon;
  final Color color;

  QuestItem({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardXp,
    required this.currentProgress,
    required this.target,
    required this.icon,
    required this.color,
  });

  bool get isCompleted => currentProgress >= target;
}

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  late List<QuestItem> _dailyQuests;

  @override
  void initState() {
    super.initState();
    _loadQuests();
  }

  void _loadQuests() {
    final gamesPlayed = StorageService.getTotalGamesPlayed();
    final streak = StorageService.getDailyStreak();
    final solitaireScore = StorageService.getSolitaireHighScore();

    _dailyQuests = [
      QuestItem(
        id: 'daily_login',
        title: 'Connexion Quotidienne',
        description: 'Lancez l\'application pour maintenir votre série active',
        rewardXp: 50,
        currentProgress: streak.clamp(0, 1),
        target: 1,
        icon: Icons.local_fire_department,
        color: const Color(0xFFFF9F1C),
      ),
      QuestItem(
        id: 'play_3_games',
        title: 'Explorateur du Multiverse',
        description: 'Jouez à au moins 3 parties parmi les 125+ jeux',
        rewardXp: 120,
        currentProgress: gamesPlayed.clamp(0, 3),
        target: 3,
        icon: Icons.videogame_asset,
        color: const Color(0xFF00FFCC),
      ),
      QuestItem(
        id: 'cards_master',
        title: 'Maître des Cartes',
        description: 'Réalisez un score au Solitaire, Blackjack ou UNO',
        rewardXp: 180,
        currentProgress: (solitaireScore > 0 ? 1 : 0),
        target: 1,
        icon: Icons.style,
        color: const Color(0xFFFF0055),
      ),
      QuestItem(
        id: 'arcade_champion',
        title: 'Champion d\'Arcade 3D',
        description: 'Dépassez 200 points sur Flappy, Snake ou Cyber-Horizon',
        rewardXp: 250,
        currentProgress: (StorageService.getSnakeHighScore() >= 200 || StorageService.getFlappyHighScore() >= 2 ? 1 : 0),
        target: 1,
        icon: Icons.rocket_launch,
        color: const Color(0xFF00F0FF),
      ),
    ];
  }

  void _claimReward(QuestItem quest) async {
    await StorageService.claimQuest(quest.id);
    FeedbackService.triggerSuccess();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF00FFCC),
          content: Text(
            '🎉 Quête validée ! +${quest.rewardXp} XP ajoutés à votre profil !',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10172D),
        elevation: 0,
        title: const Text(
          '🎯 QUÊTES & MISSIONS DU JOUR',
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
          // Bannière Progression
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B2347), Color(0xFF0D1429)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF00FFCC), Color(0xFF7000FF)]),
                  ),
                  child: const Icon(Icons.military_tech, color: Colors.black, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RÉCOMPENSES DE CHOC',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Complétez vos missions pour débloquer de nouveaux titres et gravir les niveaux du Hall of Fame !',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'DÉFIS DU JOUR (Réinitialisation à minuit)',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          ..._dailyQuests.map((quest) {
            final isClaimed = StorageService.isQuestClaimed(quest.id);
            final ratio = (quest.currentProgress / quest.target).clamp(0.0, 1.0);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10172D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: quest.isCompleted
                      ? quest.color.withValues(alpha: 0.7)
                      : Colors.white12,
                  width: quest.isCompleted ? 1.5 : 1.0,
                ),
                boxShadow: quest.isCompleted
                    ? [BoxShadow(color: quest.color.withValues(alpha: 0.15), blurRadius: 10)]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: quest.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(quest.icon, color: quest.color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quest.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              quest.description,
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          '+${quest.rewardXp} XP',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation(quest.color),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${quest.currentProgress}/${quest.target}',
                        style: TextStyle(
                          color: quest.isCompleted ? quest.color : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (quest.isCompleted) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isClaimed ? null : () => _claimReward(quest),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isClaimed ? Colors.white12 : quest.color,
                          disabledBackgroundColor: Colors.white12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          isClaimed ? 'DÉJÀ RÉCLAMÉ ✔' : 'RÉCLAMER LES +${quest.rewardXp} XP 🎁',
                          style: TextStyle(
                            color: isClaimed ? Colors.white38 : Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
