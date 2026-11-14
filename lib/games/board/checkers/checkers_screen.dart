import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';

enum CheckersColor { red, white }

class CheckersPiece {
  final CheckersColor color;
  bool isKing;

  CheckersPiece({required this.color, this.isKing = false});
}

class CheckersMove {
  final int fromR;
  final int fromC;
  final int toR;
  final int toC;
  final int? jumpR;
  final int? jumpC;

  CheckersMove(this.fromR, this.fromC, this.toR, this.toC, {this.jumpR, this.jumpC});
}

class CheckersScreen extends StatefulWidget {
  const CheckersScreen({super.key});

  @override
  State<CheckersScreen> createState() => _CheckersScreenState();
}

class _CheckersScreenState extends State<CheckersScreen> {
  late List<List<CheckersPiece?>> _board;
  CheckersColor _turn = CheckersColor.red;
  int? _selR;
  int? _selC;
  List<CheckersMove> _validMoves = [];
  bool _vsAi = true;
  bool _aiThinking = false;
  int _scoreRed = 0;
  int _scoreWhite = 0;

  @override
  void initState() {
    super.initState();
    _resetBoard();
  }

  void _resetBoard() {
    _board = List.generate(8, (_) => List<CheckersPiece?>.filled(8, null));
    // Placer les pièces blanches en haut (rangées 0, 1, 2)
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 8; c++) {
        if ((r + c) % 2 != 0) {
          _board[r][c] = CheckersPiece(color: CheckersColor.white);
        }
      }
    }
    // Placer les pièces rouges en bas (rangées 5, 6, 7)
    for (int r = 5; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if ((r + c) % 2 != 0) {
          _board[r][c] = CheckersPiece(color: CheckersColor.red);
        }
      }
    }
    _turn = CheckersColor.red;
    _selR = null;
    _selC = null;
    _validMoves = [];
    _scoreRed = 0;
    _scoreWhite = 0;
  }

  bool _isInside(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  List<CheckersMove> _getMovesForPiece(int r, int c) {
    final p = _board[r][c];
    if (p == null) return [];

    List<CheckersMove> moves = [];
    final forwardDir = p.color == CheckersColor.red ? -1 : 1;
    final directions = p.isKing ? [-1, 1] : [forwardDir];

    for (final dr in directions) {
      for (final dc in [-1, 1]) {
        final nr = r + dr;
        final nc = c + dc;
        if (_isInside(nr, nc)) {
          // Déplacement simple
          if (_board[nr][nc] == null) {
            moves.add(CheckersMove(r, c, nr, nc));
          } else if (_board[nr][nc]!.color != p.color) {
            // Tentative de saut / prise
            final jumpR = nr + dr;
            final jumpC = nc + dc;
            if (_isInside(jumpR, jumpC) && _board[jumpR][jumpC] == null) {
              moves.add(CheckersMove(r, c, jumpR, jumpC, jumpR: nr, jumpC: nc));
            }
          }
        }
      }
    }

    return moves;
  }

  void _onSquareTap(int r, int c) {
    if (_aiThinking) return;

    if (_selR != null && _selC != null) {
      final move = _validMoves.firstWhere(
        (m) => m.toR == r && m.toC == c,
        orElse: () => CheckersMove(-1, -1, -1, -1),
      );

      if (move.fromR != -1) {
        _applyMove(move);
        return;
      }
    }

    final p = _board[r][c];
    if (p != null && p.color == _turn) {
      setState(() {
        _selR = r;
        _selC = c;
        _validMoves = _getMovesForPiece(r, c);
      });
      FeedbackService.triggerLight();
    } else {
      setState(() {
        _selR = null;
        _selC = null;
        _validMoves = [];
      });
    }
  }

  void _applyMove(CheckersMove m) {
    final p = _board[m.fromR][m.fromC];
    if (p == null) return;

    setState(() {
      _board[m.toR][m.toC] = p;
      _board[m.fromR][m.fromC] = null;

      // Prise
      if (m.jumpR != null && m.jumpC != null) {
        _board[m.jumpR!][m.jumpC!] = null;
        if (p.color == CheckersColor.red) {
          _scoreRed++;
        } else {
          _scoreWhite++;
        }
        FeedbackService.triggerImpact();
      }

      // Couronnement Dame
      if ((p.color == CheckersColor.red && m.toR == 0) ||
          (p.color == CheckersColor.white && m.toR == 7)) {
        p.isKing = true;
        FeedbackService.triggerSuccess();
      }

      _selR = null;
      _selC = null;
      _validMoves = [];
      _turn = _turn == CheckersColor.red ? CheckersColor.white : CheckersColor.red;
    });

    if (_vsAi && _turn == CheckersColor.white) {
      _triggerAi();
    }
  }

  void _triggerAi() {
    setState(() => _aiThinking = true);
    Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      List<CheckersMove> allMoves = [];
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          if (_board[r][c]?.color == CheckersColor.white) {
            allMoves.addAll(_getMovesForPiece(r, c));
          }
        }
      }

      if (allMoves.isNotEmpty) {
        // Priorité aux sauts/prises
        final captures = allMoves.where((m) => m.jumpR != null).toList();
        final selected = captures.isNotEmpty
            ? captures[math.Random().nextInt(captures.length)]
            : allMoves[math.Random().nextInt(allMoves.length)];

        _applyMove(selected);
      }
      setState(() => _aiThinking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F141F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161E2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'JEU DE DAMES CLASSIC',
          style: TextStyle(
            color: Color(0xFFFF007F),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => setState(_resetBoard),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Bandeau de score & Mode
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF161E2E),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('vs IA', style: TextStyle(fontSize: 12)),
                        selected: _vsAi,
                        selectedColor: const Color(0xFFFF007F),
                        onSelected: (val) => setState(() => _vsAi = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('2 Joueurs', style: TextStyle(fontSize: 12)),
                        selected: !_vsAi,
                        selectedColor: const Color(0xFFFF007F),
                        onSelected: (val) => setState(() => _vsAi = false),
                      ),
                    ],
                  ),
                  Text(
                    'Rouge: $_scoreRed | Blanc: $_scoreWhite',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Plateau de dames
            Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFF007F).withValues(alpha: 0.6), width: 3),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF007F).withValues(alpha: 0.2),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Column(
                      children: List.generate(8, (r) {
                        return Expanded(
                          child: Row(
                            children: List.generate(8, (c) {
                              final isDark = (r + c) % 2 != 0;
                              final isSelected = _selR == r && _selC == c;
                              final isTarget = _validMoves.any((m) => m.toR == r && m.toC == c);
                              final p = _board[r][c];

                              Color bg = isDark ? const Color(0xFF1E2837) : const Color(0xFFE2E8F0);
                              if (isSelected) bg = const Color(0xFFFF007F).withValues(alpha: 0.5);

                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => _onSquareTap(r, c),
                                  child: Container(
                                    color: bg,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (p != null)
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: p.color == CheckersColor.red
                                                  ? const Color(0xFFFF0055)
                                                  : Colors.white,
                                              border: Border.all(
                                                color: Colors.black38,
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: p.color == CheckersColor.red
                                                      ? Colors.red.withValues(alpha: 0.4)
                                                      : Colors.white.withValues(alpha: 0.4),
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                            child: p.isKing
                                                ? const Center(
                                                    child: Icon(Icons.star, color: Colors.amber, size: 20),
                                                  )
                                                : null,
                                          ),
                                        if (isTarget)
                                          Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: const Color(0xFF00FFCC).withValues(alpha: 0.8),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Tour en cours
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                _turn == CheckersColor.red
                    ? 'Tour : Pions Rouges'
                    : (_vsAi ? 'L\'IA réfléchit...' : 'Tour : Pions Blancs'),
                style: TextStyle(
                  color: _turn == CheckersColor.red ? const Color(0xFFFF0055) : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

