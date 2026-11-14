import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';

class SimonScreen extends StatefulWidget {
  const SimonScreen({super.key});

  @override
  State<SimonScreen> createState() => _SimonScreenState();
}

class _SimonScreenState extends State<SimonScreen> {
  final List<int> _sequence = [];
  int _playerStep = 0;
  bool _isShowingSequence = false;
  int? _highlightedIndex;
  int _score = 0;
  int _highScore = 0;
  bool _isGameOver = false;
  final math.Random _rnd = math.Random();

  final List<Map<String, dynamic>> _colors = [
    {'color': const Color(0xFF05FFA1), 'name': 'VERT'},
    {'color': const Color(0xFFFF2A6D), 'name': 'ROUGE'},
    {'color': const Color(0xFFFFD166), 'name': 'JAUNE'},
    {'color': const Color(0xFF00F0FF), 'name': 'BLEU'},
  ];

  @override
  void initState() {
    super.initState();
    _highScore = StorageService.getSimonHighScore();
    _startNewGame();
  }

  void _startNewGame() {
    _sequence.clear();
    _playerStep = 0;
    _score = 0;
    _isGameOver = false;
    _addNewStep();
  }

  void _addNewStep() {
    _sequence.add(_rnd.nextInt(4));
    _score = _sequence.length - 1;
    StorageService.saveSimonHighScore(_score);
    _highScore = math.max(_highScore, _score);
    _playerStep = 0;
    _playSequence();
  }

  void _playSequence() {
    setState(() => _isShowingSequence = true);

    int i = 0;
    Timer.periodic(const Duration(milliseconds: 550), (timer) {
      if (i >= _sequence.length) {
        timer.cancel();
        setState(() {
          _highlightedIndex = null;
          _isShowingSequence = false;
        });
        return;
      }

      setState(() {
        _highlightedIndex = _sequence[i];
      });
      FeedbackService.triggerLight();

      Timer(const Duration(milliseconds: 320), () {
        if (mounted) {
          setState(() => _highlightedIndex = null);
        }
      });

      i++;
    });
  }

  void _onPadTap(int index) {
    if (_isShowingSequence || _isGameOver) return;

    FeedbackService.triggerLight();

    if (_sequence[_playerStep] == index) {
      // Étape correcte
      _playerStep++;
      if (_playerStep >= _sequence.length) {
        // Séquence complète réussie !
        FeedbackService.triggerSuccess();
        Timer(const Duration(milliseconds: 600), _addNewStep);
      }
    } else {
      // Erreur !
      FeedbackService.triggerImpact();
      setState(() => _isGameOver = true);
    }
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
          'SIMON NÉON (RÉFLEXE & RYTHME)',
          style: TextStyle(
            color: Color(0xFF05FFA1),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              color: const Color(0xFF10172D),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SCORE : $_score', style: const TextStyle(color: Color(0xFF05FFA1), fontSize: 18, fontWeight: FontWeight.w900)),
                  Text('RECORD : $_highScore', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),

            const Spacer(),

            // Statut
            Text(
              _isShowingSequence ? 'OBSERVEZ LA SÉQUENCE...' : 'À VOUS DE RÉPÉTER !',
              style: TextStyle(
                color: _isShowingSequence ? Colors.amberAccent : const Color(0xFF00FFCC),
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 20),

            // Pad Simon 4 cadrans
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF141C30),
                  border: Border.all(color: Colors.white12, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 20,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(4, (i) {
                    final isLit = _highlightedIndex == i;
                    final baseColor = _colors[i]['color'] as Color;

                    return GestureDetector(
                      onTap: () => _onPadTap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isLit ? baseColor : baseColor.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(i == 0 ? 100 : 16),
                            topRight: Radius.circular(i == 1 ? 100 : 16),
                            bottomLeft: Radius.circular(i == 2 ? 100 : 16),
                            bottomRight: Radius.circular(i == 3 ? 100 : 16),
                          ),
                          border: Border.all(
                            color: isLit ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isLit
                              ? [
                                  BoxShadow(
                                    color: baseColor.withValues(alpha: 0.9),
                                    blurRadius: 22,
                                    spreadRadius: 4,
                                  ),
                                ]
                              : [],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            const Spacer(),

            if (_isGameOver)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    const Text('SÉQUENCE INTERROMPUE !', style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => setState(_startNewGame),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF05FFA1)),
                      child: const Text('RÉESSAYER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

