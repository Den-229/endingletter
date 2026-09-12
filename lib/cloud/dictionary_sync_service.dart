import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show Database, ConflictAlgorithm;

import '../services/database_service.dart';
import '../services/dictionary_local_service.dart';
import '../shared/connectivity_gate.dart';
import '../shared/result.dart';
import '../utils/wordlist_loader.dart';
import 'dictionary_remote.dart';
import 'remote_dictionary_manifest.dart';

/// Orchestrateur de synchronisation du dictionnaire local depuis le cloud.
///
/// Flux `checkAndApply` :
///   1. Vérifie la connectivité.
///   2. Lit le manifest `dictionaries/latest`.
///   3. Compare `remote.sha256` au dernier `dictionary_sync_state.remote_sha256`.
///      Si match → `SyncAlreadyUpToDate`.
///   4. Télécharge le gz depuis Storage.
///   5. Vérifie le SHA-256 local des bytes ; mismatch → `SyncVerificationFailed`.
///   6. Importe via `WordlistLoader.importJsonSync`.
///   7. Écrit `dictionary_sync_state` + meta + `DictionaryLocalService.reset()`.
class DictionarySyncService {
  DictionarySyncService._();
  static final DictionarySyncService instance = DictionarySyncService._();

  /// SHA-256 d'une wordlist locale (concaténation triée). Permet de détecter
  /// une modification locale (admin upload) avant de comparer au cloud.
  Future<String> getLocalSha256() async {
    final db = DatabaseService.instance.db;
    final rows = await db.rawQuery(
        'SELECT word, frequency, category FROM words ORDER BY word');
    final buffer = StringBuffer();
    for (final r in rows) {
      buffer
        ..write(r['word'])
        ..write('|')
        ..write(r['frequency'])
        ..write('|')
        ..write(r['category'])
        ..write('\n');
    }
    return sha256.convert(buffer.toString().codeUnits).toString();
  }

  Future<SyncResult<RemoteSyncOutcome>> checkAndApply({bool force = false}) async {
    // 1. Connectivité ?
    if (!await ConnectivityGate.instance.isOnline()) {
      return const SyncOffline();
    }

    // 2. Manifest ?
    final manifest = await DictionaryRemote.instance.getLatest();
    if (manifest == null) {
      return const SyncFailure('Aucun dictionnaire publié sur le cloud.');
    }

    // 3. Déjà à jour ?
    final db = DatabaseService.instance.db;
    if (!force) {
      final lastApplied = await _lastAppliedSyncState(db);
      if (lastApplied != null &&
          lastApplied.remoteSha256 == manifest.sha256) {
        return SyncAlreadyUpToDate(manifest.sha256);
      }
    }

    // 4. Téléchargement
    Uint8List bytes;
    try {
      bytes = await DictionaryRemote.instance
          .downloadPayload(manifest.storagePath);
    } catch (e) {
      return SyncFailure('Téléchargement impossible: $e');
    }

    // 5. Vérification SHA-256
    final computedSha = sha256.convert(bytes).toString();
    if (computedSha != manifest.sha256) {
      return SyncVerificationFailed(
        'SHA-256 attendu ${manifest.sha256}, '
        'reçu ${computedSha.substring(0, 12)}…',
      );
    }

    // 6. Application
    try {
      await WordlistLoader.importJsonSync(db, bytes, manifest.version);
    } catch (e) {
      return SyncFailure('Import local échoué: $e');
    }

    // 7. Persistance meta + reset cache mémoire
    await _writeSyncState(db, manifest, computedSha);
    await DictionaryLocalService.instance.reset();

    if (kDebugMode) {
      debugPrint(
          '✅ Sync dictionnaire OK: ${manifest.wordCount} mots (${manifest.version})');
    }

    return SyncSuccess(RemoteSyncOutcome(
      version: manifest.version,
      sha256: computedSha,
      wordCount: manifest.wordCount,
    ));
  }

  Future<LastSyncState?> _lastAppliedSyncState(Database db) async {
    final rows = await db.query('dictionary_sync_state',
        orderBy: 'applied_at DESC', limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return LastSyncState(
      remoteSha256: r['remote_sha256'] as String,
      remoteVersion: r['remote_version'] as String,
      appliedAt: DateTime.fromMillisecondsSinceEpoch(
        r['applied_at'] as int,
      ),
    );
  }

  Future<void> _writeSyncState(
    Database db,
    RemoteDictionaryManifest manifest,
    String computedSha,
  ) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.insert(
      'dictionary_sync_state',
      {
        'local_sha256': computedSha,
        'remote_version': manifest.version,
        'remote_sha256': manifest.sha256,
        'applied_at': now,
        'source': 'firestore',
      },
    );
    await db.insert(
      'dictionary_meta',
      {'key': 'remote_version', 'value': manifest.version},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'dictionary_meta',
      {'key': 'remote_sha256', 'value': manifest.sha256},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'dictionary_meta',
      {'key': 'remote_applied_at', 'value': now.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

/// Outcome retourné par un sync réussi.
class RemoteSyncOutcome {
  const RemoteSyncOutcome({
    required this.version,
    required this.sha256,
    required this.wordCount,
  });
  final String version;
  final String sha256;
  final int wordCount;
}

class LastSyncState {
  const LastSyncState({
    required this.remoteSha256,
    required this.remoteVersion,
    required this.appliedAt,
  });
  final String remoteSha256;
  final String remoteVersion;
  final DateTime appliedAt;
}