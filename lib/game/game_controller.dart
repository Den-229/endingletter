import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../lan/lan_message.dart';
import '../services/dictionary_local_service.dart';
import '../services/dictionary_service.dart';
import 'game_mode.dart';
import 'played_word.dart';
import 'remote_transport.dart';

/// Phases de la partie.
enum GamePhase {
  idle,
  awaitingWord,
  finished,
}

/// Erreur lancée par [GameController] quand un coup est invalide.
class GameMoveException implements Exception {
  GameMoveException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Contrôleur de partie (ChangeNotifier).
///
/// Regroupe la logique de jeu (validation, rotation, historique) et la logique
/// de transport. Le même code est utilisé par les quatre modes :
///   - passAndPlay : applique localement, transport = LocalTransport (no-op).
///   - solo        : comme passAndPlay, mais le joueur 2 est une IA locale
///                   qui répond automatiquement après un délai.
///   - lanHost     : applique localement puis envoie un [StateMsg] au guest.
///   - lanGuest    : envoie un [MoveMsg] au host et attend son [StateMsg].
///
/// La validation de la chaîne et du dictionnaire est toujours faite par le
/// host (autoritaire). En pass-and-play et solo, c'est implicite.
class GameController extends ChangeNotifier {
  GameController({
    required this.mode,
    required this.player1Name,
    required this.player2Name,
    RemoteTransport? transport,
  })  : transport = transport ?? const LocalTransport(),
        sessionId = const Uuid().v4();

  final GameMode mode;
  final RemoteTransport transport;
  final String sessionId;

  final String player1Name;
  final String player2Name;

  /// Mon numéro de joueur (1 ou 2). En pass-and-play et lanHost = 1.
  late int _myPlayer;
  int get myPlayer => _myPlayer;

  int _currentPlayer = 1;
  String _requiredStartingLetter = '';
  GamePhase _phase = GamePhase.idle;
  String? _errorMessage;
  final List<PlayedWord> _history = [];
  StreamSubscription<LanMessage>? _transportSub;
  Timer? _aiTimer;
  final Random _rng = Random();

  /// Délai avant que l'IA joue son coup (mode solo).
  static const Duration _aiThinkDelay = Duration(milliseconds: 1500);

  /// Seed RNG injectable (tests). Si null, utilise un `Random()` standard.
  @visibleForTesting
  Random? debugRng;

  // ─── Getters ───

  int get currentPlayer => _currentPlayer;
  String get requiredStartingLetter => _requiredStartingLetter;
  GamePhase get phase => _phase;
  String? get errorMessage => _errorMessage;
  List<PlayedWord> get history => List.unmodifiable(_history);

  String currentPlayerName() => _currentPlayer == 1 ? player1Name : player2Name;

  bool get isMyTurn {
    if (mode == GameMode.passAndPlay || mode == GameMode.solo) return true;
    return _currentPlayer == _myPlayer;
  }

  /// Vrai si le joueur 2 est une IA (mode solo).
  bool get hasAi => mode == GameMode.solo;

  /// Score total (mots joués).
  int get score => _history.length;

  // ─── Initialisation ───

  /// Appelé après création pour démarrer le transport et calculer
  /// `_myPlayer` en fonction du mode.
  void start() {
    switch (mode) {
      case GameMode.passAndPlay:
      case GameMode.solo:
        _myPlayer = 1;
        _phase = GamePhase.awaitingWord;
        break;
      case GameMode.lanHost:
        _myPlayer = 1;
        _phase = GamePhase.awaitingWord;
        break;
      case GameMode.lanGuest:
        _myPlayer = 2;
        _phase = GamePhase.awaitingWord;
        break;
    }
    _transportSub = transport.inbound.listen(_onRemoteMessage);
    if (mode == GameMode.lanHost) {
      // Envoie l'état initial dès que le guest est connecté.
      transport.send(StateMsg(
        history: const [],
        currentPlayer: _currentPlayer,
        requiredLetter: _requiredStartingLetter,
        phase: 'awaiting',
      ));
    }
    notifyListeners();
  }

  // ─── API publique ───

