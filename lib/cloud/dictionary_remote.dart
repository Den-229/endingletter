import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'remote_dictionary_manifest.dart';

/// Client Firestore + Storage pour la wordlist.
///
/// Côté lecture (tout le monde) :
///   - [watchLatest] : Stream du manifest courant.
///   - [downloadPayload] : télécharge le gz depuis Storage.
///
/// Côté écriture (admin uniquement) :
///   - [publishPayload] : upload du gz dans Storage + écriture du manifest.
class DictionaryRemote {
  DictionaryRemote._();
  static final DictionaryRemote instance = DictionaryRemote._();

  static const String _latestDocPath = 'dictionaries/latest';
  static const String _historyCollectionPath = 'dictionaries/history';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Stream du manifest courant (ou null s'il n'existe pas encore).
  Stream<RemoteDictionaryManifest?> watchLatest() {
    return _firestore
        .doc(_latestDocPath)
        .snapshots()
        .map((snap) => snap.exists
            ? RemoteDictionaryManifest.fromMap(snap.data()!)
            : null)
        .handleError((Object e) {
      if (kDebugMode) debugPrint('⚠️ watchLatest error: $e');
    });
  }

  /// Lecture ponctuelle du manifest.
  Future<RemoteDictionaryManifest?> getLatest() async {
    final snap = await _firestore.doc(_latestDocPath).get();
    if (!snap.exists) return null;
    return RemoteDictionaryManifest.fromMap(snap.data()!);
  }

  /// Téléchargement du payload gz depuis Storage.
  Future<Uint8List> downloadPayload(String storagePath) async {
    final ref = _storage.ref(storagePath);
    final data = await ref.getData();
    if (data == null) {
      throw StateError('Payload vide à $storagePath');
    }
    return data;
  }

  /// Upload du payload gz et écriture du manifest (admin uniquement).
  Future<void> publishPayload({
    required Uint8List gzBytes,
    required String sha256,
    required String version,
    required String uploadedBy,
  }) async {
    final storagePath = 'dictionaries/v$version.json.gz';

    // 1. Storage
    final ref = _storage.ref(storagePath);
    await ref.putData(
      gzBytes,
      SettableMetadata(contentType: 'application/gzip'),
    );

    // 2. Compter les mots (best-effort, utilisé seulement pour l'UI).
    final wordCount = _bestEffortCount(gzBytes);

    // 3. Manifest
    final manifest = RemoteDictionaryManifest(
      version: version,
      sha256: sha256,
      sizeBytes: gzBytes.length,
      wordCount: wordCount,
      uploadedAt: DateTime.now().toUtc(),
      uploadedBy: uploadedBy,
      storagePath: storagePath,
    );

    final batch = _firestore.batch();
    batch.set(_firestore.doc(_latestDocPath), manifest.toMap());
    batch.set(
      _firestore.collection(_historyCollectionPath).doc(version),
      manifest.toMap(),
    );
    await batch.commit();
  }

  /// Estimation grossière du nombre de mots à partir du gz (utilisée comme
  /// fallback si on ne veut pas décoder le JSON à l'upload). Le sync client
  /// recalcule sa propre valeur après import.
  int _bestEffortCount(Uint8List _) => 0;
}