import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'lan_lobby_screen.dart';

/// Écran d'entrée LAN : « Héberger » vs « Rejoindre ».
///
/// L'hébergeur ouvre un socket TCP, diffuse une balise UDP toutes les 2 s et
/// attend qu'un invité se connecte. L'invité écoute les balises, affiche les
/// hôtes trouvés, et s'y connecte.
class LanEntryScreen extends StatelessWidget {
  const LanEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multijoueur LAN'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.wifi_tethering,
                size: 80,
                color: theme.colorScheme.primary,
              )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 16),
              Text(
                'Jouez à deux\nsur le même Wi-Fi',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ).animate().fade(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                'Aucun Internet requis : la connexion se fait en direct entre\n'
                'les deux téléphones, via votre routeur ou un hotspot.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ).animate().fade(delay: 300.ms),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const LanLobbyScreen(role: LanRole.host),
                    ),
                  );
                },
                icon: const Icon(Icons.cast_connected),
                label: const Text('HÉBERGER UNE PARTIE'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ).animate().fade(delay: 400.ms).slideY(begin: 0.2),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const LanLobbyScreen(role: LanRole.guest),
                    ),
                  );
                },
                icon: const Icon(Icons.devices_other),
                label: const Text('REJOINDRE UNE PARTIE'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ).animate().fade(delay: 500.ms).slideY(begin: 0.2),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rôle de l'utilisateur dans le lobby LAN.
enum LanRole { host, guest }