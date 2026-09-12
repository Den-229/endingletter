import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Hôte découvert sur le réseau local.
class LanHost {
  const LanHost({
    required this.name,
    required this.host,
    required this.port,
    this.txt = const {},
  });

  final String name;
  final String host; // IP
  final int port;
  final Map<String, String> txt;

  factory LanHost.fromBeacon(Map<String, dynamic> beacon, String ip) {
    return LanHost(
      name: (beacon['name'] as String?) ?? 'Hôte',
      host: ip,
      port: (beacon['port'] as num?)?.toInt() ?? 0,
      txt: {
        if (beacon['version'] != null) 'version': '${beacon['version']}',
        if (beacon['app'] != null) 'app': '${beacon['app']}',
      },
    );
  }

  @override
  String toString() => 'LanHost($name @ $host:$port)';
}

/// Découverte LAN via UDP broadcast sur [_lanBeaconPort].
///
/// Format de la balise (JSON, UTF-8, ≤512 octets) :
///   ```
///   {
///     "app":     "endingletter",
///     "version": 1,
///     "name":    "Alice",
///     "port":    40123
///   }
///   ```
///
/// L'hôte (`[startAdvertising]`) diffuse toutes les 2 s sur l'adresse
/// broadcast IPv4 255.255.255.255. Les invités (`[browse]`) écoutent le
/// port, dédupliquent par IP et exposent un flux de hôtes.
class LanDiscovery {
  LanDiscovery._();

  static const int _lanBeaconPort = 45678;
  static const String _appTag = 'endingletter';
  static const int _protocolVersion = 1;
  static const Duration _advertiseInterval = Duration(seconds: 2);

  /// Démarre la publicité UDP broadcast. Renvoie une fonction `stop()` qui
  /// arrête proprement le socket.
  ///
  /// [hostName] : nom affiché côté invité.
  /// [tcpPort]  : port TCP que les invités doivent contacter.
  static Future<Future<void> Function()> startAdvertising({
    required String hostName,
    required int tcpPort,
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0, // port OS-assigned pour l'envoi
        reuseAddress: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ bind UDP beacon failed: $e');
      return () async {};
    }

    final beacon = jsonEncode({
      'app': _appTag,
      'version': _protocolVersion,
      'name': hostName,
      'port': tcpPort,
    });
    final bytes = utf8.encode(beacon);
    if (bytes.length > 512) {
      socket.close();
      throw StateError('Beacon > 512 octets : ${bytes.length}');
    }

    final broadcastAddress = InternetAddress('255.255.255.255');
    final timer = Timer.periodic(_advertiseInterval, (_) {
      try {
        socket?.send(bytes, broadcastAddress, _lanBeaconPort);
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ broadcast send failed: $e');
      }
    });
    // Envoie immédiatement le premier beacon.
    try {
      socket.send(bytes, broadcastAddress, _lanBeaconPort);
    } catch (_) {}

    if (kDebugMode) {
      debugPrint('📡 Beacon Ending Letter diffusé sur :$_lanBeaconPort');
    }

    return () async {
      timer.cancel();
      socket?.close();
    };
  }

  /// Écoute le réseau pendant [duration] et retourne la liste des hôtes
  /// distincts (dédupliqués par IP). Les hôtes qui n'envoient pas le
  /// tag `app = endingletter` sont ignorés.
  static Future<List<LanHost>> browse({
    Duration duration = const Duration(seconds: 5),
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _lanBeaconPort,
        reuseAddress: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ bind UDP listen failed: $e');
      return const [];
    }

    final hosts = <String, LanHost>{};
    final completer = Completer<List<LanHost>>();
    late StreamSubscription<RawSocketEvent> sub;
    sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final s = socket;
      if (s == null) return;
      final datagram = s.receive();
      if (datagram == null) return;
      try {
        final json =
            jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
        if (json['app'] != _appTag) return;
        final ip = datagram.address.address;
        if (hosts.containsKey(ip)) return;
        hosts[ip] = LanHost.fromBeacon(json, ip);
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ beacon parse: $e');
      }
    });

    Timer(duration, () async {
      await sub.cancel();
      socket?.close();
      if (!completer.isCompleted) {
        completer.complete(hosts.values.toList());
      }
    });
    return completer.future;
  }

  /// Stream live : émet la liste découverte toutes les [interval]. À utiliser
  /// pour la liste interactive du lobby.
  static Stream<List<LanHost>> watchHosts({
    Duration interval = const Duration(seconds: 2),
  }) async* {
    while (true) {
      final hosts = await browse(duration: interval);
      yield hosts;
    }
  }

  /// Recherche l'adresse IP locale (utile pour afficher l'IP au host).
  static Future<String?> localIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      if (interfaces.isEmpty) return null;
      return interfaces.first.addresses.first.address;
    } catch (_) {
      return null;
    }
  }
}