import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../game/remote_transport.dart';
import 'lan_message.dart';

/// Transport TCP pour le mode LAN. Chaque frame est :
///   [4 bytes BE length][utf8 JSON][4 bytes BE length][utf8 JSON]...
///
/// Le length-prefix évite les pièges de newline-delimited JSON (caractères
/// spéciaux, reconnexion partielle, etc.).
///
/// Host : [LanSocket.bind] ouvre un ServerSocket sur 0.0.0.0:port puis accepte
/// la première connexion venue.
/// Guest : [LanSocket.connect] se connecte à host:port.
///
/// Cycle de vie : un ping toutes les 5 s, drop après 3 pong manqués.
class LanSocket implements RemoteTransport {
  LanSocket._({
    ServerSocket? server,
    Socket? socket,
    required String peerName,
    required this.isHost,
  })  : _server = server,
        _socket = socket,
        _peerName = peerName;

  /// Ouvre un server socket sur un port aléatoire, attend un guest, puis
  /// s'attache automatiquement.
  static Future<LanSocket> bind({required String hostName}) async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    if (kDebugMode) debugPrint('🔌 LanSocket host sur :${server.port}');
    final completer = Completer<LanSocket>();
    server.listen((socket) {
      server.close();
      if (!completer.isCompleted) {
        final s = LanSocket._(
          server: server,
          socket: socket,
          peerName: 'invité',
          isHost: true,
        );
        s.attach();
        completer.complete(s);
      }
    }, onError: (Object e) {
      if (!completer.isCompleted) completer.completeError(e);
    });
    return completer.future.timeout(const Duration(seconds: 60));
  }

  /// Port TCP écouté par le host (`bind`) ou connecté (guest).
  /// Renvoie `0` tant que le socket n'est pas prêt.
  int get port {
    final s = _server;
    if (s != null) return s.port;
    final sock = _socket;
    if (sock != null) return sock.port;
    return 0;
  }

  /// Se connecte à un hôte, s'attache, et envoie un Hello.
  static Future<LanSocket> connect({
    required String host,
    required int port,
    required String playerName,
  }) async {
    final socket = await Socket.connect(host, port,
        timeout: const Duration(seconds: 10));
    final sock = LanSocket._(
      socket: socket,
      peerName: 'hôte',
      isHost: false,
    );
    sock.attach();
    sock._send(HelloMsg(playerName: playerName));
    return sock;
  }

  final bool isHost;
  final ServerSocket? _server;
  final Socket? _socket;
  String _peerName;
  final StreamController<LanMessage> _inbound =
      StreamController<LanMessage>.broadcast();
  final StreamController<void> _done = StreamController<void>.broadcast();
  final List<int> _buffer = [];
  Timer? _heartbeatTimer;
  int _lastSentNonce = 0;
  int _expectedNonce = 0;
  int _missedPongs = 0;
  bool _closed = false;

  @override
  String get peerName => _peerName;

  @override
  Stream<LanMessage> get inbound => _inbound.stream;

  /// Émet `null` quand la socket se ferme (perte peer, timeout, erreur).
  Stream<void> get done => _done.stream;

  /// Abonne la socket aux events data/error/done et démarre le heartbeat.
  void attach() {
    final socket = _socket;
    if (socket == null) return;
    socket.listen(_onData, onError: _onError, onDone: _onDone);
    _startHeartbeat();
  }

  @override
  void setPeerName(String name) {
    _peerName = name;
  }

  @override
  void send(LanMessage message) => _send(message);

  void _send(LanMessage message) {
    final socket = _socket;
    if (socket == null || _closed) return;
    try {
      final json = jsonEncode(message.toJson());
      final bytes = utf8.encode(json);
      final lengthBytes = ByteData(4)..setUint32(0, bytes.length);
      final frame = BytesBuilder()
        ..add(lengthBytes.buffer.asUint8List())
        ..add(bytes);
      socket.add(frame.toBytes());
      if (kDebugMode) debugPrint('📤 ${message.type} →');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ send error: $e');
    }
  }

  void _onData(Uint8List chunk) {
    _buffer.addAll(chunk);
    while (_buffer.length >= 4) {
      final length = (_buffer[0] << 24) |
          (_buffer[1] << 16) |
          (_buffer[2] << 8) |
          _buffer[3];
      if (length <= 0 || length > 256 * 1024) {
        if (kDebugMode) debugPrint('⚠️ Longueur invalide : $length');
        _close();
        return;
      }
      if (_buffer.length < 4 + length) return; // attendre
      final payload = _buffer.sublist(4, 4 + length);
      _buffer.removeRange(0, 4 + length);
      try {
        final json = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
        final msg = LanMessage.fromJson(json);
        _handleHeartbeat(msg);
        _inbound.add(msg);
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ parse error: $e');
      }
    }
  }

  void _onError(Object e) {
    if (kDebugMode) debugPrint('⚠️ LanSocket error: $e');
    _close();
  }

  void _onDone() {
    if (kDebugMode) debugPrint('🛑 LanSocket peer déconnecté');
    _close();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_closed) return;
      // On incrémente le nonce et on note celui qu'on attend en Pong.
      _lastSentNonce = (_lastSentNonce + 1) & 0x3FFFFFFF;
      _expectedNonce = _lastSentNonce;
      _send(PingMsg(
        nonce: _lastSentNonce,
        t: DateTime.now().millisecondsSinceEpoch,
      ));
      _missedPongs++;
      if (_missedPongs >= 3) {
        if (kDebugMode) debugPrint('🛑 3 pings sans pong → timeout');
        _close();
      }
    });
  }

  void _handleHeartbeat(LanMessage msg) {
    switch (msg) {
      case PingMsg(:final nonce):
        _send(PongMsg(
          nonce: nonce,
          t: DateTime.now().millisecondsSinceEpoch,
        ));
      case PongMsg(:final nonce):
        if (nonce == _expectedNonce) {
          _missedPongs = 0;
        }
      case _:
    }
  }

  @override
  Future<void> close() async => _close();

  void _close() {
    if (_closed) return;
    _closed = true;
    _heartbeatTimer?.cancel();
    try {
      _socket?.destroy();
    } catch (_) {}
    try {
      _server?.close();
    } catch (_) {}
    _inbound.close();
    if (!_done.isClosed) _done.add(null);
    _done.close();
  }
}