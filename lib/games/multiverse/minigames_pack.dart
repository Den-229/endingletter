import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/storage_service.dart';

// ==========================================
// 1. PONG RÉTRO (1P vs IA & 2 Joueurs)
// ==========================================
class PongScreen extends StatefulWidget {
  const PongScreen({super.key});

  @override
  State<PongScreen> createState() => _PongScreenState();
}

class _PongScreenState extends State<PongScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  double _player1Y = 0.5;
  double _player2Y = 0.5;
  Offset _ball = const Offset(0.5, 0.5);
  Offset _ballVel = const Offset(0.38, 0.26);
  int _score1 = 0;
  int _score2 = 0;
  final bool _isPlaying = true;
  double _lastTs = 0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController.unbounded(vsync: this)..addListener(_onTick);
    _ticker.repeat(period: const Duration(days: 1));
  }

  void _onTick() {
    if (!_isPlaying) return;
    final currentMs = _ticker.lastElapsedDuration?.inMicroseconds ?? 0;
    if (_lastTs == 0) {
      _lastTs = currentMs.toDouble();
      return;
    }
    double dt = (currentMs - _lastTs) / 1000000.0;
    _lastTs = currentMs.toDouble();
    if (dt > 0.1) dt = 0.033;

    setState(() {
      _ball += _ballVel * dt;

      // Rebond haut & bas
      if (_ball.dy <= 0.05 || _ball.dy >= 0.95) {
        _ballVel = Offset(_ballVel.dx, -_ballVel.dy);
        FeedbackService.triggerLight();
      }

      // IA Joueur 2
      _player2Y += (_ball.dy - _player2Y) * 4.0 * dt;

      // Rebond Raquette 1 (Gauche x = 0.08)
      if (_ball.dx <= 0.08 && (_ball.dy - _player1Y).abs() < 0.12 && _ballVel.dx < 0) {
        _ballVel = Offset(-_ballVel.dx * 1.05, _ballVel.dy);
        FeedbackService.triggerImpact();
      }

      // Rebond Raquette 2 (Droite x = 0.92)
      if (_ball.dx >= 0.92 && (_ball.dy - _player2Y).abs() < 0.12 && _ballVel.dx > 0) {
        _ballVel = Offset(-_ballVel.dx * 1.05, _ballVel.dy);
        FeedbackService.triggerImpact();
      }

      // Buts
      if (_ball.dx < 0.0) {
        _score2++;
        _resetBall(1);
      } else if (_ball.dx > 1.0) {
        _score1++;
        _resetBall(-1);
      }
    });
  }

  void _resetBall(double dirX) {
    _ball = const Offset(0.5, 0.5);
    _ballVel = Offset(0.38 * dirX, (math.Random().nextDouble() - 0.5) * 0.5);
    FeedbackService.triggerSuccess();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10172D),
        title: Text('PONG RÉTRO ($_score1 - $_score2)', style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 16)),
      ),
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null) {
            setState(() => _player1Y = (details.localPosition.dy / box.size.height).clamp(0.1, 0.9));
          }
        },
        child: Stack(
          children: [
            // Filet central
            Center(child: Container(width: 2, height: double.infinity, color: Colors.white12)),
            // Raquette 1 (Joueur)
            Align(
              alignment: Alignment(-0.85, (_player1Y - 0.5) * 2),
              child: Container(width: 14, height: 75, decoration: BoxDecoration(color: const Color(0xFF00FFCC), borderRadius: BorderRadius.circular(6))),
            ),
            // Raquette 2 (IA)
            Align(
              alignment: Alignment(0.85, (_player2Y - 0.5) * 2),
              child: Container(width: 14, height: 75, decoration: BoxDecoration(color: const Color(0xFFFF2A6D), borderRadius: BorderRadius.circular(6))),
            ),
            // Balle
            Align(
              alignment: Alignment((_ball.dx - 0.5) * 2, (_ball.dy - 0.5) * 2),
              child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. LIGHTS OUT (Casse-Tête Lumineux)
// ==========================================
class LightsOutScreen extends StatefulWidget {
  const LightsOutScreen({super.key});

  @override
  State<LightsOutScreen> createState() => _LightsOutScreenState();
}

class _LightsOutScreenState extends State<LightsOutScreen> {
  static const int size = 4;
  late List<List<bool>> _grid;
  int _moves = 0;
  bool _isWon = false;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    _grid = List.generate(size, (_) => List.filled(size, false));
    _moves = 0;
    _isWon = false;
    // Appliquer quelques inversions aléatoires
    final rnd = math.Random();
    for (int i = 0; i < 6; i++) {
      _toggle(rnd.nextInt(size), rnd.nextInt(size), countMove: false);
    }
  }

  void _toggle(int r, int c, {bool countMove = true}) {
    if (_isWon) return;
    setState(() {
      if (countMove) _moves++;
      _flip(r, c);
      _flip(r - 1, c);
      _flip(r + 1, c);
      _flip(r, c - 1);
      _flip(r, c + 1);

      // Victoire si toutes les lumières sont éteintes
      bool allOff = true;
      for (final row in _grid) {
        for (final cell in row) {
          if (cell) allOff = false;
        }
      }
      if (allOff && countMove) {
        _isWon = true;
        FeedbackService.triggerSuccess();
      } else if (countMove) {
        FeedbackService.triggerLight();
      }
    });
  }

  void _flip(int r, int c) {
    if (r >= 0 && r < size && c >= 0 && c < size) {
      _grid[r][c] = !_grid[r][c];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10172D),
        title: Text('LIGHTS OUT ($_moves coups)', style: const TextStyle(color: Color(0xFFFFD166), fontSize: 16)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(_resetGame))],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Éteignez toutes les lumières !', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),
            Container(
              width: 280,
              height: 280,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF131D36), borderRadius: BorderRadius.circular(16)),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: size, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: size * size,
                itemBuilder: (ctx, idx) {
                  final r = idx ~/ size;
                  final c = idx % size;
                  final isLit = _grid[r][c];
                  return GestureDetector(
                    onTap: () => _toggle(r, c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isLit ? const Color(0xFFFFD166) : const Color(0xFF1C2744),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isLit ? [BoxShadow(color: const Color(0xFFFFD166).withValues(alpha: 0.6), blurRadius: 12)] : [],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isWon) ...[
              const SizedBox(height: 20),
              const Text('🎉 BRAVO ! GRILLE ÉTEINTE !', style: TextStyle(color: Color(0xFF00FFCC), fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. TAQUIN 15 (Sliding Puzzle)
// ==========================================
class SlidingPuzzleScreen extends StatefulWidget {
  const SlidingPuzzleScreen({super.key});

  @override
  State<SlidingPuzzleScreen> createState() => _SlidingPuzzleScreenState();
}

class _SlidingPuzzleScreenState extends State<SlidingPuzzleScreen> {
  late List<int> _tiles; // 0..15 (0 est la case vide)
  int _moves = 0;
  bool _isWon = false;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    _tiles = List.generate(16, (i) => i);
    _moves = 0;
    _isWon = false;
    _shuffle();
  }

  void _shuffle() {
    final rnd = math.Random();
    for (int i = 0; i < 80; i++) {
      int emptyIdx = _tiles.indexOf(0);
      List<int> neighbors = [];
      int r = emptyIdx ~/ 4;
      int c = emptyIdx % 4;
      if (r > 0) neighbors.add(emptyIdx - 4);
      if (r < 3) neighbors.add(emptyIdx + 4);
      if (c > 0) neighbors.add(emptyIdx - 1);
      if (c < 3) neighbors.add(emptyIdx + 1);
      final pick = neighbors[rnd.nextInt(neighbors.length)];
      _tiles[emptyIdx] = _tiles[pick];
      _tiles[pick] = 0;
    }
  }

  void _onTileTap(int idx) {
    if (_isWon) return;
    int emptyIdx = _tiles.indexOf(0);
    int r1 = idx ~/ 4;
    int c1 = idx % 4;
    int r2 = emptyIdx ~/ 4;
    int c2 = emptyIdx % 4;

    if ((r1 == r2 && (c1 - c2).abs() == 1) || (c1 == c2 && (r1 - r2).abs() == 1)) {
      setState(() {
        _tiles[emptyIdx] = _tiles[idx];
        _tiles[idx] = 0;
        _moves++;
        FeedbackService.triggerLight();

        bool won = true;
        for (int i = 0; i < 15; i++) {
          if (_tiles[i] != i + 1) won = false;
        }
        if (won && _tiles[15] == 0) {
          _isWon = true;
          FeedbackService.triggerSuccess();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10172D),
        title: Text('TAQUIN 15 ($_moves Coups)', style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 16)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(_resetGame))],
      ),
      body: Center(
        child: Container(
          width: 300,
          height: 300,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF131D36), borderRadius: BorderRadius.circular(16)),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 6, mainAxisSpacing: 6),
            itemCount: 16,
            itemBuilder: (ctx, idx) {
              final val = _tiles[idx];
              if (val == 0) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () => _onTileTap(idx),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F0FF),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: const Color(0xFF00F0FF).withValues(alpha: 0.3), blurRadius: 4)],
                  ),
                  child: Center(
                    child: Text('$val', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20)),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. TEST RÉFLEXES MILLISECONDES (Reaction Test)
// ==========================================
enum ReactionState { waiting, ready, clickNow, done }

class ReactionTimerScreen extends StatefulWidget {
  const ReactionTimerScreen({super.key});

  @override
  State<ReactionTimerScreen> createState() => _ReactionTimerScreenState();
}

class _ReactionTimerScreenState extends State<ReactionTimerScreen> {
  ReactionState _state = ReactionState.waiting;
  Timer? _timer;
  int _startTime = 0;
  int _reactionMs = 0;
  int _bestMs = 9999;

  void _startTest() {
    setState(() => _state = ReactionState.ready);
    final delay = 1500 + math.Random().nextInt(3000);
    _timer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() {
        _state = ReactionState.clickNow;
        _startTime = DateTime.now().millisecondsSinceEpoch;
      });
      FeedbackService.triggerImpact();
    });
  }

  void _onScreenTap() {
    if (_state == ReactionState.waiting || _state == ReactionState.done) {
      _startTest();
    } else if (_state == ReactionState.ready) {
      // Trop tôt !
      _timer?.cancel();
      setState(() {
        _state = ReactionState.done;
        _reactionMs = -1; // Faux départ
      });
      FeedbackService.triggerImpact();
    } else if (_state == ReactionState.clickNow) {
      final now = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _reactionMs = now - _startTime;
        _bestMs = math.min(_bestMs, _reactionMs);
        _state = ReactionState.done;
      });
      FeedbackService.triggerSuccess();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFF10172D);
    String text = 'TOUCHEZ POUR COMMENCER';
    if (_state == ReactionState.ready) {
      bg = const Color(0xFFFF2A6D);
      text = 'ATTENDEZ LE VERT...';
    } else if (_state == ReactionState.clickNow) {
      bg = const Color(0xFF05FFA1);
      text = 'TOUCHEZ VITE ! ⚡';
    } else if (_state == ReactionState.done) {
      bg = const Color(0xFF1A2645);
      text = _reactionMs == -1 ? 'TROP TÔT ! Réessayez' : 'TEMPS : $_reactionMs ms\nRecord : ${_bestMs < 9000 ? "$_bestMs ms" : "—"}';
    }

    return Scaffold(
      backgroundColor: bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onScreenTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flash_on, color: Colors.white, size: 55),
              const SizedBox(height: 16),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
              const SizedBox(height: 20),
              if (_state == ReactionState.done)
                ElevatedButton(
                  onPressed: _startTest,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFCC)),
                  child: const Text('RÉESSAYER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 5. HI-LO CARDS (Plus Grand ou Plus Petit)
// ==========================================
class HiLoScreen extends StatefulWidget {
  const HiLoScreen({super.key});

  @override
  State<HiLoScreen> createState() => _HiLoScreenState();
}

class _HiLoScreenState extends State<HiLoScreen> {
  int _currentCard = 7;
  int _streak = 0;
  int _bestStreak = 0;
  String _msg = 'La prochaine carte sera-t-elle PLUS HAUTE ou PLUS BASSE ?';
  final math.Random _rnd = math.Random();

  void _guess({required bool higher}) {
    final nextCard = _rnd.nextInt(13) + 1; // 1 (As) à 13 (Roi)

    if ((higher && nextCard >= _currentCard) || (!higher && nextCard <= _currentCard)) {
      _streak++;
      _bestStreak = math.max(_bestStreak, _streak);
      _msg = 'Bien joué ! C\'était un $nextCard (Série : $_streak)';
      FeedbackService.triggerSuccess();
    } else {
      _streak = 0;
      _msg = 'Perdu ! C\'était un $nextCard.';
      FeedbackService.triggerImpact();
    }

    setState(() => _currentCard = nextCard);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10172D),
        title: Text('HI-LO CARTE (Série : $_streak | Record : $_bestStreak)', style: const TextStyle(color: Color(0xFFFFD166), fontSize: 15)),
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 30),
            Container(
              width: 120,
              height: 170,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 16)]),
              child: Center(
                child: Text('$_currentCard', style: const TextStyle(color: Colors.black, fontSize: 52, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _guess(higher: false),
                  icon: const Icon(Icons.arrow_downward, color: Colors.black),
                  label: const Text('PLUS BAS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2A6D), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                ),
                ElevatedButton.icon(
                  onPressed: () => _guess(higher: true),
                  icon: const Icon(Icons.arrow_upward, color: Colors.black),
                  label: const Text('PLUS HAUT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF05FFA1), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
