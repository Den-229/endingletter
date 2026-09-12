import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

/// Parse et importe des wordlists dans la base SQLite.
///
/// Formats supportés :
///   - Seed asset bundlé : gzip d'un fichier texte (un mot par ligne).
///   - Sync distante : gzip d'un JSON `{"version", "categories", "frequencies"}`.
class WordlistLoader {
  WordlistLoader._();

  /// Taille des batchs d'insertion (équilibre perf / mémoire).
  static const int _batchSize = 1000;

  /// Chemin du seed gzip dans les assets Flutter.
  static const String seedAssetPath = 'assets/dictionary/enable_seed.txt.gz';

  /// Chemin du mapping catégories dans les assets.
  static const String categoriesAssetPath =
      'assets/categories/enable_categories.json';

  /// Importe le seed bundlé (gzip → txt → SQLite).
  /// Retourne le nombre de mots insérés.
  static Future<int> importSeed(Database db,
      {String sourceVersion = 'enable-seed'}) async {
    final bytes = await rootBundle.load(seedAssetPath);
    final decompressed = _gunzip(bytes.buffer.asUint8List());
    final text = utf8.decode(decompressed);
    return _importTxt(db, text, sourceVersion);
  }

  /// Importe un mapping mot → catégorie depuis l'asset JSON.
  /// Retourne le nombre de paires importées.
  static Future<int> importCategoriesAsset(Database db) async {
    final raw = await rootBundle.loadString(categoriesAssetPath);
    return importCategoriesJson(db, raw);
  }

  /// Parse un JSON de catégories et update la table `words`.
  /// Format attendu : `{"version": 1, "categories": {"word": "category", ...}}`.
  static Future<int> importCategoriesJson(
      Database db, String jsonContent) async {
    final map = jsonDecode(jsonContent) as Map<String, dynamic>;
    final categories = (map['categories'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k.toString().toLowerCase(), v.toString()));

    if (categories.isEmpty) return 0;

    final batch = <Map<String, Object?>>[];
    int updated = 0;
    for (final entry in categories.entries) {
      batch.add({'word': entry.key, 'category': entry.value});
      if (batch.length >= _batchSize) {
        updated += await _flushCategories(db, batch);
        batch.clear();
      }
    }
    if (batch.isNotEmpty) updated += await _flushCategories(db, batch);
    return updated;
  }

  /// Exporte la table `words` vers un JSON gzippé prêt pour Firestore/Storage.
/// Format produit (gzip body) :
///   ```json
///   {
///     "version":     "<version>",
///     "wordCount":   <integer>,
///     "frequencies": { "apple": 0.001, ... },
///     "categories":  { "apple": ["food"], ... }
///   }
///   ```
/// Utilisé par [AdminUploadScreen] pour publier la wordlist.
  static Future<Uint8List> exportJsonSync(
      Database db, String version) async {
    final rows = await db.query('words',
        columns: ['word', 'frequency', 'category'], orderBy: 'word');

    final frequencies = <String, double>{};
    final categories = <String, List<String>>{};
    for (final row in rows) {
      final w = row['word'] as String;
      frequencies[w] = (row['frequency'] as num).toDouble();
      categories[w] = [(row['category'] as String?) ?? 'general'];
    }

    final root = <String, dynamic>{
      'version': version,
      'wordCount': rows.length,
      'frequencies': frequencies,
      'categories': categories,
    };

    final bytes = utf8.encode(jsonEncode(root));
    final gz = GZipEncoder().encode(bytes);
    if (gz == null) {
      throw const FormatException('GZipEncoder a renvoyé null');
    }
    return Uint8List.fromList(gz);
  }

  /// Importe un JSON gzip téléchargé (sync Firestore future).
  static Future<int> importJsonSync(
      Database db, Uint8List gzBytes, String version) async {
    final jsonStr = utf8.decode(_gunzip(gzBytes));
    final root = jsonDecode(jsonStr) as Map<String, dynamic>;

    final categories = (root['categories'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(
                k.toString().toLowerCase(),
                (v as List).map((e) => e.toString().toLowerCase()).toList()))
        ??
        <String, List<String>>{};

    final frequencies = (root['frequencies'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k.toString().toLowerCase(),
                (v as num).toDouble())) ??
        <String, double>{};

    // Construit la liste union de tous les mots présents soit en `frequencies`
    // soit en `categories` (la clé du map est le mot lui-même).
    final allWords = <String>{
      ...frequencies.keys,
      ...categories.keys,
    };

    if (allWords.isEmpty) return 0;

    final batch = <Map<String, Object?>>[];
    int inserted = 0;
    for (final word in allWords) {
      final freq = frequencies[word] ?? 1.0;
      final cats = categories[word];
      final cat = (cats == null || cats.isEmpty) ? 'general' : cats.first;

      batch.add({
        'word': word,
        'length': word.length,
        'first_letter': word.isEmpty ? '' : word[0],
        'last_letter': word.isEmpty ? '' : word[word.length - 1],
        'frequency': freq,
        'category': cat,
        'source_version': version,
      });

      if (batch.length >= _batchSize) {
        inserted += await _flushWords(db, batch);
        batch.clear();
      }
    }
    if (batch.isNotEmpty) inserted += await _flushWords(db, batch);
    return inserted;
  }

  // ──────────────────────── Helpers privés ────────────────────────

  static Future<int> _importTxt(
      Database db, String text, String sourceVersion) async {
    final batch = <Map<String, Object?>>[];
    int inserted = 0;
    for (final raw in text.split('\n')) {
      final word = raw.trim().toLowerCase();
      if (word.isEmpty || !RegExp(r'^[a-z]+$').hasMatch(word)) continue;

      batch.add({
        'word': word,
        'length': word.length,
        'first_letter': word[0],
        'last_letter': word[word.length - 1],
        'frequency': 1.0,
        'category': 'general',
        'source_version': sourceVersion,
      });

      if (batch.length >= _batchSize) {
        inserted += await _flushWords(db, batch);
        batch.clear();
      }
    }
    if (batch.isNotEmpty) inserted += await _flushWords(db, batch);
    return inserted;
  }

  static Future<int> _flushWords(
      Database db, List<Map<String, Object?>> rows) async {
    await db.transaction((txn) async {
      for (final row in rows) {
        await txn.insert('words', row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return rows.length;
  }

  static Future<int> _flushCategories(
      Database db, List<Map<String, Object?>> rows) async {
    int updated = 0;
    await db.transaction((txn) async {
      for (final row in rows) {
        final n = await txn.rawUpdate(
          'UPDATE words SET category = ? WHERE word = ?',
          [row['category'], row['word']],
        );
        updated += n;
      }
    });
    return updated;
  }

  static Uint8List _gunzip(Uint8List bytes) {
    // Décompression GZIP (RFC 1952). Le wordlist est un gzip natif,
    // pas un archive ZIP.
    final decoded = GZipDecoder().decodeBytes(bytes);
    if (decoded.isEmpty) {
      throw const FormatException('Archive gzip vide');
    }
    return Uint8List.fromList(decoded);
  }
}
