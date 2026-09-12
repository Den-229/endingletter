import '../game/played_word.dart';

/// Erreur lancée par [LanMessage.fromJson] quand le `type` est inconnu.
class LanProtocolException implements Exception {
  LanProtocolException(this.message);
  final String message;
  @override
  String toString() => 'LanProtocolException: $message';
}

/// Hiérarchie de messages échangés sur le LAN. Sérialisation JSON newline-
/// delimited (chaque frame est un objet complet terminé par `\n`).
///
/// Convention : toutes les frames portent `v: 1` (protocolVersion) et un
/// `type` discriminant. Le host est autoritaire : il valide les coups et
/// renvoie un `State` complet à chaque acceptation.
sealed class LanMessage {
  const LanMessage();

  /// Version du protocole (incrémentée à chaque breaking change).
  static const int protocolVersion = 1;

  String get type;

  Map<String, dynamic> toJson();

  String get peerName;

  static LanMessage fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == null) {
      throw LanProtocolException('Champ "type" manquant.');
    }
    return switch (type) {
      'hello' => HelloMsg(
          playerName: json['playerName'] as String? ?? 'Joueur',
          resume: json['resume'] as bool? ?? false,
          sessionId: json['sessionId'] as String?,
        ),
      'welcome' => WelcomeMsg(
          assignedPlayer: (json['assignedPlayer'] as num?)?.toInt() ?? 2,
          sessionId: json['sessionId'] as String? ?? '',
          hostName: json['hostName'] as String? ?? 'Hôte',
        ),
      'state' => StateMsg(
          history: (json['history'] as List? ?? const [])
              .map((e) => PlayedWord.fromJson(e as Map<String, dynamic>))
              .toList(growable: false),
          currentPlayer: (json['currentPlayer'] as num?)?.toInt() ?? 1,
          requiredLetter: json['requiredLetter'] as String? ?? '',
          phase: json['phase'] as String? ?? 'idle',
        ),
      'move' => MoveMsg(
          word: json['word'] as String? ?? '',
          player: (json['player'] as num?)?.toInt() ?? 0,
        ),
      'moveAccepted' => MoveAcceptedMsg(
          word: json['word'] as String? ?? '',
          requiredLetterNext: json['requiredLetterNext'] as String? ?? '',
        ),
      'moveRejected' => MoveRejectedMsg(
          reason: json['reason'] as String? ?? 'unknown',
        ),
      'chat' => ChatMsg(
          from: json['from'] as String? ?? '?',
          text: json['text'] as String? ?? '',
        ),
      'giveUp' => GiveUpMsg(
          player: (json['player'] as num?)?.toInt() ?? 0,
        ),
      'rematch' => const RematchMsg(),
      'ping' => PingMsg(
          nonce: (json['nonce'] as num?)?.toInt() ?? 0,
          t: (json['t'] as num?)?.toInt() ?? 0,
        ),
      'pong' => PongMsg(
          nonce: (json['nonce'] as num?)?.toInt() ?? 0,
          t: (json['t'] as num?)?.toInt() ?? 0,
        ),
      'disconnect' => DisconnectMsg(
          reason: json['reason'] as String? ?? 'unknown',
        ),
      _ => throw LanProtocolException('Type de message inconnu : $type'),
    };
  }
}

class HelloMsg extends LanMessage {
  const HelloMsg({
    required this.playerName,
    this.resume = false,
    this.sessionId,
  });

  final String playerName;
  final bool resume;
  final String? sessionId;

  @override
  String get type => 'hello';

  @override
  String get peerName => playerName;

  @override
  Map<String, dynamic> toJson() => {
        'v': LanMessage.protocolVersion,
        'type': type,
        'playerName': playerName,
        'resume': resume,
        if (sessionId != null) 'sessionId': sessionId,
      };
}

class WelcomeMsg extends LanMessage {
  const WelcomeMsg({
    required this.assignedPlayer,
    required this.sessionId,
    required this.hostName,
  });

  final int assignedPlayer;
  final String sessionId;
  final String hostName;

  @override
  String get type => 'welcome';

  @override
  String get peerName => hostName;

