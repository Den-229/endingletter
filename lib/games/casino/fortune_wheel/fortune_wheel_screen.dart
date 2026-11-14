import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';

class FortuneWheelScreen extends StatefulWidget {
  const FortuneWheelScreen({super.key});

  @override
  State<FortuneWheelScreen> createState() => _FortuneWheelScreenState();
}

class _FortuneWheelScreenState extends State<FortuneWheelScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  double _currentAngle = 0.0;
  bool _isSpinning = false;
  String _rewardText = 'Faites tourner la roue pour gagner des récompenses !';

  final List<Map<String, dynamic>> _sectors = [
    {'label': '+100 XP', 'color': const Color(0xFF00FFCC), 'xp': 100},
    {'label': '+50 XP', 'color': const Color(0xFF00F0FF), 'xp': 50},
    {'label': 'JACKPOT 1000', 'color': const Color(0xFFFFD166), 'xp': 1000},
    {'label': '+200 XP', 'color': const Color(0xFFE056FD), 'xp': 200},
    {'label': '+50 XP', 'color': const Color(0xFF05FFA1), 'xp': 50},
    {'label': 'REPLAY !', 'color': const Color(0xFFFF2A6D), 'xp': 0},
    {'label': '+300 XP', 'color': const Color(0xFFFF9F1C), 'xp': 300},
    {'label': '+150 XP', 'color': const Color(0xFF7000FF), 'xp': 150},
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  void _spin() {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _rewardText = 'La roue tourne...';
    });
    FeedbackService.triggerLight();

    final rnd = math.Random();
    // 5 à 8 tours complets + angle aléatoire
    final extraRounds = 5 + rnd.nextInt(4);
    final targetSector = rnd.nextInt(_sectors.length);
    final sectorAngle = (2 * math.pi) / _sectors.length;
    final finalAngle = _currentAngle + (extraRounds * 2 * math.pi) + (targetSector * sectorAngle);

    final animation = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    final startAngle = _currentAngle;

    _animCtrl.reset();
    animation.addListener(() {
      setState(() {
        _currentAngle = startAngle + (finalAngle - startAngle) * animation.value;
      });
    });

    _animCtrl.forward().then((_) {
      final reward = _sectors[targetSector];
      final xp = reward['xp'] as int;
      if (xp > 0) {
        StorageService.saveHighScore('fortune_wheel', xp);
      }

      setState(() {
        _isSpinning = false;
        _rewardText = '🎉 FÉLICITATIONS : GAGNÉ ${reward['label']} !';
      });
      FeedbackService.triggerSuccess();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
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
          'ROUE DE LA FORTUNE NÉON',
          style: TextStyle(color: Color(0xFFFFD166), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _rewardText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),

            // Roue animée
            Center(
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Transform.rotate(
                    angle: _currentAngle,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
                      ),
                      child: CustomPaint(
                        painter: _WheelPainter(sectors: _sectors),
                      ),
                    ),
                  ),

                  // Aiguille flèche au sommet
                  Positioned(
                    top: -6,
                    child: Container(
                      width: 22,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                        boxShadow: [BoxShadow(color: Colors.white70, blurRadius: 8)],
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_drop_down, color: Colors.black, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Bouton Tourner
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: ElevatedButton.icon(
                onPressed: _isSpinning ? null : _spin,
                icon: const Icon(Icons.rotate_right, color: Colors.black),
                label: Text(
                  _isSpinning ? 'EN ROTATION...' : 'LANCER LA ROUE !',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD166),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> sectors;

  _WheelPainter({required this.sectors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * math.pi) / sectors.length;

    for (int i = 0; i < sectors.length; i++) {
      final startAngle = i * sweepAngle;
      final paint = Paint()..color = sectors[i]['color'] as Color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Bordure de secteur
      final borderPaint = Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );
    }

    // Moyeu central
    canvas.drawCircle(center, 28, Paint()..color = const Color(0xFF10172D));
    canvas.drawCircle(center, 28, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}
