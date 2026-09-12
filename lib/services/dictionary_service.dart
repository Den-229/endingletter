import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'database_service.dart';
import 'dictionary_local_service.dart';

/// Orchestrateur de validation des mots anglais.
///
/// Stratégie (offline-first) :
///   1. **Cache local** (SQLite + Set mémoire) → réponse O(1).
///   2. Si absent et en ligne → appel API `dictionaryapi.dev` (fallback).
///      Le mot validé est alors inséré dans `api_validated_words` et
///      dans le Set en mémoire (propagation en background).
///   3. Sinon (hors-ligne + pas dans le cache) → mot invalide.
class DictionaryService {
  static const String _apiBaseUrl =
      'https://api.dictionaryapi.dev/api/v2/entries/en/';

  /// Vérifie si [word] est un mot anglais valide.
  /// [word] doit déjà avoir été nettoyé (trim + lowercase) par l'appelant.
  static Future<bool> isValidEnglishWord(String word) async {
    if (word.trim().isEmpty || !RegExp(r'^[a-zA-Z]+$').hasMatch(word)) {
      return false;
    }

    final cleaned = word.toLowerCase();

    // 1. Local cache ?
    final local = DictionaryLocalService.instance;
    if (local.isLoaded && local.isValid(cleaned)) {
      return true;
    }

    // 2. Online + API externe ?
    final connectivity = await Connectivity().checkConnectivity();
    final online = connectivity.isNotEmpty &&
        connectivity.any((r) => r != ConnectivityResult.none);

    if (online) {
      try {
        final response =
            await http.get(Uri.parse('$_apiBaseUrl$cleaned'));
        if (response.statusCode == 200) {
          // Cache pour la prochaine fois.
          await _cacheApiValidatedWord(cleaned);
          return true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ API indisponible : $e');
      }
    }

    return false;
  }

  static Future<void> _cacheApiValidatedWord(String word) async {
    try {
      final db = DatabaseService.instance.db;
      await db.insert(
        'api_validated_words',
        {
          'word': word,
          'validated_at': DateTime.now().millisecondsSinceEpoch,
          'hits': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // On ne modifie pas le Set mémoire ici (trop invasif pour un fallback),
      // mais on pourrait appeler local.reset() pour propager.
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Cache API word failed: $e');
    }
  }
}
