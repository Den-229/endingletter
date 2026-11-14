import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour la persistance locale des scores, paramètres, XP et trophées.
class StorageService {
  static const String _keyAudioEnabled = 'settings_audio_enabled';
  static const String _keyHapticsEnabled = 'settings_haptics_enabled';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // --- GESTION GÉNÉRIQUE DES HIGH SCORES ---
  static int getHighScore(String gameKey) {
    return _prefs?.getInt('score_$gameKey') ?? 0;
  }

  static Future<bool> saveHighScore(String gameKey, int score) async {
    final current = getHighScore(gameKey);
    if (score > current) {
      await _prefs?.setInt('score_$gameKey', score);
      return true;
    }
    return false;
  }

  // Clés des jeux
  static int getCyberHighScore() => getHighScore('cyber_horizon');
  static Future<bool> saveCyberHighScore(int score) => saveHighScore('cyber_horizon', score);

  static int getGraviHighScore() => getHighScore('gravi_portal');
  static Future<bool> saveGraviHighScore(int score) => saveHighScore('gravi_portal', score);

  static int getSnakeHighScore() => getHighScore('snake');
  static Future<bool> saveSnakeHighScore(int score) => saveHighScore('snake', score);

  static int get2048HighScore() => getHighScore('game_2048');
  static Future<bool> save2048HighScore(int score) => saveHighScore('game_2048', score);

  static int getMathHighScore() => getHighScore('math_sprint');
  static Future<bool> saveMathHighScore(int score) => saveHighScore('math_sprint', score);

  static int getFlappyHighScore() => getHighScore('flappy');
  static Future<bool> saveFlappyHighScore(int score) => saveHighScore('flappy', score);

  static int getBricksHighScore() => getHighScore('brick_breaker');
  static Future<bool> saveBricksHighScore(int score) => saveHighScore('brick_breaker', score);

  static int getSimonHighScore() => getHighScore('simon');
  static Future<bool> saveSimonHighScore(int score) => saveHighScore('simon', score);

  static int getSolitaireHighScore() => getHighScore('solitaire');
  static Future<bool> saveSolitaireHighScore(int score) => saveHighScore('solitaire', score);

  // --- SYSTÈME D'EXPÉRIENCE (XP) & NIVEAU DU JOUEUR ---
  static int getTotalXP() {
    int total = 0;
    total += getCyberHighScore();
    total += getGraviHighScore() * 2;
    total += getSnakeHighScore() * 2;
    total += get2048HighScore();
    total += getMathHighScore();
    total += getFlappyHighScore() * 100;
    total += getBricksHighScore() * 2;
    total += getSimonHighScore() * 150;
    total += getSolitaireHighScore() * 3;
    total += getDailyStreak() * 50;
    return total;
  }

  static int getPlayerLevel() {
    final xp = getTotalXP();
    return (xp / 500).floor() + 1;
  }

  // --- RÉCOMPENSES QUOTIDIENNES & SÉRIE ---
  static const String _keyDailyLastDate = 'daily_last_date';
  static const String _keyDailyStreak = 'daily_streak';

  static int getDailyStreak() => _prefs?.getInt(_keyDailyStreak) ?? 1;

  static bool canClaimDaily() {
    final lastStr = _prefs?.getString(_keyDailyLastDate);
    if (lastStr == null) return true;
    final lastDate = DateTime.tryParse(lastStr);
    if (lastDate == null) return true;
    final now = DateTime.now();
    return now.day != lastDate.day || now.month != lastDate.month || now.year != lastDate.year;
  }

  static Future<int> claimDailyReward() async {
    final now = DateTime.now();
    int currentStreak = getDailyStreak();
    final lastStr = _prefs?.getString(_keyDailyLastDate);
    if (lastStr != null) {
      final lastDate = DateTime.tryParse(lastStr);
      if (lastDate != null) {
        final diffDays = now.difference(lastDate).inDays;
        if (diffDays == 1) {
          currentStreak++;
        } else if (diffDays > 1) {
          currentStreak = 1;
        }
      }
    }
    await _prefs?.setInt(_keyDailyStreak, currentStreak);
    await _prefs?.setString(_keyDailyLastDate, now.toIso8601String());
    return currentStreak * 50; // XP gagné
  }

  // --- FAVORIS & HISTORIQUE RÉCENTS ---
  static const String _keyFavorites = 'user_favorite_games';
  static const String _keyRecents = 'user_recent_games';
  static const String _keyGamesPlayed = 'total_games_played';
  static const String _keyPlayerAvatar = 'player_avatar';
  static const String _keyPlayerTitle = 'player_title';

