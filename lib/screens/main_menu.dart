import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../auth/app_user.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../cloud/admin_upload_screen.dart';
import '../cloud/dictionary_sync_service.dart';
import '../game/game_mode.dart';
import '../shared/result.dart';
import 'account_screen.dart';
import 'game_screen.dart';
import 'lan_entry_screen.dart';

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.authStateChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Icon(
                    Icons.sort_by_alpha,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ).animate().scale(
                      duration: 600.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 24),
                  Text(
                    'ENDING LETTER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
                  const SizedBox(height: 12),
                  Text(
                    'Trouvez un mot anglais commençant par la dernière '
                    'lettre du mot précédent.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ).animate().fade(delay: 400.ms),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GameScreen(
                            mode: GameMode.passAndPlay,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('JOUER (Pass & Play)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.5),
                    ),
                  ).animate().fade(delay: 600.ms).slideY(begin: 0.2),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const GameScreen(mode: GameMode.solo),
                        ),
                      );
                    },
                    icon: const Icon(Icons.smart_toy),
                    label: const Text('SOLO CONTRE L\'IA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ).animate().fade(delay: 650.ms).slideY(begin: 0.2),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LanEntryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('MULTIJOUEUR LAN'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.5),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ).animate().fade(delay: 700.ms).slideY(begin: 0.2),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _syncDictionary(context),
                    icon: const Icon(Icons.cloud_sync),
                    label: const Text('SYNCHRONISER LE DICTIONNAIRE'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ).animate().fade(delay: 750.ms),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (user != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openAdmin(context),
                            icon: const Icon(Icons.admin_panel_settings),
                            label: Text(user.isAdmin
                                ? 'PUBLIER (admin)'
                                : 'ADMINISTRATION'),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: user.isAdmin
                                    ? Colors.green.withValues(alpha: 0.6)
                                    : Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ).animate().fade(),
                        ),
                      if (user != null) const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openAccount(context),
                          icon: Icon(
                              user != null ? Icons.account_circle : Icons.login),
                          label: Text(user != null ? 'COMPTE' : 'CONNEXION'),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ).animate().fade(),
                      ),
                    ],
                  ).animate().fade(delay: 800.ms),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showRules(context),
                    icon: const Icon(Icons.help_outline),
                    label: const Text('RÈGLES DU JEU'),
                  ).animate().fade(delay: 850.ms),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _syncDictionary(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await DictionarySyncService.instance.checkAndApply();
    if (!context.mounted) return;
    switch (result) {
      case SyncAlreadyUpToDate():
        messenger.showSnackBar(const SnackBar(
          content: Text('✅ Dictionnaire déjà à jour.'),
          backgroundColor: Colors.green,
        ));
      case SyncOffline():
        messenger.showSnackBar(const SnackBar(
          content: Text('❌ Pas de connexion Internet.'),
          backgroundColor: Colors.orange,
        ));
      case SyncVerificationFailed(:final reason):
        messenger.showSnackBar(SnackBar(
          content: Text('❌ Vérification SHA-256 échouée : $reason'),
          backgroundColor: Colors.red,
        ));
      case SyncFailure(:final message):
        messenger.showSnackBar(SnackBar(
          content: Text('❌ Sync échouée : $message'),
          backgroundColor: Colors.red,
        ));
      case SyncSuccess(:final data):
        messenger.showSnackBar(SnackBar(
          content: Text(
              '✅ Dictionnaire synchronisé (${data.wordCount} mots, ${data.version}).'),
          backgroundColor: Colors.green,
        ));
    }
  }

  void _openAdmin(BuildContext context) {
    if (AuthService.instance.isAdmin) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminUploadScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _openAccount(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AccountScreen()),
      );
    }
  }

  void _showRules(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Règles du Jeu'),
        content: const Text(
          '1. Chaque joueur doit entrer un mot anglais valide commençant '
          'par la DERNIÈRE lettre du mot précédent.\n\n'
          '2. Vous ne pouvez pas réutiliser un mot déjà joué.\n\n'
          '3. Solo : affrontez une IA locale qui répond automatiquement.\n\n'
          '4. Multijoueur LAN : deux téléphones sur le même Wi-Fi ou en '
          'hotspot, sans Internet.\n\n'
          '5. Le dictionnaire est 100% local — jouez hors-ligne. '
          'Les administrateurs peuvent publier une mise à jour via Firebase, '
          'que vous sync manuellement depuis le menu Compte.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('COMPRIS'),
          ),
        ],
      ),
    );
  }
}