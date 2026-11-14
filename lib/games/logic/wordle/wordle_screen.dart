import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';

class WordleScreen extends StatefulWidget {
  const WordleScreen({super.key});

  @override
  State<WordleScreen> createState() => _WordleScreenState();
}

class _WordleScreenState extends State<WordleScreen> {
  static const int wordLength = 5;
  static const int maxGuesses = 6;

  final List<String> _words = [
    'CYBER', 'ROBOT', 'LASER', 'PIXEL', 'SPACE',
    'RADAR', 'ALPHA', 'BRAIN', 'SHINE', 'SMART',
    'CLOUD', 'FIGHT', 'POWER', 'GAMES', 'TURBO'
  ];

  late String _targetWord;
  final List<String> _guesses = [];
  String _currentInput = '';
  bool _isWon = false;
  bool _isGameOver = false;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    _targetWord = _words[math.Random().nextInt(_words.length)];
    _guesses.clear();
    _currentInput = '';
    _isWon = false;
    _isGameOver = false;
    setState(() {});
  }

  void _onKeyPress(String key) {
    if (_isWon || _isGameOver) return;

    if (key == 'ENTER') {
      if (_currentInput.length == wordLength) {
        FeedbackService.triggerImpact();
        setState(() {
          _guesses.add(_currentInput);
          if (_currentInput == _targetWord) {
            _isWon = true;
            _streak++;
            FeedbackService.triggerSuccess();
          } else if (_guesses.length >= maxGuesses) {
            _isGameOver = true;
            _streak = 0;
            FeedbackService.triggerImpact();
          }
          _currentInput = '';
        });
      }
    } else if (key == '⌫') {
      if (_currentInput.isNotEmpty) {
        FeedbackService.triggerLight();
        setState(() {
          _currentInput = _currentInput.substring(0, _currentInput.length - 1);
        });
      }
    } else {
      if (_currentInput.length < wordLength) {
        FeedbackService.triggerLight();
        setState(() {
          _currentInput += key;
        });
      }
    }
  }

  Color _getLetterColor(int rowIdx, int colIdx) {
    if (rowIdx >= _guesses.length) return const Color(0xFF131D36);

    final guess = _guesses[rowIdx];
    final char = guess[colIdx];

    if (_targetWord[colIdx] == char) {
      return const Color(0xFF05FFA1); // Vert : bonne place
    } else if (_targetWord.contains(char)) {
      return const Color(0xFFFFD166); // Jaune : mal placé
    } else {
      return const Color(0xFF334155); // Gris foncé : absent
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10172D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'WORDLE CYBER (Série : $_streak)',
          style: const TextStyle(color: Color(0xFF05FFA1), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _startNewGame,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Grille 6x5 Wordle
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 290,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(maxGuesses, (r) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(wordLength, (c) {
                            String letter = '';
                            if (r < _guesses.length) {
                              letter = _guesses[r][c];
                            } else if (r == _guesses.length && c < _currentInput.length) {
                              letter = _currentInput[c];
                            }

                            final color = _getLetterColor(r, c);

                            return Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: letter.isNotEmpty ? Colors.white38 : Colors.white12,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  letter,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
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

            // Message de fin
            if (_isWon || _isGameOver)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _isWon ? '🎉 MOT TROUVÉ !' : 'MOT SECRET : $_targetWord',
                  style: TextStyle(
                    color: _isWon ? const Color(0xFF05FFA1) : Colors.redAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

            // Clavier virtuel
            _buildVirtualKeyboard(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildVirtualKeyboard() {
    const rows = [
      ['A', 'Z', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['Q', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'M'],
      ['ENTER', 'W', 'X', 'C', 'V', 'B', 'N', '⌫'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((k) {
              final isSpecial = k == 'ENTER' || k == '⌫';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: GestureDetector(
                  onTap: () => _onKeyPress(k),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isSpecial ? 10 : 8, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2640),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      k,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isSpecial ? 11 : 14,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
