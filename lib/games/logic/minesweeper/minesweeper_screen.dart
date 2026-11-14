import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';

class MineCell {
  bool isMine = false;
  bool isRevealed = false;
  bool isFlagged = false;
  int neighborMines = 0;
}

class MinesweeperScreen extends StatefulWidget {
  const MinesweeperScreen({super.key});

  @override
  State<MinesweeperScreen> createState() => _MinesweeperScreenState();
}

class _MinesweeperScreenState extends State<MinesweeperScreen> {
  static const int rows = 9;
  static const int cols = 9;
  static const int totalMines = 10;

  late List<List<MineCell>> _grid;
  bool _isGameOver = false;
  bool _isWon = false;
  bool _flagMode = false;
  int _flagsLeft = totalMines;
  Timer? _timer;
  int _seconds = 0;
  bool _timerStarted = false;
  final math.Random _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _timer?.cancel();
    _seconds = 0;
    _timerStarted = false;
    _grid = List.generate(rows, (_) => List.generate(cols, (_) => MineCell()));
    _isGameOver = false;
    _isWon = false;
    _flagsLeft = totalMines;

    // Placer les mines
    int placed = 0;
    while (placed < totalMines) {
      final r = _rnd.nextInt(rows);
      final c = _rnd.nextInt(cols);
      if (!_grid[r][c].isMine) {
        _grid[r][c].isMine = true;
        placed++;
      }
    }

    // Calculer le nombre de mines voisines
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!_grid[r][c].isMine) {
          int count = 0;
          for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
              final nr = r + dr;
              final nc = c + dc;
              if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && _grid[nr][nc].isMine) {
                count++;
              }
            }
          }
          _grid[r][c].neighborMines = count;
        }
      }
    }
  }

  void _onCellTap(int r, int c) {
    if (_isGameOver || _isWon) return;
    final cell = _grid[r][c];

    if (_flagMode) {
      // Poser ou enlever un drapeau
      if (!cell.isRevealed) {
        setState(() {
          cell.isFlagged = !cell.isFlagged;
          _flagsLeft += cell.isFlagged ? -1 : 1;
        });
        FeedbackService.triggerLight();
        _checkWin();
      }
      return;
    }

    if (cell.isFlagged || cell.isRevealed) return;

    if (!_timerStarted) {
      _timerStarted = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted && !_isGameOver && !_isWon) {
          setState(() => _seconds++);
        }
      });
    }

    if (cell.isMine) {
      // Détonation d'une mine !
      _timer?.cancel();
      setState(() {
        _isGameOver = true;
        for (var row in _grid) {
          for (var item in row) {
            if (item.isMine) item.isRevealed = true;
          }
        }
      });
      FeedbackService.triggerImpact();
      return;
    }

    // Révélation récursive si case vide (0)
    setState(() {
      _revealRecursively(r, c);
      FeedbackService.triggerLight();
      _checkWin();
    });
  }

  void _revealRecursively(int r, int c) {
    if (r < 0 || r >= rows || c < 0 || c >= cols) return;
    final cell = _grid[r][c];
    if (cell.isRevealed || cell.isFlagged || cell.isMine) return;

    cell.isRevealed = true;

    if (cell.neighborMines == 0) {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr != 0 || dc != 0) {
            _revealRecursively(r + dr, c + dc);
          }
        }
      }
    }
  }

  void _checkWin() {
    int unrevealedSafe = 0;
    for (var row in _grid) {
      for (var cell in row) {
        if (!cell.isMine && !cell.isRevealed) {
          unrevealedSafe++;
        }
      }
    }

    if (unrevealedSafe == 0) {
      setState(() => _isWon = true);
      FeedbackService.triggerSuccess();
    }
  }

  Color _getNumberColor(int n) {
    switch (n) {
      case 1: return const Color(0xFF00F0FF);
      case 2: return const Color(0xFF05FFA1);
      case 3: return const Color(0xFFFF2A6D);
      case 4: return const Color(0xFF7000FF);
      case 5: return const Color(0xFFFF9F1C);
      default: return const Color(0xFFFFD166);
    }
  }

  Widget _buildDigitalCounter(int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            value.clamp(0, 999).toString().padLeft(3, '0'),
            style: TextStyle(
              fontFamily: 'monospace',
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10172D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'DÉMINEUR RÉTRO',
          style: TextStyle(
            color: Color(0xFFFFD166),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => setState(_resetGame),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barre d'état authentique rétro (Compteur Mines, Smiley Central, Compteur Chrono)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF131D36),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDigitalCounter(_flagsLeft, Icons.flag, const Color(0xFFFF2A6D)),
                  
                  // Smiley central interactif
                  GestureDetector(
                    onTap: () => setState(_resetGame),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFE680), Color(0xFFFFB800)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFB800).withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _isWon ? '😎' : (_isGameOver ? '💥' : '🙂'),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),

                  _buildDigitalCounter(_seconds, Icons.timer, const Color(0xFF00FFCC)),
                ],
              ),
            ),

            // Mode Drapeau / Découvrir
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _flagMode = !_flagMode),
                    icon: Icon(_flagMode ? Icons.flag : Icons.touch_app, size: 16),
                    label: Text(_flagMode ? 'MODE DRAPEAU (ACTIF)' : 'MODE DÉCOUVERTE', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _flagMode ? const Color(0xFFFF2A6D) : const Color(0xFF00FFCC),
                      foregroundColor: Colors.black,
                      elevation: 6,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Grille 9x9 Démineur avec relief tactile
            Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD166).withValues(alpha: 0.3), width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16),
                  ],
                ),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Column(
                    children: List.generate(rows, (r) {
                      return Expanded(
                        child: Row(
                          children: List.generate(cols, (c) {
                            final cell = _grid[r][c];
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => _onCellTap(r, c),
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    gradient: cell.isRevealed
                                        ? (cell.isMine
                                            ? const RadialGradient(colors: [Color(0xFFFF0055), Color(0xFF990022)])
                                            : null)
                                        : const LinearGradient(
                                            colors: [Color(0xFF2E3D66), Color(0xFF1B2540)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    color: cell.isRevealed ? (cell.isMine ? null : const Color(0xFF090E1A)) : null,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: cell.isRevealed ? Colors.white10 : Colors.white24,
                                      width: cell.isRevealed ? 1 : 1.5,
                                    ),
                                    boxShadow: !cell.isRevealed
                                        ? [
                                            const BoxShadow(
                                              color: Colors.black38,
                                              offset: Offset(1, 2),
                                              blurRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: cell.isRevealed
                                        ? (cell.isMine
                                            ? const Text('💣', style: TextStyle(fontSize: 16))
                                            : (cell.neighborMines > 0
                                                ? Text(
                                                    '${cell.neighborMines}',
                                                    style: TextStyle(
                                                      color: _getNumberColor(cell.neighborMines),
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 16,
                                                    ),
                                                  )
                                                : null))
                                        : (cell.isFlagged
                                            ? const Icon(Icons.flag, color: Color(0xFFFF2A6D), size: 18)
                                            : null),
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

            const Spacer(),

            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                _flagMode ? 'Touchez une case pour poser/enlever un drapeau' : 'Touchez une case pour explorer le champ de mines',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

