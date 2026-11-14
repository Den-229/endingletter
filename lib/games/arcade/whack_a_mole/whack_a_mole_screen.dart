import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';

class WhackAMoleScreen extends StatefulWidget {
  const WhackAMoleScreen({super.key});

  @override
  State<WhackAMoleScreen> createState() => _WhackAMoleScreenState();
}

class _WhackAMoleScreenState extends State<WhackAMoleScreen> {
  static const int holeCount = 9;
  int? _activeMoleIndex;
  int _score = 0;
  int _highScore = 0;
  int _timeLeft = 30;
  Timer? _gameTimer;
  Timer? _moleTimer;
  bool _isPlaying = false;
  bool _isGameOver = false;
  final math.Random _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _highScore = StorageService.getHighScore('whack_a_mole');
  }

  void _startGame() {
    setState(() {
      _score = 0;
      _timeLeft = 30;
      _isPlaying = true;
      _isGameOver = false;
      _activeMoleIndex = null;
    });

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _endGame();
      }
    });

    _spawnMole();
  }

  void _spawnMole() {
    if (!_isPlaying) return;

    _moleTimer?.cancel();
    setState(() {
      _activeMoleIndex = _rnd.nextInt(holeCount);
    });

    // Durée d'apparition qui accélère avec le score
    final durationMs = math.max(480, 950 - (_score * 12));
    _moleTimer = Timer(Duration(milliseconds: durationMs), () {
      if (mounted && _isPlaying) {
        setState(() => _activeMoleIndex = null);
        Timer(const Duration(milliseconds: 150), _spawnMole);
      }
    });
  }

  void _onHoleTap(int index) {
    if (!_isPlaying || _isGameOver) return;

    if (_activeMoleIndex == index) {
      // Taupe touchée !
      FeedbackService.triggerImpact();
      setState(() {
        _score += 100;
        _activeMoleIndex = null;
        StorageService.saveHighScore('whack_a_mole', _score);
        _highScore = math.max(_highScore, _score);
      });
      _spawnMole();
    } else {
      // Coup manqué
      FeedbackService.triggerLight();
    }
  }

  void _endGame() {
    _gameTimer?.cancel();
    _moleTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
      _activeMoleIndex = null;
    });
    FeedbackService.triggerSuccess();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _moleTimer?.cancel();
    super.dispose();
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
        title: const Text(
          'TAPE-TAUPE CYBER ⚡',
          style: TextStyle(
            color: Color(0xFFFF2A6D),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // HUD
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: const Color(0xFF10172D),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SCORE : $_score', style: const TextStyle(color: Color(0xFFFF2A6D), fontSize: 18, fontWeight: FontWeight.w900)),
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Color(0xFFFFD166), size: 20),
                      const SizedBox(width: 4),
                      Text('$_timeLeft s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  Text('RECORD : $_highScore', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),

            const Spacer(),

            // Grille 3x3 des terriers
            Center(
              child: Container(
                width: 320,
                height: 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D36),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFF2A6D).withValues(alpha: 0.5), width: 2),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: holeCount,
                  itemBuilder: (ctx, i) {
                    final hasMole = _activeMoleIndex == i;

                    return GestureDetector(
                      onTap: () => _onHoleTap(i),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C1224),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: hasMole ? const Color(0xFFFF2A6D) : Colors.white12,
                            width: hasMole ? 2.5 : 1.0,
                          ),
                          boxShadow: hasMole
                              ? [BoxShadow(color: const Color(0xFFFF2A6D).withValues(alpha: 0.6), blurRadius: 16)]
                              : [],
                        ),
                        child: Center(
                          child: hasMole
                              ? const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.adb, color: Color(0xFFFF2A6D), size: 40),
                                    Text('TOUCHER !', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                                  ],
                                )
                              : Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const Spacer(),

            // Bouton Start / Statut
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: !_isPlaying
                  ? ElevatedButton.icon(
                      onPressed: _startGame,
                      icon: const Icon(Icons.play_arrow, color: Colors.black),
                      label: Text(
                        _isGameOver ? 'REJOUER' : 'COMMENCER',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2A6D),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      ),
                    )
                  : const Text(
                      'Tapez les robots néon dès qu\'ils sortent !',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
