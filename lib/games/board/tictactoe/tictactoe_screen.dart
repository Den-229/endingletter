import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';

enum CellValue { none, x, o }

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  late List<CellValue> _board;
  CellValue _turn = CellValue.x;
  CellValue _winner = CellValue.none;
  bool _isDraw = false;
  bool _vsAi = true;
  bool _aiThinking = false;
  int _scoreX = 0;
  int _scoreO = 0;

  @override
  void initState() {
    super.initState();
    _resetBoard();
  }

  void _resetBoard() {
    _board = List.filled(9, CellValue.none);
    _turn = CellValue.x;
    _winner = CellValue.none;
    _isDraw = false;
    _aiThinking = false;
  }

  void _onCellTap(int idx) {
    if (_board[idx] != CellValue.none || _winner != CellValue.none || _isDraw || _aiThinking) {
      return;
    }

    setState(() {
      _board[idx] = _turn;
      FeedbackService.triggerImpact();

      if (_checkWin(_turn)) {
        _winner = _turn;
        if (_winner == CellValue.x) _scoreX++;
        if (_winner == CellValue.o) _scoreO++;
        FeedbackService.triggerSuccess();
        return;
      } else if (!_board.contains(CellValue.none)) {
        _isDraw = true;
        FeedbackService.triggerLight();
        return;
      }

      _turn = _turn == CellValue.x ? CellValue.o : CellValue.x;
    });

    if (_vsAi && _turn == CellValue.o) {
      _triggerAi();
    }
  }

  bool _checkWin(CellValue val) {
    const wins = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // Horizontales
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // Verticales
      [0, 4, 8], [2, 4, 6]             // Diagonales
    ];
    return wins.any((w) => _board[w[0]] == val && _board[w[1]] == val && _board[w[2]] == val);
  }

  void _triggerAi() {
    setState(() => _aiThinking = true);
    Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      int bestMove = _findBestAiMove();
      if (bestMove != -1) {
        _onCellTap(bestMove);
      }
      setState(() => _aiThinking = false);
    });
  }

  int _findBestAiMove() {
    // 1. Coup gagnant pour O
    for (int i = 0; i < 9; i++) {
      if (_board[i] == CellValue.none) {
        _board[i] = CellValue.o;
        if (_checkWin(CellValue.o)) {
          _board[i] = CellValue.none;
          return i;
        }
        _board[i] = CellValue.none;
      }
    }
    // 2. Bloquer coup gagnant de X
    for (int i = 0; i < 9; i++) {
      if (_board[i] == CellValue.none) {
        _board[i] = CellValue.x;
        if (_checkWin(CellValue.x)) {
          _board[i] = CellValue.none;
          return i;
        }
        _board[i] = CellValue.none;
      }
    }
    // 3. Centre si libre
    if (_board[4] == CellValue.none) return 4;
    // 4. Premier emplacement vide
    for (int i = 0; i < 9; i++) {
      if (_board[i] == CellValue.none) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1021),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141A33),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'MORPION NÉON (TIC-TAC-TOE)',
          style: TextStyle(
            color: Color(0xFF00FFCC),
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
            // Mode & Score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(0xFF141A33),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('vs IA', style: TextStyle(fontSize: 12)),
                        selected: _vsAi,
                        selectedColor: const Color(0xFF00FFCC),
                        onSelected: (val) => setState(() => _vsAi = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('2 Joueurs', style: TextStyle(fontSize: 12)),
                        selected: !_vsAi,
                        selectedColor: const Color(0xFF00FFCC),
                        onSelected: (val) => setState(() => _vsAi = false),
                      ),
                    ],
                  ),
                  Text('X: $_scoreX  |  O: $_scoreO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const Spacer(),

            // Grille 3x3
            Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141A33),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.5), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 9,
                    itemBuilder: (ctx, i) {
                      final val = _board[i];
                      return GestureDetector(
                        onTap: () => _onCellTap(i),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0E1D),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Center(
                            child: val != CellValue.none
                                ? Text(
                                    val == CellValue.x ? 'X' : 'O',
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                      color: val == CellValue.x ? const Color(0xFF00FFCC) : const Color(0xFFFF2A6D),
                                      shadows: [
                                        Shadow(
                                          color: val == CellValue.x ? const Color(0xFF00FFCC) : const Color(0xFFFF2A6D),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                _winner != CellValue.none
                    ? '🎉 VICTOIRE DE ${_winner == CellValue.x ? 'X' : 'O'} !'
                    : (_isDraw
                        ? 'MATCH NUL !'
                        : (_turn == CellValue.x ? 'Tour : Joueur X' : (_vsAi ? 'L\'IA réfléchit...' : 'Tour : Joueur O'))),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

