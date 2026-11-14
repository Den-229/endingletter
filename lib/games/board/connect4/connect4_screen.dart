import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';

enum DiscColor { none, red, yellow }

class Connect4Screen extends StatefulWidget {
  const Connect4Screen({super.key});

  @override
  State<Connect4Screen> createState() => _Connect4ScreenState();
}

class _Connect4ScreenState extends State<Connect4Screen> {
  static const int rows = 6;
  static const int cols = 7;

  late List<List<DiscColor>> _grid;
  DiscColor _turn = DiscColor.red;
  DiscColor _winner = DiscColor.none;
  bool _vsAi = true;
  bool _aiThinking = false;
  int _scoreRed = 0;
  int _scoreYellow = 0;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    _grid = List.generate(rows, (_) => List.filled(cols, DiscColor.none));
    _turn = DiscColor.red;
    _winner = DiscColor.none;
    _aiThinking = false;
  }

  void _dropDisc(int col) {
    if (_winner != DiscColor.none || _aiThinking) return;

    int targetRow = -1;
    for (int r = rows - 1; r >= 0; r--) {
      if (_grid[r][col] == DiscColor.none) {
        targetRow = r;
        break;
      }
    }

    if (targetRow == -1) return;

    setState(() {
      _grid[targetRow][col] = _turn;
      FeedbackService.triggerImpact();

      if (_checkWin(targetRow, col, _turn)) {
        _winner = _turn;
        if (_winner == DiscColor.red) _scoreRed++;
        if (_winner == DiscColor.yellow) _scoreYellow++;
        FeedbackService.triggerSuccess();
        return;
      }

      _turn = _turn == DiscColor.red ? DiscColor.yellow : DiscColor.red;
    });

    if (_vsAi && _turn == DiscColor.yellow) {
      _triggerAi();
    }
  }

  bool _checkWin(int r, int c, DiscColor color) {
    // Horizontale
    int count = 0;
    for (int j = 0; j < cols; j++) {
      count = (_grid[r][j] == color) ? count + 1 : 0;
      if (count >= 4) return true;
    }

    // Verticale
    count = 0;
    for (int i = 0; i < rows; i++) {
      count = (_grid[i][c] == color) ? count + 1 : 0;
      if (count >= 4) return true;
    }

    // Diagonale \
    for (int dr = -3; dr <= 3; dr++) {
      int countDiag = 0;
      for (int step = 0; step < 4; step++) {
        int nr = r + dr + step;
        int nc = c + dr + step;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && _grid[nr][nc] == color) {
          countDiag++;
        } else {
          countDiag = 0;
        }
        if (countDiag >= 4) return true;
      }
    }

    // Diagonale /
    for (int dr = -3; dr <= 3; dr++) {
      int countDiag = 0;
      for (int step = 0; step < 4; step++) {
        int nr = r - dr - step;
        int nc = c + dr + step;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && _grid[nr][nc] == color) {
          countDiag++;
        } else {
          countDiag = 0;
        }
        if (countDiag >= 4) return true;
      }
    }

    return false;
  }

  void _triggerAi() {
    setState(() => _aiThinking = true);
    Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      int bestCol = -1;

      // 1. Coup gagnant pour l'IA
      for (int c = 0; c < cols; c++) {
        if (_canPlayCol(c)) {
          final r = _getAvailableRow(c);
          if (r != -1 && _checkWin(r, c, DiscColor.yellow)) {
            bestCol = c;
            break;
          }
        }
      }

      // 2. Bloquer le joueur
      if (bestCol == -1) {
        for (int c = 0; c < cols; c++) {
          if (_canPlayCol(c)) {
            final r = _getAvailableRow(c);
            if (r != -1 && _checkWin(r, c, DiscColor.red)) {
              bestCol = c;
              break;
            }
          }
        }
      }

      // 3. Colonne aléatoire intelligente (centre en priorité)
      if (bestCol == -1) {
        final available = [3, 2, 4, 1, 5, 0, 6].where(_canPlayCol).toList();
        if (available.isNotEmpty) {
          bestCol = available[math.Random().nextInt(math.min(3, available.length))];
        }
      }

      setState(() => _aiThinking = false);
      if (bestCol != -1) {
        _dropDisc(bestCol);
      }
    });
  }

  bool _canPlayCol(int c) => _grid[0][c] == DiscColor.none;

  int _getAvailableRow(int c) {
    for (int r = rows - 1; r >= 0; r--) {
      if (_grid[r][c] == DiscColor.none) return r;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10172D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.grid_on, color: Color(0xFFFFD166)),
            SizedBox(width: 8),
            Text(
              'PUISSANCE 4 NÉON',
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
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => setState(_resetGame),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Bandeau Score & Mode
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
                          label: const Text('vs IA', style: TextStyle(fontSize: 12)),
                          selected: _vsAi,
                          selectedColor: const Color(0xFFFFD166),
                          labelStyle: TextStyle(
                            color: _vsAi ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) => setState(() => _vsAi = true),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('2 Joueurs', style: TextStyle(fontSize: 12)),
                          selected: !_vsAi,
                          selectedColor: const Color(0xFFFFD166),
                          labelStyle: TextStyle(
                            color: !_vsAi ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) => setState(() => _vsAi = false),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF2A6D))),
                        const SizedBox(width: 4),
                        Text('Rouge: $_scoreRed', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 12),
                        Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD166))),
                        const SizedBox(width: 4),
                        Text('Jaune: $_scoreYellow', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Flèches d'insertion au-dessus de chaque colonne
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: List.generate(cols, (c) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _dropDisc(c),
                      child: Container(
                        height: 30,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_drop_down,
                          color: _turn == DiscColor.red ? const Color(0xFFFF2A6D) : const Color(0xFFFFD166),
                          size: 28,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Grille bleue authentique de Puissance 4
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 2),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF4364F7).withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                child: AspectRatio(
                  aspectRatio: 7 / 6,
                  child: Column(
                    children: List.generate(rows, (r) {
                      return Expanded(
                        child: Row(
                          children: List.generate(cols, (c) {
                            final disc = _grid[r][c];

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => _dropDisc(c),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: disc == DiscColor.none
                                        ? const Color(0xFF090E1B)
                                        : (disc == DiscColor.red
                                            ? const Color(0xFFFF2A6D)
                                            : const Color(0xFFFFD166)),
                                    border: Border.all(color: Colors.black45, width: 2.5),
                                    boxShadow: disc != DiscColor.none
                                        ? [
                                            BoxShadow(
                                              color: (disc == DiscColor.red ? const Color(0xFFFF2A6D) : const Color(0xFFFFD166)).withValues(alpha: 0.8),
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: disc != DiscColor.none
                                      ? Center(
                                          // Anneau concentrique intérieur 3D
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                                            ),
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

            // Pieds du stand Puissance 4
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 32, height: 16, decoration: BoxDecoration(color: const Color(0xFF0052D4), borderRadius: BorderRadius.circular(4))),
                  Container(width: 32, height: 16, decoration: BoxDecoration(color: const Color(0xFF0052D4), borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),

            const Spacer(),

            // Statut ou Victoire
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _winner != DiscColor.none
                  ? Column(
                      children: [
                        Text(
                          _winner == DiscColor.red ? '🎉 VICTOIRE DES ROUGES !' : '🎉 VICTOIRE DES JAUNES !',
                          style: TextStyle(
                            color: _winner == DiscColor.red ? const Color(0xFFFF2A6D) : const Color(0xFFFFD166),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () => setState(_resetGame),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FFCC),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('REJOUER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  : Text(
                      _turn == DiscColor.red
                          ? 'Tour : Jetons Rouges'
                          : (_vsAi ? 'L\'IA réfléchit...' : 'Tour : Jetons Jaunes'),
                      style: TextStyle(
                        color: _turn == DiscColor.red ? const Color(0xFFFF2A6D) : const Color(0xFFFFD166),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
