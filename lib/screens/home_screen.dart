import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../games/multiverse/game_catalog_100.dart';
import '../widgets/game_detail_sheet.dart';
import 'quests_screen.dart';
import 'achievements_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'innovation_lab_screen.dart';
import 'multiplayer_hub_screen.dart';
import 'competitions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  CatalogCategory _selectedCategory = CatalogCategory.all;
  bool _filterFavoritesOnly = false;
  bool _filterRecentsOnly = false;
  String _searchQuery = '';
  late final List<CatalogGame> _games = GameCatalog100.getAllGames();

  void _launchRandomGame() {
    FeedbackService.triggerImpact();
    final randomGame = _games[math.Random().nextInt(_games.length)];
    StorageService.addRecentGame(randomGame.id);
    Navigator.of(context).push(
      MaterialPageRoute(builder: randomGame.builder),
    );
  }

  void _playGame(CatalogGame game) {
    FeedbackService.triggerImpact();
    StorageService.addRecentGame(game.id);
    Navigator.of(context).push(
      MaterialPageRoute(builder: game.builder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildGamesCatalogTab(),
          const QuestsScreen(),
          const AchievementsScreen(),
          const ProfileScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A0F21),
          border: Border(top: BorderSide(color: Colors.white12, width: 1)),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -4)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            FeedbackService.triggerSelection();
            setState(() => _currentTabIndex = index);
          },
          backgroundColor: const Color(0xFF0A0F21),
          selectedItemColor: const Color(0xFF00FFCC),
          unselectedItemColor: Colors.white38,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_esports_outlined),
              activeIcon: Icon(Icons.sports_esports),
              label: 'Jeux',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.military_tech_outlined),
              activeIcon: Icon(Icons.military_tech),
              label: 'Quêtes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events),
              label: 'Trophées',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Système',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesCatalogTab() {
    final favIds = StorageService.getFavoriteIds();
    final recentIds = StorageService.getRecentIds();

    final filteredGames = _games.where((g) {
      if (_filterFavoritesOnly && !favIds.contains(g.id)) return false;
      if (_filterRecentsOnly && !recentIds.contains(g.id)) return false;

      final matchesCategory = _filterFavoritesOnly || _filterRecentsOnly ||
          _selectedCategory == CatalogCategory.all ||
          g.category == _selectedCategory;

      final q = _searchQuery.toLowerCase().trim();
      final matchesSearch = q.isEmpty ||
          g.title.toLowerCase().contains(q) ||
          g.subtitle.toLowerCase().contains(q) ||
          g.badge.toLowerCase().contains(q) ||
          '#${g.id}'.contains(q) ||
          '${g.id}'.contains(q);

      return matchesCategory && matchesSearch;
    }).toList();

    // Jeu vedette du jour (ex: UNO ou Solitaire)
    final heroGame = _games.firstWhere((g) => g.id == 27, orElse: () => _games.first);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barre supérieure responsive
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'OMNI-GAMES MEGA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.8,
                            shadows: [
                              Shadow(color: Color(0xFF00FFCC), blurRadius: 14),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        '${_games.length} Jeux au Multiverse',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Toggle Audio Rapide
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        StorageService.isAudioEnabled() ? Icons.volume_up : Icons.volume_off,
                        color: StorageService.isAudioEnabled() ? const Color(0xFF00FFCC) : Colors.white38,
                        size: 22,
                      ),
                      tooltip: 'Sonore On/Off',
                      onPressed: () {
                        final newVal = !StorageService.isAudioEnabled();
                        StorageService.setAudioEnabled(newVal);
                        FeedbackService.triggerSelection();
                        setState(() {});
                      },
                    ),
                    const SizedBox(width: 4),
                    // Bouton Jeu Aléatoire
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.casino, color: Color(0xFF00FFCC), size: 22),
                      tooltip: 'Jeu Aléatoire au hasard',
                      onPressed: _launchRandomGame,
                    ),
                    const SizedBox(width: 4),
                    // Guide Innovation
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.lightbulb_outline, color: Colors.white70, size: 22),
                      tooltip: 'Laboratoire d\'Innovation',
                      onPressed: () {
                        FeedbackService.triggerSelection();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InnovationLabScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bannière Récompense Quotidienne
          if (StorageService.canClaimDaily())
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: GestureDetector(
                onTap: () async {
                  final gainedXp = await StorageService.claimDailyReward();
                  FeedbackService.triggerSuccess();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF00FFCC),
                        content: Text(
                          '🔥 Série quotidienne validée ! +$gainedXp XP ajoutés à votre profil !',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                    setState(() {});
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2A6D), Color(0xFFFF9F1C)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2A6D).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.card_giftcard, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CADEAU DU JOUR • SÉRIE ${StorageService.getDailyStreak()} JOURS 🔥',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                            const Text(
                              'Touchez pour réclamer votre bonus XP',
                              style: TextStyle(color: Colors.white70, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'RÉCLAMER',
                          style: TextStyle(color: Color(0xFFFF2A6D), fontWeight: FontWeight.w900, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Carte Jeu Vedette du Jour
          if (_searchQuery.isEmpty && !_filterFavoritesOnly && !_filterRecentsOnly && _selectedCategory == CatalogCategory.all)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: GestureDetector(
                onTap: () => GameDetailSheet.show(context, heroGame, () => _playGame(heroGame)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E2F52), Color(0xFF0F1A33)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: heroGame.accentColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: heroGame.accentColor.withValues(alpha: 0.25),
                        ),
                        child: Icon(heroGame.icon, color: heroGame.accentColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'JEU VEDETTE DU JOUR',
                                  style: TextStyle(color: heroGame.accentColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.stars, color: Color(0xFFFFD166), size: 14),
                              ],
                            ),
                            Text(
                              heroGame.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _playGame(heroGame),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: heroGame.accentColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('JOUER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Barre de recherche intuitive
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF10172D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  icon: const Icon(Icons.search, color: Colors.white38, size: 20),
                  hintText: 'Rechercher par nom ou numéro (#1 à #${_games.length})...',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),

          // Hubs rapides : Multijoueur & Compétitions
          if (_searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuickHubButton(
                      title: 'Multijoueur',
                      subtitle: 'Lobby & Duels',
                      icon: Icons.sports_esports,
                      color: const Color(0xFFFF007F),
                      onTap: () {
                        FeedbackService.triggerSelection();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MultiplayerHubScreen()));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickHubButton(
                      title: 'Compétitions',
                      subtitle: 'Brackets & Cups',
                      icon: Icons.emoji_events,
                      color: const Color(0xFFFFD166),
                      onTap: () {
                        FeedbackService.triggerSelection();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CompetitionsScreen()));
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Filtres par Catégorie, Favoris et Récents
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('Tous (${_games.length})', !_filterFavoritesOnly && !_filterRecentsOnly && _selectedCategory == CatalogCategory.all, () {
                  setState(() {
                    _filterFavoritesOnly = false;
                    _filterRecentsOnly = false;
                    _selectedCategory = CatalogCategory.all;
                  });
                }),
                _buildFilterChip('⭐ Favoris (${favIds.length})', _filterFavoritesOnly, () {
                  setState(() {
                    _filterFavoritesOnly = true;
                    _filterRecentsOnly = false;
                  });
                }),
                _buildFilterChip('⏱️ Récents (${recentIds.length})', _filterRecentsOnly, () {
                  setState(() {
                    _filterFavoritesOnly = false;
                    _filterRecentsOnly = true;
                  });
                }),
                _buildCategoryChip('🎴 Cartes', CatalogCategory.cards),
                _buildCategoryChip('♟️ Plateau', CatalogCategory.board),
                _buildCategoryChip('🧠 Logique', CatalogCategory.logic),
                _buildCategoryChip('⚡ Maths', CatalogCategory.math),
                _buildCategoryChip('🚀 Arcade', CatalogCategory.arcade),
                _buildCategoryChip('⏱️ Réflexes', CatalogCategory.reflex),
                _buildCategoryChip('⚽ Sports & Course', CatalogCategory.sports),
              ],
            ),
          ),

          // Grille des jeux
          Expanded(
            child: filteredGames.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off, size: 48, color: Colors.white24),
                        const SizedBox(height: 10),
                        Text(
                          _filterFavoritesOnly ? 'Aucun jeu dans vos favoris pour l\'instant !' : 'Aucun jeu ne correspond à votre recherche',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.86,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredGames.length,
                    itemBuilder: (ctx, idx) {
                      final game = filteredGames[idx];
                      return _buildGameCard(game, favIds.contains(game.id));
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF00FFCC),
        backgroundColor: const Color(0xFF10172D),
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 11.5,
        ),
        side: BorderSide(
          color: isSelected ? const Color(0xFF00FFCC) : Colors.white12,
        ),
        onSelected: (_) {
          FeedbackService.triggerLight();
          onTap();
        },
      ),
    );
  }

  Widget _buildCategoryChip(String label, CatalogCategory cat) {
    final isSelected = !_filterFavoritesOnly && !_filterRecentsOnly && _selectedCategory == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF00FFCC),
        backgroundColor: const Color(0xFF10172D),
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 11.5,
        ),
        side: BorderSide(
          color: isSelected ? const Color(0xFF00FFCC) : Colors.white12,
        ),
        onSelected: (_) {
          FeedbackService.triggerLight();
          setState(() {
            _filterFavoritesOnly = false;
            _filterRecentsOnly = false;
            _selectedCategory = cat;
          });
        },
      ),
    );
  }

  Widget _buildGameCard(CatalogGame game, bool isFav) {
    return GestureDetector(
      onTap: () {
        FeedbackService.triggerLight();
        GameDetailSheet.show(context, game, () => _playGame(game));
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              game.accentColor.withValues(alpha: 0.14),
              const Color(0xFF10172D),
              const Color(0xFF090E1F),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: game.accentColor.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: game.accentColor.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : Numéro, Icône, Badge et Étoile Favori
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: game.accentColor.withValues(alpha: 0.2),
                      ),
                      child: Icon(game.icon, color: game.accentColor, size: 18),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '#${game.id}',
                      style: TextStyle(
                        color: game.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () async {
                    await StorageService.toggleFavorite(game.id);
                    FeedbackService.triggerSelection();
                    setState(() {});
                  },
                  child: Icon(
                    isFav ? Icons.star : Icons.star_border,
                    color: isFav ? const Color(0xFFFFD166) : Colors.white24,
                    size: 20,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Titre du jeu
            Text(
              game.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
                shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
            ),
            const SizedBox(height: 3),

            // Sous-titre
            Text(
              game.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                height: 1.2,
              ),
            ),

            const Spacer(),

            // Bouton JOUER
            SizedBox(
              width: double.infinity,
              height: 32,
              child: ElevatedButton(
                onPressed: () => _playGame(game),
                style: ElevatedButton.styleFrom(
                  backgroundColor: game.accentColor,
                  elevation: 4,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow, color: Colors.black, size: 16),
                    SizedBox(width: 3),
                    Text(
                      'JOUER',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickHubButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF10172D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
