import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';

class PipeObstacle {
  double x;
  final double topHeight;
  final double gap;
  bool passed = false;

  PipeObstacle({required this.x, required this.topHeight, this.gap = 160.0});
}

class FlappyScreen extends StatefulWidget {
  const FlappyScreen({super.key});

  @override
  State<FlappyScreen> createState() => _FlappyScreenState();
}

class _FlappyScreenState extends State<FlappyScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  double _birdY = 0.5; // Coordonnée normalisée 0..1
  double _velocity = 0.0;
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  int _highScore = 0;
  double _lastTimestamp = 0;

  final List<PipeObstacle> _pipes = [];
  double _pipeSpawnTimer = 0.0;
  final math.Random _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _highScore = StorageService.getFlappyHighScore();
    _ticker = AnimationController.unbounded(vsync: this)..addListener(_onTick);
    _ticker.repeat(period: const Duration(days: 1));
  }

  void _startGame() {
    setState(() {
      _birdY = 0.5;
      _velocity = -0.32;
      _pipes.clear();
      _score = 0;
      _isGameOver = false;
      _isPlaying = true;
      _pipeSpawnTimer = 0.0;
    });
    FeedbackService.triggerLight();
  }

  void _flap() {
    if (_isGameOver) return;
    if (!_isPlaying) {
      _startGame();
      return;
    }
    setState(() {
      _velocity = -0.42; // Impulsion de saut
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
      // Gravité
      _velocity += 1.25 * dt;
      _birdY += _velocity * dt;

      // Sol & Plafond
      if (_birdY <= 0.0 || _birdY >= 0.95) {
        _triggerGameOver();
        return;
      }

      // Génération tuyaux
      _pipeSpawnTimer += dt;
      if (_pipeSpawnTimer > 1.8) {
        _pipeSpawnTimer = 0.0;
        final topH = 80.0 + _rnd.nextDouble() * 180.0;
        _pipes.add(PipeObstacle(x: 1.2, topHeight: topH));
      }

      // Déplacement tuyaux
      for (final p in _pipes) {
        p.x -= 0.35 * dt;

        // Détection de passage pour point
        if (!p.passed && p.x < 0.25) {
          p.passed = true;
          _score++;
          StorageService.saveFlappyHighScore(_score);
          _highScore = math.max(_highScore, _score);
          FeedbackService.triggerSuccess();
        }

        // Collision avec l'oiseau (Position X oiseau = 0.25)
        if (p.x > 0.12 && p.x < 0.38) {
          // Calculer limites Y de l'ouverture
          // La hauteur de l'écran en unités relatives : topHeight / totalHeight
          final birdPixelY = _birdY * 600.0;
          if (birdPixelY < p.topHeight || birdPixelY > (p.topHeight + p.gap)) {
            _triggerGameOver();
            return;
          }
        }
      }

      _pipes.removeWhere((p) => p.x < -0.3);
    });
  }

  void _triggerGameOver() {
    _isGameOver = true;
    _isPlaying = false;
    FeedbackService.triggerImpact();
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
          'CYBER FLAP NÉON',
          style: TextStyle(
            color: Color(0xFFFFD166),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _flap,
        child: Stack(
          children: [
            // Décor & Tuyaux
            Positioned.fill(
              child: CustomPaint(
                painter: _FlappyPainter(
                  birdY: _birdY,
                  velocity: _velocity,
                  pipes: _pipes,
                ),
              ),
            ),

            // Score HUD en haut
            Positioned(
              top: 30,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Color(0xFFFFD166), blurRadius: 16)],
                    ),
                  ),
                  Text(
                    'RECORD : $_highScore',
                    style: const TextStyle(
                      color: Color(0xFFFFD166),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Message pour démarrer
            if (!_isPlaying && !_isGameOver)
              const Center(
                child: Text(
                  'TOUCHEZ L\'ÉCRAN POUR VOLER ! 🚀',
                  style: TextStyle(
                    color: Color(0xFF00FFCC),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

            // Modal Game Over
            if (_isGameOver)
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D36),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF2A6D), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2A6D).withValues(alpha: 0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'CRASH !',
                        style: TextStyle(
                          color: Color(0xFFFF2A6D),
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Score : $_score | Meilleur : $_highScore', style: const TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _startGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD166),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('REJOUER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FlappyPainter extends CustomPainter {
  final double birdY;
  final double velocity;
  final List<PipeObstacle> pipes;

  _FlappyPainter({required this.birdY, required this.velocity, required this.pipes});

  @override
  void paint(Canvas canvas, Size size) {
    // Fond cyber galactique avec étoiles scintillantes
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F1B35), Color(0xFF090D1A), Color(0xFF03050A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Étoiles de fond
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.4);
    for (int i = 0; i < 25; i++) {
      final sx = ((i * 73) % size.width.toInt()).toDouble();
      final sy = ((i * 97) % (size.height * 0.8).toInt()).toDouble();
      canvas.drawCircle(Offset(sx, sy), (i % 3 == 0) ? 1.5 : 1.0, starPaint);
    }

    // Dessin des Tuyaux néon avec collerettes / rebords 3D
    const pipeWidth = 58.0;
    const rimWidth = 66.0;
    const rimHeight = 22.0;

    for (final p in pipes) {
      final px = p.x * size.width;

      // 1. Tuyau supérieur (corps)
      final topRect = Rect.fromLTWH(px, 0, pipeWidth, (p.topHeight - rimHeight).clamp(0, size.height));
      final topGradient = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF00C853), Color(0xFF05FFA1), Color(0xFF009624)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(topRect);
      canvas.drawRect(topRect, topGradient);

      // Collerette supérieure
      final topRimRect = Rect.fromLTWH(px - (rimWidth - pipeWidth) / 2, p.topHeight - rimHeight, rimWidth, rimHeight);
      final rimGradient = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF69F0AE), Color(0xFF05FFA1), Color(0xFF00701A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(topRimRect);
      canvas.drawRRect(RRect.fromRectAndRadius(topRimRect, const Radius.circular(6)), rimGradient);
      canvas.drawRRect(RRect.fromRectAndRadius(topRimRect, const Radius.circular(6)), Paint()..color = Colors.white.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 1.5);

      // 2. Tuyau inférieur (corps)
      final botY = p.topHeight + p.gap;
      final botRect = Rect.fromLTWH(px, botY + rimHeight, pipeWidth, (size.height - (botY + rimHeight)).clamp(0, size.height));
      final botGradient = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF00C853), Color(0xFF05FFA1), Color(0xFF009624)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(botRect);
      canvas.drawRect(botRect, botGradient);

      // Collerette inférieure
      final botRimRect = Rect.fromLTWH(px - (rimWidth - pipeWidth) / 2, botY, rimWidth, rimHeight);
      canvas.drawRRect(RRect.fromRectAndRadius(botRimRect, const Radius.circular(6)), rimGradient);
      canvas.drawRRect(RRect.fromRectAndRadius(botRimRect, const Radius.circular(6)), Paint()..color = Colors.white.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }

    // Dessin de l'Oiseau Drone Cyber
    final birdX = size.width * 0.25;
    final birdPixelY = birdY * size.height;

    canvas.save();
    canvas.translate(birdX, birdPixelY);
    final rot = (velocity * 1.5).clamp(-0.6, 0.7);
    canvas.rotate(rot);

    // Halo lumineux
    final glow = Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset.zero, 24, glow);

    // Corps de l'oiseau
    final birdBody = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFF176), Color(0xFFFFD166), Color(0xFFFF8F00)],
        center: Alignment(-0.2, -0.2),
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 18));
    canvas.drawCircle(Offset.zero, 18, birdBody);

    // Bec orange
    final beakPath = Path()
      ..moveTo(14, -4)
      ..lineTo(24, 1)
      ..lineTo(14, 6)
      ..close();
    canvas.drawPath(beakPath, Paint()..color = const Color(0xFFFF3D00));

    // Œil brillant avec reflet
    canvas.drawCircle(const Offset(6, -5), 5.5, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(7, -5), 3.0, Paint()..color = const Color(0xFF10172D));
    canvas.drawCircle(const Offset(6, -6), 1.2, Paint()..color = Colors.white);

    // Aile animée
    final wingOffsetY = (math.sin(velocity * 8) * 4).toDouble();
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-6, 3 + wingOffsetY), width: 15, height: 9),
      Paint()..color = const Color(0xFFFF6D00),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlappyPainter oldDelegate) => true;
}