  /// Soumet un mot. Comportement selon le mode :
  ///   - passAndPlay / solo : applique localement après validation.
  ///     En solo, le tour de l'IA est déclenché automatiquement.
  ///   - lanGuest    : envoie un [MoveMsg] et attend la réponse du host.
  ///   - lanHost     : normalement appelé après validation via [_applyAndBroadcast].
  Future<void> submitWord(String raw) async {
    _errorMessage = null;

    if (_phase == GamePhase.finished) return;

    final cleaned = raw.trim().toLowerCase();
    if (cleaned.isEmpty || !RegExp(r'^[a-z]+$').hasMatch(cleaned)) {
      _errorMessage = 'Caractères non autorisés';
      notifyListeners();
      return;
    }

    if (mode == GameMode.lanGuest) {
      // On envoie au host et on attend.
      transport.send(MoveMsg(word: cleaned, player: _myPlayer));
      return;
    }

    await _applyAndBroadcast(cleaned, _myPlayer);

    // En solo, le joueur 2 (IA) joue automatiquement après un délai.
    if (mode == GameMode.solo &&
        _phase != GamePhase.finished &&
        _currentPlayer == 2) {
      _scheduleAiTurn();
    }
  }

  /// Abandonne la partie. En LAN, envoie un [GiveUpMsg].
  void giveUp() {
    if (_phase == GamePhase.finished) return;
    _aiTimer?.cancel();
    _phase = GamePhase.finished;
    if (mode != GameMode.passAndPlay && mode != GameMode.solo) {
      transport.send(GiveUpMsg(player: _myPlayer));
    }
    notifyListeners();
  }

  /// Annule le dernier coup.
  ///   - pass-and-play et solo : local immédiat.
  ///   - lanHost : local + broadcast via [StateMsg] (le guest se resynchronise).
  ///   - lanGuest : désactivé (le host est autoritaire).
  void undoLast() {
    if (mode == GameMode.lanGuest) return;
    if (_history.isEmpty) return;
    _aiTimer?.cancel();
    final last = _history.removeLast();
    if (_history.isEmpty) {
      _requiredStartingLetter = '';
      _currentPlayer = 1;
    } else {
      final prev = _history.last;
      _requiredStartingLetter = prev.word[prev.word.length - 1];
      _currentPlayer = last.player == 1 ? 1 : 2;
    }
    if (mode == GameMode.lanHost) {
      // Le guest reçoit l'état corrigé.
      transport.send(StateMsg(
        history: List.unmodifiable(_history),
        currentPlayer: _currentPlayer,
        requiredLetter: _requiredStartingLetter,
        phase: 'awaiting',
      ));
    }
    notifyListeners();
  }

  /// Réinitialise la partie (utilisé par Rematch).
  void restart() {
    _aiTimer?.cancel();
    _history.clear();
    _requiredStartingLetter = '';
    _currentPlayer = 1;
    _phase = GamePhase.awaitingWord;
    _errorMessage = null;
    if (mode == GameMode.lanHost) {
      transport.send(StateMsg(
        history: const [],
        currentPlayer: 1,
        requiredLetter: '',
        phase: 'awaiting',
      ));
    }
    notifyListeners();
  }

  // ─── Validation (host-authoritative ou locale en pass-and-play) ───

  Future<void> _applyAndBroadcast(String word, int player) async {
    final validation = await _validate(word);
    if (validation != null) {
      _errorMessage = validation;
      notifyListeners();
      return;
    }

    _history.add(PlayedWord(
      word: word,
      player: player,
      playedAt: DateTime.now().toUtc(),
    ));
    _requiredStartingLetter = word[word.length - 1];
    _currentPlayer = player == 1 ? 2 : 1;

    if (mode == GameMode.lanHost) {
      transport.send(StateMsg(
        history: List.unmodifiable(_history),
        currentPlayer: _currentPlayer,
        requiredLetter: _requiredStartingLetter,
        phase: 'awaiting',
      ));
    }
    notifyListeners();
  }

  Future<String?> _validate(String word) async {
    if (_requiredStartingLetter.isNotEmpty &&
        !word.startsWith(_requiredStartingLetter)) {
      return 'Doit commencer par ${_requiredStartingLetter.toUpperCase()}';
    }
    if (_history.any((w) => w.word == word)) {
      return 'Mot déjà joué';
    }
    final ok = await DictionaryService.isValidEnglishWord(word);
    if (!ok) return 'Mot anglais inconnu';
    return null;
  }

  // ─── IA locale (mode solo) ───

