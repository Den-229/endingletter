import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/wordlist_loader.dart';
import 'database_service.dart';

/// Service principal d'accès au dictionnaire local (SQLite + cache mémoire).
///
/// Responsabilités :
///   - Maintenir un `Set<String>` en RAM pour des lookups O(1).
///   - Exposer une API de validation (`isValid`), suggestions
///     (`getWordsStartingWith`), et métadonnées (`getMeta`).
///
/// L'instance doit être initialisée via [ensureLoaded] au démarrage de l'app,
/// puis [reset] peut être appelée pour recharger le cache après une sync.
class DictionaryLocalService {
  DictionaryLocalService._();
  static final DictionaryLocalService instance = DictionaryLocalService._();

  Set<String> _words = const {};
  Map<String, String> _wordCategory = const {};
  Map<String, double> _wordFrequency = const {};
  bool _loaded = false;

  /// True si le service a déjà chargé son cache mémoire.
  bool get isLoaded => _loaded;

  /// Nombre de mots actuellement en cache mémoire.
  int get size => _words.length;

  /// Initialise le service : si la base est vide, importe le seed bundlé ;
  /// puis peuple le `Set<String>` mémoire.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final db = await DatabaseService.instance.open();

    // 1. Si la base est vide, on importe le seed bundlé.
    final countRow = await db.rawQuery('SELECT COUNT(*) AS c FROM words');
    final count = Sqflite.firstIntValue(countRow) ?? 0;
    if (count == 0) {
      if (kDebugMode) {
        debugPrint('📚 Import du seed bundlé…');
      }
      final inserted = await WordlistLoader.importSeed(db);
      await WordlistLoader.importCategoriesAsset(db);
      await _setMeta(db, 'seed_word_count', inserted.toString());
      await _setMeta(db, 'seed_installed_at',
          DateTime.now().toUtc().toIso8601String());
      if (kDebugMode) {
        debugPrint('✅ $inserted mots importés');
      }
    }

    // 2. Charger le Set en mémoire.
    await _reloadCache(db);
    _loaded = true;
  }

  /// Recharge le cache mémoire depuis SQLite. À appeler après une sync.
  Future<void> reset() async {
    _loaded = false;
    await ensureLoaded();
  }

  /// Validation instantanée O(1).
  bool isValid(String word) => _words.contains(word);

  /// Renvoie la catégorie d'un mot, ou 'general' si non classifié.
  String categoryOf(String word) =>
      _wordCategory[word] ?? 'general';

  /// Renvoie la fréquence (rareté) d'un mot ; 1.0 si inconnue.
  double frequencyOf(String word) => _wordFrequency[word] ?? 1.0;

  /// Renvoie N mots du dictionnaire commençant par [letter], filtrés
  /// optionnellement par catégorie.
  Future<List<String>> getWordsStartingWith(
    String letter, {
    String? category,
    int limit = 20,
  }) async {
    final db = DatabaseService.instance.db;
    final l = letter.toLowerCase();

    String where = 'first_letter = ?';
    final args = <Object?>[l];
    if (category != null) {
      where += ' AND category = ?';
      args.add(category);
    }

    final rows = await db.query(
      'words',
      columns: ['word'],
      where: where,
      whereArgs: args,
      orderBy: 'frequency DESC, length ASC',
      limit: limit,
    );
    return rows.map((r) => r['word'] as String).toList();
  }

  /// Renvoie la liste des catégories distinctes présentes en base.
  Future<List<String>> distinctCategories() async {
    final db = DatabaseService.instance.db;
    final rows =
        await db.rawQuery('SELECT DISTINCT category FROM words ORDER BY 1');
    return rows.map((r) => r['category'] as String).toList(growable: false);
  }

  /// Renvoie les métadonnées du dictionnaire local (version, checksum, etc.).
  Future<Map<String, String>> getMeta() async {
    final db = DatabaseService.instance.db;
    final rows = await db.query('dictionary_meta');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  // ──────────────────── Helpers privés ────────────────────

  Future<void> _reloadCache(Database db) async {
    // On charge le Set en streaming pour limiter la RAM (3 Mo tout de même).
    final words = <String>{};
    final categories = <String, String>{};
    final frequencies = <String, double>{};

    final rows = await db.rawQuery('SELECT word, category, frequency FROM words');
    for (final row in rows) {
      final w = row['word'] as String;
      words.add(w);
      categories[w] = row['category'] as String? ?? 'general';
      frequencies[w] = (row['frequency'] as num?)?.toDouble() ?? 1.0;
    }

    _words = words;
    _wordCategory = categories;
    _wordFrequency = frequencies;

    if (kDebugMode) {
      debugPrint(
          '📚 Cache dictionnaire chargé : ${_words.length} mots en mémoire');
    }
  }

  Future<void> _setMeta(Database db, String key, String value) async {
    await db.insert(
      'dictionary_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
