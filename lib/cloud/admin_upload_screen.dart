import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../auth/auth_service.dart';
import '../services/database_service.dart';
import '../shared/connectivity_gate.dart';
import '../utils/wordlist_loader.dart';
import 'dictionary_remote.dart';
import 'dictionary_sync_service.dart';

/// Écran admin : publie la wordlist locale dans le cloud.
///
/// 1. Calcule le SHA-256 de la wordlist locale.
/// 2. Compare à la version cloud : si identiques, on évite l'upload.
/// 3. Sinon, gzipe + upload Storage + écrit le manifest Firestore.
class AdminUploadScreen extends StatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  String _status = '';
  bool _isUploading = false;
  String? _localSha;
  String? _remoteSha;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final db = DatabaseService.instance.db;
    final rows =
        await db.rawQuery('SELECT COUNT(*) AS c FROM words');
    final count = (rows.first['c'] as int?) ?? 0;
    final localSha = await DictionarySyncService.instance.getLocalSha256();

    // Lire la dernière version cloud (best effort).
    String? remoteSha;
    if (await ConnectivityGate.instance.isOnline()) {
      final remote = await DictionaryRemote.instance.getLatest();
      remoteSha = remote?.sha256;
    }

    if (!mounted) return;
    setState(() {
      _wordCount = count;
      _localSha = localSha;
      _remoteSha = remoteSha;
    });
  }

  Future<void> _upload() async {
    if (!AuthService.instance.isAdmin) {
      _toast('Vous devez être administrateur pour publier.');
      return;
    }
    setState(() {
      _isUploading = true;
      _status = 'Préparation de la wordlist locale…';
    });

    try {
      // 1. Export
      final version = 'v${DateFormat('yyyy-MM-dd-HHmm').format(DateTime.now().toUtc())}';
      final bytes = await WordlistLoader.exportJsonSync(
          DatabaseService.instance.db, version);

      // 2. SHA-256 local des bytes gzippés
      final sha = sha256.convert(bytes).toString();
      setState(() => _status = 'Upload vers le cloud… (~${(bytes.length / 1024).toStringAsFixed(0)} Ko)');

      // 3. Upload + manifest
      await DictionaryRemote.instance.publishPayload(
        gzBytes: bytes,
        sha256: sha,
        version: version,
        uploadedBy: AuthService.instance.currentUser!.uid,
      );

      if (!mounted) return;
      setState(() {
        _status = '✅ Publication $version réussie.';
        _remoteSha = sha;
        _isUploading = false;
      });
      _toast('Wordlist $version publiée.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = '❌ Échec : $e';
        _isUploading = false;
      });
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canUpload = AuthService.instance.isAdmin &&
        _localSha != null &&
        _localSha != _remoteSha;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publier la wordlist'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('État local',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('$_wordCount mots en base'),
                      const SizedBox(height: 4),
                      Text(
                        'SHA-256 : ${_short(_localSha)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('État cloud',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_remoteSha == null
                          ? 'Aucun manifest publié'
                          : 'SHA-256 : ${_short(_remoteSha)}'),
                      const SizedBox(height: 4),
                      Text(
                        _localSha == _remoteSha
                            ? '✅ Local et cloud identiques.'
                            : '⚠️ Local différent du cloud.',
                        style: TextStyle(
                          color: _localSha == _remoteSha
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_status.isNotEmpty)
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: (_isUploading || !canUpload) ? null : _upload,
                icon: const Icon(Icons.cloud_upload),
                label: Text(_isUploading
                    ? 'Publication…'
                    : (_localSha == _remoteSha
                        ? 'DÉJÀ À JOUR'
                        : 'PUBLIER')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ).animate().fade().slideY(begin: 0.2),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualiser'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _short(String? sha) {
    if (sha == null || sha.isEmpty) return '—';
    return '${sha.substring(0, sha.length < 16 ? sha.length : 16)}…';
  }
}