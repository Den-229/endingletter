import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/storage_service.dart';

class Brick {
  Rect rect;
  Color color;
  int points;
  bool isDestroyed = false;

  Brick({required this.rect, required this.color, required this.points});
}

class BrickBreakerScreen extends StatefulWidget {
  const BrickBreakerScreen({super.key});

  @override
  State<BrickBreakerScreen> createState() => _BrickBreakerScreenState();
}

class _BrickBreakerScreenState extends State<BrickBreakerScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  double _paddleX = 0.5; // 0..1
  Offset _ballPos = const Offset(0.5, 0.7);
  Offset _ballVel = const Offset(0.3, -0.45);
  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  bool _isPlaying = false;
  bool _isGameOver = false;
  double _lastTimestamp = 0;

  final List<Brick> _bricks = [];

  @override
  void initState() {
    super.initState();
    _highScore = StorageService.getBricksHighScore();
    _initBricks();
    _ticker = AnimationController.unbounded(vsync: this)..addListener(_onTick);
    _ticker.repeat(period: const Duration(days: 1));
  }

  void _initBricks() {
    _bricks.clear();
    const rows = 5;
    const cols = 7;
    const brickHeight = 22.0;
    final colors = [
      const Color(0xFFFF2A6D),
      const Color(0xFFFFD166),
      const Color(0xFF00F0FF),
      const Color(0xFF05FFA1),
      const Color(0xFFE056FD),
    ];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // Coordonnées normalisées
        final left = 0.05 + c * (0.90 / cols);
        final top = 0.12 + r * 0.055;
        final w = (0.90 / cols) - 0.015;
        _bricks.add(Brick(
          rect: Rect.fromLTWH(left, top, w, brickHeight / 600.0),
          color: colors[r],
          points: (rows - r) * 20,
        ));
      }
    }
  }

  void _startGame() {
    setState(() {
      _paddleX = 0.5;
      _ballPos = const Offset(0.5, 0.7);
      _ballVel = const Offset(0.32, -0.52);
      _score = 0;
      _lives = 3;
      _isGameOver = false;
      _isPlaying = true;
      _initBricks();
    });
    FeedbackService.triggerLight();
  }

  void _onTick() {
    if (!_isPlaying || _isGameOver) return;

    final currentMs = _ticker.lastElapsedDuration?.inMicroseconds ?? 0;
    if (_lastTimestamp == 0) {
      _lastTimestamp = currentMs.toDouble();
      return;
    }
    double dt = (currentMs - _lastTimestamp) / 1000000.0;
    _lastTimestamp = currentMs.toDouble();
    if (dt > 0.1) dt = 0.033;

    setState(() {
      // Déplacement balle
      _ballPos += _ballVel * dt;

      // Rebond murs latéraux
      if (_ballPos.dx <= 0.02) {
        _ballPos = Offset(0.02, _ballPos.dy);
        _ballVel = Offset(-_ballVel.dx, _ballVel.dy);
        FeedbackService.triggerLight();
      } else if (_ballPos.dx >= 0.98) {
        _ballPos = Offset(0.98, _ballPos.dy);
        _ballVel = Offset(-_ballVel.dx, _ballVel.dy);
        FeedbackService.triggerLight();
      }

      // Rebond plafond
      if (_ballPos.dy <= 0.05) {
        _ballPos = Offset(_ballPos.dx, 0.05);
        _ballVel = Offset(_ballVel.dx, -_ballVel.dy);
        FeedbackService.triggerLight();
      }

      // Rebond Raquette (Y = 0.88, largeur = 0.22)
      const paddleY = 0.88;
      const paddleHalfW = 0.11;
      if (_ballPos.dy >= paddleY - 0.02 &&
          _ballPos.dy <= paddleY + 0.02 &&
          _ballVel.dy > 0 &&
          (_ballPos.dx - _paddleX).abs() < paddleHalfW) {
        // Angle selon impact sur la raquette
        final hitFactor = (_ballPos.dx - _paddleX) / paddleHalfW; // -1..1
        _ballVel = Offset(hitFactor * 0.6, -(_ballVel.dy.abs()));
        FeedbackService.triggerImpact();
      }

      // Perte de balle en bas
      if (_ballPos.dy > 0.98) {
        _lives--;
        FeedbackService.triggerImpact();
        if (_lives <= 0) {
          _isGameOver = true;
          _isPlaying = false;
        } else {
          // Relance
          _ballPos = Offset(_paddleX, 0.7);
          _ballVel = const Offset(0.28, -0.48);
        }
      }

      // Collision Briques
      for (final b in _bricks.where((b) => !b.isDestroyed)) {
        if (b.rect.contains(_ballPos)) {
          b.isDestroyed = true;
          _ballVel = Offset(_ballVel.dx, -_ballVel.dy);
          _score += b.points;
          StorageService.saveBricksHighScore(_score);
          _highScore = math.max(_highScore, _score);
          FeedbackService.triggerSuccess();
          break;
        }
      }

      // Toutes briques détruites : rechargement
      if (_bricks.every((b) => b.isDestroyed)) {
        _initBricks();
        _ballVel = Offset(_ballVel.dx * 1.1, _ballVel.dy * 1.1);
      }
    });
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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'CASSE-BRIQUES RÉTRO',
          style: TextStyle(
            color: Color(0xFF00FFCC),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              setState(() => _paddleX = (_paddleX - 0.06).clamp(0.12, 0.88));
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              setState(() => _paddleX = (_paddleX + 0.06).clamp(0.12, 0.88));
            }
          }
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          onPanUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              final localX = details.localPosition.dx / box.size.width;
              setState(() => _paddleX = localX.clamp(0.12, 0.88));
            }
          },
          child: Stack(
            children: [
              // Rendu Canvas du Casse-Briques
              Positioned.fill(
                child: CustomPaint(
                  painter: _BrickPainter(
                    paddleX: _paddleX,
                    ballPos: _ballPos,
                    bricks: _bricks,
                  ),
                ),
              ),

              // HUD
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SCORE : $_score', style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 16, fontWeight: FontWeight.w900)),
                    Row(
                      children: List.generate(
                        3,
                        (i) => Icon(
                          Icons.favorite,
                          color: i < _lives ? const Color(0xFFFF2A6D) : Colors.white12,
                          size: 20,
                        ),
                      ),
                    ),
                    Text('RECORD : $_highScore', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),

              if (!_isPlaying && !_isGameOver)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _startGame,
                    icon: const Icon(Icons.play_arrow, color: Colors.black),
                    label: const Text('LANCER LA BALLE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFCC), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  ),
                ),

              if (_isGameOver)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D36),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.redAccent, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('PARTIE TERMINÉE', style: TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        Text('Score : $_score | Record : $_highScore', style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: _startGame,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFCC)),
                          child: const Text('REJOUER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrickPainter extends CustomPainter {
  final double paddleX;
  final Offset ballPos;
  final List<Brick> bricks;

  _BrickPainter({required this.paddleX, required this.ballPos, required this.bricks});

  @override
  void paint(Canvas canvas, Size size) {
    // Fond cyber avec dégradé sombre
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F172E), Color(0xFF060A14)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Briques biseautées avec reflet
    for (final b in bricks.where((b) => !b.isDestroyed)) {
      final rect = Rect.fromLTWH(
        b.rect.left * size.width,
        b.rect.top * size.height,
        b.rect.width * size.width,
        b.rect.height * size.height,
      );

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));
      final fillPaint = Paint()
        ..shader = LinearGradient(
          colors: [b.color, b.color.withValues(alpha: 0.75)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect);
      canvas.drawRRect(rrect, fillPaint);

      // Bordure brillante
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(rrect, borderPaint);
    }

    // Raquette néon avec lueur et barre centrale
    const paddleWidthRelative = 0.22;
    final paddleRect = Rect.fromCenter(
      center: Offset(paddleX * size.width, 0.88 * size.height),
      width: paddleWidthRelative * size.width,
      height: 14.0,
    );

    // Lueur raquette
    final paddleGlow = Paint()
      ..color = const Color(0xFF00FFCC).withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(RRect.fromRectAndRadius(paddleRect, const Radius.circular(7)), paddleGlow);

    // Corps raquette
    final paddlePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00FFCC), Color(0xFF00B0FF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(paddleRect);
    canvas.drawRRect(RRect.fromRectAndRadius(paddleRect, const Radius.circular(7)), paddlePaint);

    // Reflet blanc au centre de la raquette
    final reflectorRect = Rect.fromCenter(
      center: Offset(paddleX * size.width, 0.88 * size.height),
      width: paddleWidthRelative * size.width * 0.5,
      height: 4.0,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(reflectorRect, const Radius.circular(2)), Paint()..color = Colors.white.withValues(alpha: 0.8));

    // Balle lumineuse avec halo néon
    final ballPixel = Offset(ballPos.dx * size.width, ballPos.dy * size.height);
    final ballGlow = Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(ballPixel, 14.0, ballGlow);

    final ballPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.white, Color(0xFFFFD166)],
        center: Alignment(-0.2, -0.2),
      ).createShader(Rect.fromCircle(center: ballPixel, radius: 8));
    canvas.drawCircle(ballPixel, 8.0, ballPaint);
  }

  @override
  bool shouldRepaint(covariant _BrickPainter oldDelegate) => true;
}

