import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';
import 'chess_engine.dart';

class ChessScreen extends StatefulWidget {
  const ChessScreen({super.key});

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  final ChessGame _game = ChessGame();
  int? _selectedRow;
  int? _selectedCol;
  List<ChessMove> _currentLegalMoves = [];
  bool _playAgainstAi = true;
  bool _isAiThinking = false;
  ChessMove? _lastMove;

  // Pendule d'échecs (Par défaut 10 minutes par joueur)
  bool _clockEnabled = true;
  int _whiteTimeSeconds = 600;
  int _blackTimeSeconds = 600;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _startClock();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _clockTimer?.cancel();
    if (!_clockEnabled) return;

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_game.currentTurn == PieceColor.white) {
          if (_whiteTimeSeconds > 0) _whiteTimeSeconds--;
        } else {
          if (_blackTimeSeconds > 0) _blackTimeSeconds--;
        }
      });
    });
  }

  void _resetGame() {
    setState(() {
      _game.reset();
      _selectedRow = null;
      _selectedCol = null;
      _currentLegalMoves = [];
      _lastMove = null;
      _isAiThinking = false;
      _whiteTimeSeconds = 600;
      _blackTimeSeconds = 600;
    });
    _startClock();
  }

  void _undoMove() {
    if (!_game.canUndo || _isAiThinking) return;
    FeedbackService.triggerLight();
    setState(() {
      _game.undoLastMove();
      if (_playAgainstAi && _game.canUndo && _game.currentTurn == PieceColor.black) {
        _game.undoLastMove();
      }
      _selectedRow = null;
      _selectedCol = null;
      _currentLegalMoves = [];
      _lastMove = null;
    });
  }

  void _onSquareTapped(int r, int c) {
    if (_isAiThinking) return;

    final piece = _game.board[r][c];

    // Si on a déjà sélectionné une pièce
    if (_selectedRow != null && _selectedCol != null) {
      final move = _currentLegalMoves.firstWhere(
        (m) => m.toRow == r && m.toCol == c,
        orElse: () => ChessMove(-1, -1, -1, -1),
      );

      if (move.fromRow != -1) {
        // Coup valide !
        setState(() {
          _lastMove = move;
          _game.makeMove(move);
          _selectedRow = null;
          _selectedCol = null;
          _currentLegalMoves = [];
        });
        FeedbackService.triggerImpact();

        // Réponse de l'IA si mode IA
        if (_playAgainstAi && _game.currentTurn == PieceColor.black) {
          _triggerAiMove();
        }
        return;
      }
    }

    // Sélection d'une nouvelle pièce
    if (piece != null && piece.color == _game.currentTurn) {
      setState(() {
        _selectedRow = r;
        _selectedCol = c;
        _currentLegalMoves = _game.getLegalMoves(r, c);
      });
      FeedbackService.triggerLight();
    } else {
      setState(() {
        _selectedRow = null;
        _selectedCol = null;
        _currentLegalMoves = [];
      });
    }
  }

  void _triggerAiMove() {
    setState(() => _isAiThinking = true);
    Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      final aiMove = _game.computeBestAiMove(PieceColor.black);
      if (aiMove != null) {
        setState(() {
          _lastMove = aiMove;
          _game.makeMove(aiMove);
          _isAiThinking = false;
        });
        FeedbackService.triggerImpact();
      } else {
        setState(() => _isAiThinking = false);
      }
    });
  }

  String _formatClock(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final diff = _game.materialAdvantage;

    return Scaffold(
      backgroundColor: const Color(0xFF090D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10172D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield, color: Color(0xFF00FFCC), size: 20),
            SizedBox(width: 8),
            Text(
              'ÉCHECS MASTER',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.timer_outlined, color: _clockEnabled ? const Color(0xFF00FFCC) : Colors.white38),
            tooltip: 'Activer/Désactiver la pendule',
            onPressed: () {
              setState(() => _clockEnabled = !_clockEnabled);
              _startClock();
            },
          ),
          IconButton(
            icon: Icon(Icons.undo, color: _game.canUndo ? Colors.white : Colors.white24),
            tooltip: 'Annuler le coup',
            onPressed: _game.canUndo ? _undoMove : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Nouvelle partie',
            onPressed: _resetGame,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Bandeau d'options Mode de jeu et Pendules
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF10172D),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('vs IA Bot', style: TextStyle(fontSize: 12)),
                          selected: _playAgainstAi,
                          selectedColor: const Color(0xFF00FFCC),
                          labelStyle: TextStyle(
                            color: _playAgainstAi ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) => setState(() => _playAgainstAi = true),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('2 Joueurs', style: TextStyle(fontSize: 12)),
                          selected: !_playAgainstAi,
                          selectedColor: const Color(0xFF00FFCC),
                          labelStyle: TextStyle(
                            color: !_playAgainstAi ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) => setState(() => _playAgainstAi = false),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Pendules Noirs et Blancs
                    if (_clockEnabled)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _game.currentTurn == PieceColor.white ? const Color(0xFF00FFCC).withValues(alpha: 0.2) : Colors.black38,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _game.currentTurn == PieceColor.white ? const Color(0xFF00FFCC) : Colors.white24),
                            ),
                            child: Text(
                              '⚪ ${_formatClock(_whiteTimeSeconds)}',
                              style: TextStyle(
                                color: _game.currentTurn == PieceColor.white ? const Color(0xFF00FFCC) : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _game.currentTurn == PieceColor.black ? const Color(0xFFFF0055).withValues(alpha: 0.2) : Colors.black38,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _game.currentTurn == PieceColor.black ? const Color(0xFFFF0055) : Colors.white24),
                            ),
                            child: Text(
                              '⚫ ${_formatClock(_blackTimeSeconds)}',
                              style: TextStyle(
                                color: _game.currentTurn == PieceColor.black ? const Color(0xFFFF0055) : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Pièces capturées par les Blancs & Avantage matériel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Text('Noirs capturés : ', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _game.capturedByWhite.map((p) => Text(p.symbol, style: const TextStyle(fontSize: 16, color: Colors.white70))).toList(),
                      ),
                    ),
                  ),
                  if (diff > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF00FFCC), borderRadius: BorderRadius.circular(4)),
                      child: Text('+$diff', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                ],
              ),
            ),

            // Historique des coups en direct
            if (_game.moveHistory.isNotEmpty)
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  itemCount: _game.moveHistory.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final moveText = _game.moveHistory[_game.moveHistory.length - 1 - idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16203D),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12),
                      ),
                      alignment: Alignment.center,
                      child: Text(moveText, style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 11, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),

            const Spacer(),

            // Échiquier 8x8 avec coordonnées A-H et 1-8
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2838),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.6), width: 3),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF00FFCC).withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Coordonnées supérieures (A-H)
                    Row(
                      children: [
                        const SizedBox(width: 18),
                        ...List.generate(8, (i) => Expanded(
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + i),
                              style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )),
                        const SizedBox(width: 18),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Lignes avec chiffres 1-8 à gauche et droite
                    ...List.generate(8, (r) {
                      return Row(
                        children: [
                          SizedBox(
                            width: 18,
                            child: Text(
                              '${8 - r}',
                              style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...List.generate(8, (c) {
                            final piece = _game.board[r][c];
                            final isLightSquare = (r + c) % 2 == 0;
                            final isSelected = _selectedRow == r && _selectedCol == c;
                            final isLegalTarget = _currentLegalMoves.any((m) => m.toRow == r && m.toCol == c);
                            final isLastMoveSource = _lastMove != null && _lastMove!.fromRow == r && _lastMove!.fromCol == c;
                            final isLastMoveDest = _lastMove != null && _lastMove!.toRow == r && _lastMove!.toCol == c;

                            Color squareColor = isLightSquare ? const Color(0xFFE8EDF9) : const Color(0xFF4B6584);
                            if (isLastMoveSource || isLastMoveDest) {
                              squareColor = const Color(0xFFF7B731).withValues(alpha: 0.6);
                            }
                            if (isSelected) {
                              squareColor = const Color(0xFF00FFCC).withValues(alpha: 0.7);
                            }

                            return Expanded(
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: GestureDetector(
                                  onTap: () => _onSquareTapped(r, c),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: squareColor,
                                      border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Puce de déplacement légal
                                        if (isLegalTarget)
                                          Container(
                                            width: piece == null ? 12 : null,
                                            height: piece == null ? 12 : null,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: piece == null ? const Color(0xFF2ED573).withValues(alpha: 0.8) : null,
                                              border: piece != null ? Border.all(color: const Color(0xFFFF4757), width: 3) : null,
                                            ),
                                          ),

                                        // Pièce
                                        if (piece != null)
                                          Text(
                                            piece.symbol,
                                            style: TextStyle(
                                              fontSize: 30,
                                              color: piece.color == PieceColor.white ? const Color(0xFFFFFFFF) : const Color(0xFF1E272E),
                                              shadows: const [
                                                Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 2)),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          SizedBox(
                            width: 18,
                            child: Text(
                              '${8 - r}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      );
                    }),

                    const SizedBox(height: 4),

                    // Coordonnées inférieures (A-H)
                    Row(
                      children: [
                        const SizedBox(width: 18),
                        ...List.generate(8, (i) => Expanded(
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + i),
                              style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )),
                        const SizedBox(width: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Pièces capturées par les Noirs & Avantage
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Text('Blancs capturés : ', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _game.capturedByBlack.map((p) => Text(p.symbol, style: const TextStyle(fontSize: 16, color: Colors.white70))).toList(),
                      ),
                    ),
                  ),
                  if (diff < 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFF4757), borderRadius: BorderRadius.circular(4)),
                      child: Text('+${diff.abs()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