  static List<int> getFavoriteIds() {
    final list = _prefs?.getStringList(_keyFavorites) ?? [];
    return list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toList();
  }

  static bool isFavorite(int gameId) {
    final favs = getFavoriteIds();
    return favs.contains(gameId);
  }

  static Future<bool> toggleFavorite(int gameId) async {
    final favs = getFavoriteIds();
    bool added;
    if (favs.contains(gameId)) {
      favs.remove(gameId);
      added = false;
    } else {
      favs.add(gameId);
      added = true;
    }
    await _prefs?.setStringList(_keyFavorites, favs.map((e) => e.toString()).toList());
    return added;
  }

  static List<int> getRecentIds() {
    final list = _prefs?.getStringList(_keyRecents) ?? [];
    return list.map((e) => int.tryParse(e) ?? 0).where((id) => id > 0).toList();
  }

  static Future<void> addRecentGame(int gameId) async {
    final recents = getRecentIds();
    recents.remove(gameId);
    recents.insert(0, gameId);
    if (recents.length > 8) {
      recents.removeLast();
    }
    await _prefs?.setStringList(_keyRecents, recents.map((e) => e.toString()).toList());
    await incrementGamesPlayed();
  }

  static int getTotalGamesPlayed() => _prefs?.getInt(_keyGamesPlayed) ?? 0;

  static Future<void> incrementGamesPlayed() async {
    final current = getTotalGamesPlayed();
    await _prefs?.setInt(_keyGamesPlayed, current + 1);
  }

  static Future<void> recordGamePlayed(String gameName) async {
    await incrementGamesPlayed();
  }

  // --- PERSONNALISATION AVATAR & TITRE ---
  static String getPlayerAvatar() => _prefs?.getString(_keyPlayerAvatar) ?? '👾';
  static Future<void> setPlayerAvatar(String avatar) async => await _prefs?.setString(_keyPlayerAvatar, avatar);

  static String getPlayerTitle() => _prefs?.getString(_keyPlayerTitle) ?? 'Gamer d\'Élite';
  static Future<void> setPlayerTitle(String title) async => await _prefs?.setString(_keyPlayerTitle, title);

  // --- SUCCÈS & TROPHÉES ---
  static const String _keyAchievements = 'unlocked_achievements';

  static List<String> getUnlockedAchievements() => _prefs?.getStringList(_keyAchievements) ?? ['debutant'];

  static bool isAchievementUnlocked(String id) => getUnlockedAchievements().contains(id);

  static Future<bool> unlockAchievement(String id) async {
    final list = getUnlockedAchievements();
    if (!list.contains(id)) {
      list.add(id);
      await _prefs?.setStringList(_keyAchievements, list);
      return true;
    }
    return false;
  }

  // --- QUÊTES QUOTIDIENNES ---
  static const String _keyQuestClaimPrefix = 'quest_claimed_';

  static bool isQuestClaimed(String questId) {
    return _prefs?.getBool('$_keyQuestClaimPrefix$questId') ?? false;
  }

  static Future<void> claimQuest(String questId) async {
    await _prefs?.setBool('$_keyQuestClaimPrefix$questId', true);
  }

  // --- PARAMÈTRES AUDIO & HAPTIQUE ---
  static bool isAudioEnabled() => _prefs?.getBool(_keyAudioEnabled) ?? true;
  static Future<void> setAudioEnabled(bool value) async => await _prefs?.setBool(_keyAudioEnabled, value);

  static bool isHapticsEnabled() => _prefs?.getBool(_keyHapticsEnabled) ?? true;
  static Future<void> setHapticsEnabled(bool value) async => await _prefs?.setBool(_keyHapticsEnabled, value);
}

/// Système de feedback sensoriel haptique et sonore
class FeedbackService {
  static void triggerImpact() {
    if (StorageService.isHapticsEnabled()) {
      HapticFeedback.mediumImpact();
    }
    if (StorageService.isAudioEnabled()) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  static void triggerLight() {
    if (StorageService.isHapticsEnabled()) {
      HapticFeedback.lightImpact();
    }
    if (StorageService.isAudioEnabled()) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  static void triggerSuccess() {
    if (StorageService.isHapticsEnabled()) {
      HapticFeedback.heavyImpact();
    }
    if (StorageService.isAudioEnabled()) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  static void triggerSelection() {
    if (StorageService.isHapticsEnabled()) {
      HapticFeedback.selectionClick();
    }
    if (StorageService.isAudioEnabled()) {
      SystemSound.play(SystemSoundType.click);
    }
  }
}
