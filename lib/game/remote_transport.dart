import '../lan/lan_message.dart';

/// Abstraction de transport utilisée par [GameController].
///
/// Trois implémentations :
///   - [LocalTransport] : no-op, utilisée en pass-and-play et solo.
///   - [LanSocket] : TCP length-prefixed JSON pour le mode LAN.
abstract class RemoteTransport {
  /// Flux entrant des messages distants.
  Stream<LanMessage> get inbound;

  /// Envoie un message. No-op si pas connecté.
  void send(LanMessage message);

  /// Ferme la connexion proprement.
  Future<void> close();

  /// Nom du peer distant (utilisé pour l'UI).
  String get peerName;

  /// Met à jour le nom du peer (appelé après réception du Hello/Welcome).
  /// No-op par défaut pour les transports locaux.
  void setPeerName(String name) {}
}

/// Transport factice utilisé en mode pass-and-play et solo.
/// Les méthodes sont des no-ops.
class LocalTransport implements RemoteTransport {
  const LocalTransport();

  @override
  Stream<LanMessage> get inbound => const Stream<LanMessage>.empty();

  @override
  void send(LanMessage message) {
    // intentionally empty
  }

  @override
  Future<void> close() async {}

  @override
  String get peerName => 'local';

  @override
  void setPeerName(String name) {
    // no-op : il n'y a pas de peer distant en mode local.
  }
}