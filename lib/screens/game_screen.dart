import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../game/game_mode.dart';
import '../game/played_word.dart';
import '../game/remote_transport.dart';
import '../lan/lan_socket.dart';
import '../shared/sound_service.dart';

/// Écran de jeu unifié : piloté par [GameController] pour tous les modes
/// (passAndPlay / solo / lanHost / lanGuest).
///
/// L'écran reçoit :
///   - [mode] : mode de jeu.
///   - [transport] : optionnel. Si fourni (LAN), utilisé par le contrôleur ;
///     sinon un [LocalTransport] no-op.
///   - [peerLabel] : libellé humain du peer (utilisé uniquement dans le titre).
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.mode,
    this.transport,
    this.peerLabel,
    this.player1Name = 'Joueur 1',
    this.player2Name = 'Joueur 2',
  });

  final GameMode mode;
  final RemoteTransport? transport;
  final String? peerLabel;
  final String player1Name;
  final String player2Name;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final TextEditingController _wordController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final GameController _controller;
  StreamSubscription<void>? _transportDoneSub;

  @override
  void initState() {
    super.initState();
    _controller = GameController(
      mode: widget.mode,
      transport: widget.transport,
      player1Name: widget.player1Name,
      player2Name: widget.mode == GameMode.solo
          ? 'IA'
          : (widget.peerLabel ?? widget.player2Name),
    )..start();
    _controller.addListener(_onControllerChanged);

    // Si le transport est un LanSocket, on surveille sa fermeture pour
    // terminer la partie proprement.
    final t = widget.transport;
    if (t is LanSocket) {
      _transportDoneSub = t.done.listen((_) {
        if (!mounted) return;
        // Marque la partie comme terminée si elle ne l'était pas déjà.
        if (_controller.phase != GamePhase.finished) {
          _controller.giveUp();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion LAN perdue. Partie terminée.'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  String? _lastErrorSignature;

  void _onControllerChanged() {
    // Joue les sons en fonction des transitions d'état.
    final err = _controller.errorMessage;
    if (err != null && err != _lastErrorSignature) {
      SoundService.instance.playError();
      _lastErrorSignature = err;
    } else if (err == null) {
      _lastErrorSignature = null;
    }

    // Fin de partie.
    if (_controller.phase == GamePhase.finished && _lastErrorSignature == null) {
      SoundService.instance.playWin();
    }
  }

  @override
  void dispose() {
    _transportDoneSub?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _wordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _wordController.text;
    if (raw.trim().isEmpty) return;
    SoundService.instance.playSubmit();
    await _controller.submitWord(raw);
    if (_controller.errorMessage == null) {
      _wordController.clear();
      _focusNode.requestFocus();
    }
  }

  void _giveUp() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandonner ?'),
        content: const Text(
            'La partie en cours se termine et le joueur adverse gagne.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CONTINUER'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _controller.giveUp();
            },
            child: const Text('ABANDONNER'),
          ),
        ],
      ),
    );
  }

  String get _title {
    switch (widget.mode) {
      case GameMode.passAndPlay:
        return 'Pass & Play';
      case GameMode.solo:
        return 'Solo contre IA';
      case GameMode.lanHost:
        return 'LAN — Hôte vs ${widget.peerLabel ?? "Invité"}';
      case GameMode.lanGuest:
        return 'LAN — ${widget.peerLabel ?? "Hôte"} vs Vous';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameController>.value(
      value: _controller,
      child: Consumer<GameController>(
        builder: (context, c, _) {
          final isFinished = c.phase == GamePhase.finished;
          if (isFinished && c.history.isNotEmpty) {
            // Affiche l'écran de fin après une micro-tâche pour laisser
            // l'animation de la lettre se terminer.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _showGameOverDialog(c);
            });
          }
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(_title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              centerTitle: true,
              actions: [
                if (c.mode != GameMode.lanGuest)
                  IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: 'Annuler le dernier coup',
                    onPressed: c.history.isEmpty ? null : c.undoLast,
                  ),
                IconButton(
                  icon: const Icon(Icons.flag),
                  tooltip: 'Abandonner',
                  onPressed: _giveUp,
                ),
              ],


            ),
            body: SafeArea(child: _buildBody(context, c)),
          );
        },
      ),
    );
  }

  void _showGameOverDialog(GameController c) {
    final winner = c.history.isEmpty
        ? null
        : (c.history.last.player == 1 ? c.player1Name : c.player2Name);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(winner != null ? '🏆 $winner a gagné !' : 'Partie terminée'),
        content: Text(
          winner != null
              ? '${c.history.length} mots joués.\n'
                  'Score : ${c.history.where((p) => p.player == 1).length}'
                  ' (P1) — '
                  '${c.history.where((p) => p.player == 2).length}'
                  ' (P2).'
              : (c.errorMessage ?? 'Fin de partie.'),
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // retour menu
            },
            child: const Text('MENU'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              c.restart();
            },
            child: const Text('REJOUER'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, GameController c) {
    final theme = Theme.of(context);
    final isP1 = c.currentPlayer == 1;
    final color = isP1 ? theme.colorScheme.primary : theme.colorScheme.secondary;
    final canEdit = c.isMyTurn && !c.hasAi;

    return Column(
      children: [
        // Joueur courant + score
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(c.hasAi && c.currentPlayer == 2
                  ? Icons.smart_toy
                  : Icons.person, color: color),
              const SizedBox(width: 8),
              Text(
                c.hasAi && c.currentPlayer == 2
                    ? 'Tour de l\'IA…'
                    : 'Tour de ${c.currentPlayerName()}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Score ${c.history.where((w) => w.player == c.currentPlayer).length}',
                style: TextStyle(
                  fontSize: 14,
                  color: color.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ).animate(key: ValueKey(c.currentPlayer)).scale(
              duration: 300.ms,
              curve: Curves.easeOutBack,
            ),

        const SizedBox(height: 12),

        // Lettre requise
        if (c.requiredStartingLetter.isNotEmpty)
          Column(
            children: [
              Text(
                'Commencez par la lettre :',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    c.requiredStartingLetter.toUpperCase(),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              )
                  .animate(key: ValueKey(c.requiredStartingLetter))
                  .scale(duration: 400.ms, curve: Curves.elasticOut),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              c.mode == GameMode.solo
                  ? 'Vous commencez — l\'IA répondra automatiquement.'
                  : 'Entrez n\'importe quel mot anglais pour commencer !',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.secondary,
              ),
            ).animate().fade(duration: 600.ms),
          ),

        const SizedBox(height: 16),

        // Saisie
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _wordController,
            focusNode: _focusNode,
            enabled: canEdit,
            autofocus: canEdit,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: canEdit ? 'Tapez un mot…' : 'En attente…',
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            ),
          ),
        ),

        if (c.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 24, right: 24),
            child: Text(
              c.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ).animate().shake(duration: 400.ms),
          ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton(
              onPressed: canEdit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'SOUMETTRE',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Historique
        if (c.history.isNotEmpty) ...[
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Historique (${c.history.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const Spacer(),
                Text(
                  'P1 ${c.history.where((p) => p.player == 1).length} • '
                  'P2 ${c.history.where((p) => p.player == 2).length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: c.history.length,
              itemBuilder: (_, i) => _HistoryTile(
                word: c.history[i],
                index: i,
                total: c.history.length,
              ),
            ),
          ),
        ] else
          const Spacer(),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.word,
    required this.index,
    required this.total,
  });

  final PlayedWord word;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isP1 = word.player == 1;
    final color = isP1 ? theme.colorScheme.primary : theme.colorScheme.secondary;
    final w = word.word;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${total - index}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 18,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(text: w.substring(0, w.length - 1)),
                  TextSpan(
                    text: w.substring(w.length - 1),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'P${word.player}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    ).animate().fade().slideX(begin: 0.2);
  }
}