  @override
  Map<String, dynamic> toJson() => {
        'v': LanMessage.protocolVersion,
        'type': type,
        'assignedPlayer': assignedPlayer,
        'sessionId': sessionId,
        'hostName': hostName,
      };
}

/// État complet envoyé par le host après chaque coup validé.
/// L'invité ne fait que lire ce message et appliquer localement.
class StateMsg extends LanMessage {
  const StateMsg({
    required this.history,
    required this.currentPlayer,
    required this.requiredLetter,
    required this.phase,
  });

  final List<PlayedWord> history;
  final int currentPlayer;
  final String requiredLetter;
  final String phase;

  @override
  String get type => 'state';

  @override
  String get peerName => 'host';

  @override
  Map<String, dynamic> toJson() => {
        'v': LanMessage.protocolVersion,
        'type': type,
        'history': history.map((w) => w.toJson()).toList(),
        'currentPlayer': currentPlayer,
        'requiredLetter': requiredLetter,
        'phase': phase,
      };
}

class MoveMsg extends LanMessage {
  const MoveMsg({
    required this.word,
    required this.player,
  });

  final String word;
  final int player;

  @override
  String get type => 'move';

  @override
  String get peerName => 'guest';

  @override
  Map<String, dynamic> toJson() => {
        'v': LanMessage.protocolVersion,
        'type': type,
        'word': word,
        'player': player,
      };
}

class MoveAcceptedMsg extends LanMessage {
  const MoveAcceptedMsg({
    required this.word,
    required this.requiredLetterNext,
  });

  final String word;
  final String requiredLetterNext;

  @override
  String get type => 'moveAccepted';

  @override
  String get peerName => 'host';

  @override
  Map<String, dynamic> toJson() => {
        'v': LanMessage.protocolVersion,
        'type': type,
        'word': word,
        'requiredLetterNext': requiredLetterNext,
      };
}

class MoveRejectedMsg extends LanMessage {
  const MoveRejectedMsg({required this.reason});
  final String reason;

  @override
  String get type => 'moveRejected';

  @override
  String get peerName => 'host';

  @override
  Map<String, dynamic> toJson() => {
        'v': LanMessage.protocolVersion,
        'type': type,
        'reason': reason,
      };
}

class ChatMsg extends LanMessage {
  const ChatMsg({required this.from, required this.text});
  final String from;
  final String text;

  @override
  String get type => 'chat';

  @override
  String get peerName => from;

  @override
  Map<String, dynamic> toJson() => {
        'v': LanMessage.protocolVersion,
        'type': type,
        'from': from,
        'text': text,
      };
}

class GiveUpMsg extends LanMessage {
  const GiveUpMsg({required this.player});
  final int player;

  @override
  String get type => 'giveUp';

  @override
  String get peerName => 'peer';

  @override
  Map<String, dynamic> toJson() => {
        'v': LanMessage.protocolVersion,
        'type': type,
        'player': player,
      };
}

class RematchMsg extends LanMessage {
  const RematchMsg();

  @override
  String get type => 'rematch';

  @override
  String get peerName => 'peer';

  @override
  Map<String, dynamic> toJson() => {
        'v': LanMessage.protocolVersion,
        'type': type,
      };
}

class PingMsg extends LanMessage {
  const PingMsg({required this.nonce, required this.t});
  final int nonce;
  final int t;

  @override
  String get type => 'ping';

  @override
  String get peerName => 'peer';

  @override
  Map<String, dynamic> toJson() => {
        'v': LanMessage.protocolVersion,
        'type': type,
        'nonce': nonce,
        't': t,
      };
}

class PongMsg extends LanMessage {
  const PongMsg({required this.nonce, required this.t});
  final int nonce;
  final int t;

  @override
  String get type => 'pong';

  @override
  String get peerName => 'peer';

  @override
  Map<String, dynamic> toJson() => {
        'v': LanMessage.protocolVersion,
        'type': type,
        'nonce': nonce,
        't': t,
      };
}

class DisconnectMsg extends LanMessage {
  const DisconnectMsg({required this.reason});
  final String reason;

  @override
  String get type => 'disconnect';

  @override
  String get peerName => 'peer';

  @override
  Map<String, dynamic> toJson() => {
        'v': LanMessage.protocolVersion,
        'type': type,
        'reason': reason,
      };
}