  void _scheduleAiTurn() {
    _aiTimer?.cancel();
    _aiTimer = Timer(_aiThinkDelay, _aiTurn);
  }

  /// Choisit un mot au hasard pondéré par fréquence, qui commence par la
  /// lettre requise, puis le joue. Si aucun mot n'est trouvé, le joueur 1
  /// gagne.
  ///
  /// Stratégie : on préfère les mots **communs** (haute fréquence) pour
  /// réduire la lettre finale que l'adversaire doit placer (les mots
  /// courants ont souvent des finales peu jouables : s, e, y…).
  Future<void> _aiTurn() async {
    if (_phase == GamePhase.finished) return;
    if (_currentPlayer != 2) return;

    final letter = _requiredStartingLetter;
    final List<String> candidates;
    if (letter.isEmpty) {
      // Premier coup de l'IA : on prend n'importe quel mot fréquent.
      candidates = await DictionaryLocalService.instance
          .getWordsStartingWith('a', limit: 50);
      if (candidates.isEmpty) {
        _finish('IA bloquée : aucun mot disponible.');
        return;
      }
    } else {
      final all = await DictionaryLocalService.instance
          .getWordsStartingWith(letter, limit: 100);
      candidates = all
          .where((w) => !_history.any((p) => p.word == w))
          .toList();
      if (candidates.isEmpty) {
        _finish('IA bloquée : pas de mot pour la lettre '
            '« ${letter.toUpperCase()} ».');
        return;
      }
    }

    final pick = _pickWeighted(candidates);
    await _applyAndBroadcast(pick, 2);
  }

  /// Sélection pondérée : plus la fréquence est grande, plus le mot a de
  /// chances d'être choisi. (Le seed charge `frequency = 1.0` par défaut,
  /// donc on retombe sur un choix uniforme en l'absence d'une vraie
  /// distribution.)
  String _pickWeighted(List<String> candidates) {
    if (candidates.length == 1) return candidates.first;
    final weights = candidates
        .map((w) =>
            max(1e-9, DictionaryLocalService.instance.frequencyOf(w)))
        .toList();
    final total = weights.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      // Toutes les fréquences à 0 (cas du seed brut) → choix uniforme.
      return candidates[_rng.nextInt(candidates.length)];
    }
    final rng = debugRng ?? _rng;
    var r = rng.nextDouble() * total;
    for (var i = 0; i < candidates.length; i++) {
      r -= weights[i];
      if (r <= 0) return candidates[i];
    }
    return candidates.last;
  }

  void _finish(String reason) {
    _errorMessage = reason;
    _phase = GamePhase.finished;
    notifyListeners();
  }

  // ─── Traitement des messages distants (host ou guest) ───

  Future<void> _onRemoteMessage(LanMessage msg) async {
    switch (msg) {
      case HelloMsg():
        if (mode == GameMode.lanHost) {
          transport.setPeerName(msg.playerName);
          transport.send(WelcomeMsg(
            assignedPlayer: 2,
            sessionId: sessionId,
            hostName: player1Name,
          ));
        }

      case WelcomeMsg():
        if (mode == GameMode.lanGuest) {
          transport.setPeerName(msg.hostName);
          _myPlayer = msg.assignedPlayer;
        }

      case StateMsg():
        // Guest reçoit l'état autoritaire du host.
        if (mode == GameMode.lanGuest) {
          _history
            ..clear()
            ..addAll(msg.history);
          _currentPlayer = msg.currentPlayer;
          _requiredStartingLetter = msg.requiredLetter;
          _phase = switch (msg.phase) {
            'finished' => GamePhase.finished,
            'awaiting' => GamePhase.awaitingWord,
            _ => GamePhase.idle,
          };
          notifyListeners();
        }

      case MoveMsg():
        // Host reçoit un coup du guest : le valide et le diffuse.
        if (mode == GameMode.lanHost) {
          await _applyAndBroadcast(msg.word, msg.player);
        }

      case GiveUpMsg():
        _aiTimer?.cancel();
        _phase = GamePhase.finished;
        notifyListeners();

      case RematchMsg():
        restart();

      case ChatMsg _:
        // Pour plus tard — placeholder.

      case _:
        // Ping/Pong et Disconnect sont gérés dans LanSocket.
        break;
    }
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    _transportSub?.cancel();
    transport.close();
    super.dispose();
  }
}