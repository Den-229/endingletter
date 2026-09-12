import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../cloud/dictionary_sync_service.dart';
import '../services/database_service.dart';
import '../services/dictionary_local_service.dart';
import '../shared/connectivity_gate.dart';
import '../shared/result.dart';

/// Écran « Compte » : utilisateur connecté, rôle, état du dictionnaire,
/// bouton de sync manuel, déconnexion.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _loading = true;
  int _localWordCount = 0;
  String? _localVersion;
  DateTime? _lastSync;
  String? _lastSyncSha;
  bool _syncing = false;
  bool _online = false;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _refresh();
    _connectivitySub = ConnectivityGate.instance.online.listen((v) {
      if (mounted) setState(() => _online = v);
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final db = DatabaseService.instance.db;
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM words');
      final count = (rows.first['c'] as int?) ?? 0;
      final meta = await DictionaryLocalService.instance.getMeta();
      final appliedAtStr = meta['remote_applied_at'];
      DateTime? appliedAt;
      if (appliedAtStr != null) {
        final ts = int.tryParse(appliedAtStr);
        if (ts != null) appliedAt = DateTime.fromMillisecondsSinceEpoch(ts);
      }
      if (!mounted) return;
      setState(() {
        _localWordCount = count;
        _localVersion = meta['remote_version'];
        _lastSync = appliedAt;
        _lastSyncSha = meta['remote_sha256'];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final messenger = ScaffoldMessenger.of(context);
    final result = await DictionarySyncService.instance.checkAndApply();
    if (!mounted) return;
    setState(() => _syncing = false);
    await _refresh();
    final msg = switch (result) {
      SyncSuccess(:final data) =>
        '✅ Sync OK — ${data.wordCount} mots (${data.version}).',
      SyncAlreadyUpToDate() => '✅ Déjà à jour.',
      SyncOffline() => '❌ Pas de connexion Internet.',
      SyncVerificationFailed(:final reason) =>
        '❌ SHA-256 invalide : $reason',
      SyncFailure(:final message) => '❌ Échec : $message',
    };
    messenger.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: switch (result) {
        SyncSuccess() || SyncAlreadyUpToDate() => Colors.green,
        SyncOffline() => Colors.orange,
        _ => Colors.red,
      },
    ));
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    setState(() {});
  }

  String _formatAge(Duration d) {
    if (d.inDays > 0) return 'il y a ${d.inDays} j';
    if (d.inHours > 0) return 'il y a ${d.inHours} h';
    if (d.inMinutes > 0) return 'il y a ${d.inMinutes} min';
    return 'à l\'instant';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthService.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compte & Sync'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _userCard(theme, user),
              const SizedBox(height: 16),
              _dictionaryCard(theme),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: (_syncing || !_online) ? null : _sync,
                icon: _syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_sync),
                label: Text(
                  _syncing
                      ? 'Synchronisation…'
                      : 'Synchroniser avec le cloud',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ).animate().fade().slideY(begin: 0.2),
              if (!_online) ...[
                const SizedBox(height: 8),
                Text(
                  'Connexion Internet requise pour la sync.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Le dictionnaire reste 100% local : aucune connexion requise '
                'pour jouer. La sync permet de récupérer la dernière mise à '
                'jour publiée par un administrateur.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userCard(ThemeData theme, dynamic user) {
    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              user != null ? Icons.verified_user : Icons.person_off,
              size: 40,
              color: user != null
                  ? (user.isAdmin ? Colors.green : Colors.blue)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.email ?? 'Non connecté',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    user == null
                        ? 'Connectez-vous pour synchroniser.'
                        : (user.isAdmin
                            ? 'Administrateur'
                            : 'Utilisateur'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: user?.isAdmin == true
                          ? Colors.green
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (user != null)
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Se déconnecter',
                onPressed: _signOut,
              )
            else
              TextButton(
                onPressed: _openLogin,
                child: const Text('CONNEXION'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dictionaryCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dictionnaire local',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              _kv(theme, 'Mots en base', '$_localWordCount'),
              _kv(
                theme,
                'Version installée',
                _localVersion ?? 'seed local',
              ),
              _kv(
                theme,
                'Dernière sync',
                _lastSync == null
                    ? 'jamais'
                    : _formatAge(DateTime.now().difference(_lastSync!)),
              ),
              if (_lastSyncSha != null)
                _kv(theme, 'SHA-256',
                    '${_lastSyncSha!.substring(0, 12)}…'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(ThemeData theme, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}