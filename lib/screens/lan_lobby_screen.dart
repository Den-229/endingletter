import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../game/game_mode.dart';
import '../lan/lan_discovery.dart';
import '../lan/lan_socket.dart';
import 'game_screen.dart';
import 'lan_entry_screen.dart';

/// Lobby LAN :
///   - Host : affiche l'IP locale, lance la balise UDP, attend un guest TCP.
///   - Guest : scanne les hôtes (mDNS broadcast), permet de s'y connecter.
///
/// Une fois la connexion TCP établie, on lance `GameScreen` avec le mode
/// LAN approprié.
class LanLobbyScreen extends StatefulWidget {
  const LanLobbyScreen({super.key, required this.role});

  final LanRole role;

  @override
  State<LanLobbyScreen> createState() => _LanLobbyScreenState();
}

class _LanLobbyScreenState extends State<LanLobbyScreen> {
  String? _localIp;
  Future<void> Function()? _stopBeacon;
  LanSocket? _hostSocket;
  StreamSubscription<List<LanHost>>? _scanSub;
  List<LanHost> _hosts = const [];
  bool _connecting = false;
  String? _connectError;
  final String _hostName = 'Hôte';

  @override
  void initState() {
    super.initState();
    if (widget.role == LanRole.host) {
      _startHost();
    } else {
      _startScan();
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _stopBeacon?.call();
    _hostSocket?.close();
    super.dispose();
  }

  // ─── Host ─────────────────────────────────────────────────────────────

  Future<void> _startHost() async {
    final ip = await LanDiscovery.localIp();
    try {
      _hostSocket = await LanSocket.bind(hostName: 'host');
    } catch (e) {
      if (!mounted) return;
      setState(() => _connectError = 'Impossible d\'ouvrir le socket : $e');
      return;
    }
    final stop = await LanDiscovery.startAdvertising(
      hostName: _hostName,
      tcpPort: _hostSocket!.port,
    );
    if (!mounted) return;
    setState(() {
      _localIp = ip;
      _stopBeacon = stop;
    });
  }

  // ─── Guest ────────────────────────────────────────────────────────────

  void _startScan() {
    _scanSub = LanDiscovery.watchHosts(interval: const Duration(seconds: 2))
        .listen((hosts) {
      if (!mounted) return;
      setState(() => _hosts = hosts);
    });
  }

  Future<void> _join(LanHost host) async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _connectError = null;
    });
    try {
      final sock = await LanSocket.connect(
        host: host.host,
        port: host.port,
        playerName: 'Invité',
      );
      _scanSub?.cancel();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            mode: GameMode.lanGuest,
            transport: sock,
            peerLabel: host.name,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connectError = 'Connexion impossible à ${host.name} '
            '(${host.host}) : $e';
      });
    }
  }

  Future<void> _joinByIp() async {
    final ctrl = TextEditingController();
    final portCtrl = TextEditingController(text: '45678');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejoindre par IP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Adresse IP de l\'hôte',
                hintText: '192.168.1.42',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portCtrl,
              decoration: const InputDecoration(
                labelText: 'Port TCP',
                hintText: '45678',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('REJOINDRE'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final ip = ctrl.text.trim();
    final port = int.tryParse(portCtrl.text.trim()) ?? 45678;
    if (ip.isEmpty) return;
    await _join(LanHost(name: 'Manuel', host: ip, port: port));
  }

  // ─── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.role == LanRole.host
            ? 'Héberger une partie'
            : 'Rejoindre une partie'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: widget.role == LanRole.host
            ? _buildHostBody(theme)
            : _buildGuestBody(theme),
      ),
    );
  }

  Widget _buildHostBody(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.cast_connected,
            size: 64,
            color: theme.colorScheme.primary,
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1500.ms, color: theme.colorScheme.secondary),
          const SizedBox(height: 16),
          Text(
            'En attente d\'un joueur…',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          Card(
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Votre IP locale',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _localIp ?? 'Détection…',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Port TCP : ${_hostSocket?.port ?? '—'}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'L\'invité peut soit rejoindre automatiquement si la\n'
                    'découverte fonctionne, soit utiliser « Rejoindre par IP »\n'
                    'avec cette adresse et ce port.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_connectError != null)
            Card(
              color: Colors.red.withValues(alpha: 0.15),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _connectError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () {
              _stopBeacon?.call();
              _hostSocket?.close();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('ANNULER'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestBody(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _hosts.isEmpty
                  ? 'Recherche d\'hôtes sur le réseau…'
                  : '${_hosts.length} hôte${_hosts.length > 1 ? 's' : ''} '
                      'trouvé${_hosts.length > 1 ? 's' : ''}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (_connectError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Card(
                color: Colors.red.withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _connectError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _hosts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.radar,
                          size: 64,
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.5),
                        )
                            .animate(onPlay: (c) => c.repeat())
                            .scaleXY(
                              begin: 0.9,
                              end: 1.1,
                              duration: 1200.ms,
                              curve: Curves.easeInOut,
                            ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun hôte détecté.\n'
                          'Vérifiez que vous êtes sur le même Wi-Fi.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _hosts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final h = _hosts[i];
                      return Card(
                        color: theme.colorScheme.surface,
                        child: ListTile(
                          leading: Icon(
                            Icons.computer,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(
                            h.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${h.host}:${h.port}'),
                          trailing: _connecting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: _connecting ? null : () => _join(h),
                        ),
                      ).animate().fade().slideX(begin: 0.2);
                    },
                  ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _connecting ? null : _joinByIp,
            icon: const Icon(Icons.edit),
            label: const Text('Rejoindre par IP (manuel)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}