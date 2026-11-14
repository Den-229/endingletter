import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/storage_service.dart';

class Game2048Screen extends StatefulWidget {
  const Game2048Screen({super.key});

  @override
  State<Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends State<Game2048Screen> {
  static const int size = 4;
  late List<List<int>> _grid;
  int _score = 0;
  int _bestScore = 0;
  bool _gameOver = false;
  final math.Random _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    _grid = List.generate(size, (_) => List.filled(size, 0));
    _score = 0;
    _gameOver = false;
    _spawnTile();
    _spawnTile();
  }

  void _spawnTile() {
    List<math.Point<int>> emptyCells = [];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_grid[r][c] == 0) emptyCells.add(math.Point(r, c));
      }
    }

    if (emptyCells.isNotEmpty) {
      final cell = emptyCells[_rnd.nextInt(emptyCells.length)];
      _grid[cell.x][cell.y] = _rnd.nextDouble() < 0.9 ? 2 : 4;
    }
  }

  void _swipe(AxisDirection dir) {
    if (_gameOver) return;

    bool moved = false;
    int earnedScore = 0;

    List<int> slideAndMerge(List<int> line) {
      List<int> nonZero = line.where((v) => v != 0).toList();
      List<int> res = [];
      int i = 0;
      while (i < nonZero.length) {
        if (i + 1 < nonZero.length && nonZero[i] == nonZero[i + 1]) {
          final mergedVal = nonZero[i] * 2;
          res.add(mergedVal);
          earnedScore += mergedVal;
          i += 2;
        } else {
          res.add(nonZero[i]);
          i++;
        }
      }
      while (res.length < size) {
        res.add(0);
      }
      return res;
    }

    setState(() {
      for (int idx = 0; idx < size; idx++) {
        List<int> line = [];
        for (int j = 0; j < size; j++) {
          switch (dir) {
            case AxisDirection.left:
              line.add(_grid[idx][j]);
              break;
            case AxisDirection.right:
              line.add(_grid[idx][size - 1 - j]);
              break;
            case AxisDirection.up:
              line.add(_grid[j][idx]);
              break;
            case AxisDirection.down:
              line.add(_grid[size - 1 - j][idx]);
              break;
          }
        }

        final merged = slideAndMerge(line);

        for (int j = 0; j < size; j++) {
          int originalVal = 0;
          switch (dir) {
            case AxisDirection.left:
              originalVal = _grid[idx][j];
              _grid[idx][j] = merged[j];
              break;
            case AxisDirection.right:
              originalVal = _grid[idx][size - 1 - j];
              _grid[idx][size - 1 - j] = merged[j];
              break;
            case AxisDirection.up:
              originalVal = _grid[j][idx];
              _grid[j][idx] = merged[j];
              break;
            case AxisDirection.down:
              originalVal = _grid[size - 1 - j][idx];
              _grid[size - 1 - j][idx] = merged[j];
              break;
          }
          if (originalVal != merged[j]) moved = true;
        }
      }

      if (moved) {
        _score += earnedScore;
        StorageService.save2048HighScore(_score);
        _bestScore = math.max(_bestScore, _score);
        FeedbackService.triggerLight();
        _spawnTile();
        _checkGameOver();
      }
    });
  }

  void _checkGameOver() {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_grid[r][c] == 0) return;
        if (r + 1 < size && _grid[r][c] == _grid[r + 1][c]) return;
        if (c + 1 < size && _grid[r][c] == _grid[r][c + 1]) return;
      }
    }
    _gameOver = true;
    FeedbackService.triggerImpact();
  }

  Color _getTileColor(int val) {
    switch (val) {
      case 2:
        return const Color(0xFF1E293B);
      case 4:
        return const Color(0xFF334155);
      case 8:
        return const Color(0xFFFF9F1C);
      case 16:
        return const Color(0xFFFF4040);
      case 32:
        return const Color(0xFFFF007F);
      case 64:
        return const Color(0xFFE056FD);
      case 128:
        return const Color(0xFF7000FF);
      case 256:
        return const Color(0xFF00F0FF);
      case 512:
        return const Color(0xFF05FFA1);
      case 1024:
      case 2048:
      default:
        return const Color(0xFFFFD166);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B101D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141C30),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '2048 QUANTUM',
          style: TextStyle(
            color: Color(0xFF00F0FF),
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
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _swipe(AxisDirection.left);
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) _swipe(AxisDirection.right);
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) _swipe(AxisDirection.up);
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) _swipe(AxisDirection.down);
          }
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          onPanEnd: (details) {
            final vx = details.velocity.pixelsPerSecond.dx;
            final vy = details.velocity.pixelsPerSecond.dy;
            if (vx.abs() > vy.abs()) {
              if (vx > 100) _swipe(AxisDirection.right);
              if (vx < -100) _swipe(AxisDirection.left);
            } else {
              if (vy > 100) _swipe(AxisDirection.down);
              if (vy < -100) _swipe(AxisDirection.up);
            }
          },
          child: SafeArea(
            child: Column(
              children: [
                // Score Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildScoreCard('SCORE', _score, const Color(0xFF00F0FF)),
                      _buildScoreCard('MEILLEUR', _bestScore, const Color(0xFFFFD166)),
                    ],
                  ),
                ),

                const Spacer(),

                // Grille 2048
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141C30),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Column(
                        children: List.generate(size, (r) {
                          return Expanded(
                            child: Row(
                              children: List.generate(size, (c) {
                                final val = _grid[r][c];
                                return Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _getTileColor(val),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: val > 0
                                          ? [
                                              BoxShadow(
                                                color: _getTileColor(val).withValues(alpha: 0.4),
                                                blurRadius: 8,
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                      child: val > 0
                                          ? Text(
                                              '$val',
                                              style: TextStyle(
                                                color: val <= 4 ? Colors.white70 : Colors.white,
                                                fontSize: val > 512 ? 20 : 26,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            )
                                          : null,
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

                // Indication
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    _gameOver ? 'PARTIE TERMINÉE' : 'Glissez le doigt dans les 4 directions',
                    style: TextStyle(
                      color: _gameOver ? Colors.redAccent : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141C30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
