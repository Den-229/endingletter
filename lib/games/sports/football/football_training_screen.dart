import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/confetti_overlay.dart';

class FootballTrainingScreen extends StatefulWidget {
  const FootballTrainingScreen({super.key});

  @override
  State<FootballTrainingScreen> createState() => _FootballTrainingScreenState();
}

class _FootballTrainingScreenState extends State<FootballTrainingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _shotController;
  Offset _ballPos = const Offset(0.50, 0.85); // Point de penalty
  Offset _shotTarget = const Offset(0.50, 0.85);
  Offset _gkPos = const Offset(0.50, 0.38); // Position du gardien sur la ligne
  Offset _gkDiveTarget = const Offset(0.50, 0.38);

  bool _isShooting = false;
  String _feedbackMessage = 'GLISSEZ LE DOIGT VERS LE BUT POUR TIRER !';
  Color _feedbackColor = Colors.white70;
  int _score = 0;
  int _streak = 0;
  int _shotsTaken = 0;
  bool _showVictory = false;

  @override
  void initState() {
    super.initState();
    _shotController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..addListener(_onShotTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _evaluateShot();
        }
      });
  }

  @override
  void dispose() {
    _shotController.dispose();
    super.dispose();
  }

  void _onShotTick() {
    setState(() {
      final t = Curves.easeOutQuad.transform(_shotController.value);
      _ballPos = Offset.lerp(const Offset(0.50, 0.85), _shotTarget, t)!;
      _gkPos = Offset.lerp(const Offset(0.50, 0.38), _gkDiveTarget, t)!;
    });
  }

  void _onPanStart(DragDownDetails details) {
    if (_isShooting) return;
  }

  void _onPanEnd(DragEndDetails details, Size canvasSize) {
    if (_isShooting) return;

    // Calcul de la cible du tir à partir du vecteur de vitesse du swipe
    final vel = details.velocity.pixelsPerSecond;
    if (vel.dy >= -50) {
      // Swipe trop faible ou vers le bas
      return;
    }

    // Direction horizontale normalisée
    final normalizedDx = 0.50 + (vel.dx / 1200.0).clamp(-0.40, 0.40);
    // Hauteur du tir (entre 0.15 lucarne et 0.40 ras du poteau)
    final normalizedDy = (0.35 + (vel.dy / 2500.0)).clamp(0.12, 0.42);

    _shotTarget = Offset(normalizedDx, normalizedDy);

    // Plongeon du gardien de but (aléatoire avec anticipation)
    final rnd = math.Random();
    final gkX = 0.50 + (rnd.nextDouble() * 0.50 - 0.25);
    final gkY = 0.25 + (rnd.nextDouble() * 0.15);
    _gkDiveTarget = Offset(gkX, gkY);

    setState(() {
      _isShooting = true;
      _shotsTaken++;
    });

    FeedbackService.triggerImpact();
    _shotController.forward(from: 0.0);
  }

  void _evaluateShot() {
    // Distance entre la balle et le gardien au moment du tir
    final distToGk = (_ballPos - _gkPos).distance;

    // Zone de but valide (x: 0.18 à 0.82, y: 0.14 à 0.42)
    final isInsideGoal = _shotTarget.dx >= 0.18 && _shotTarget.dx <= 0.82 && _shotTarget.dy >= 0.14 && _shotTarget.dy <= 0.42;

    if (!isInsideGoal) {
      // Hors cadre
      setState(() {
        _feedbackMessage = 'TIR NON CADRÉ ! AU-DESSUS OU À CÔTÉ';
        _feedbackColor = const Color(0xFFFF9F1C);
        _streak = 0;
      });
      FeedbackService.triggerLight();
    } else if (distToGk < 0.10) {
      // Arrêt du gardien
      setState(() {
        _feedbackMessage = 'ARRÊT EXCEPTIONNEL DU GARDIEN ! 🧤';
        _feedbackColor = const Color(0xFFFF0055);
        _streak = 0;
      });
      FeedbackService.triggerImpact();
    } else {
      // BUT !
      final isTopCorner = (_shotTarget.dx < 0.30 || _shotTarget.dx > 0.70) && _shotTarget.dy < 0.22;
      final points = isTopCorner ? 100 : 50;

      setState(() {
        _score += points;
        _streak++;
        _feedbackMessage = isTopCorner ? 'PLEINE LUCARNE ! +$points PTS 🎯' : 'GOOOOOAL ! +$points PTS ⚽';
        _feedbackColor = const Color(0xFF00FFCC);
      });

      FeedbackService.triggerSuccess();

      if (_streak >= 3) {
        setState(() => _showVictory = true);
        StorageService.recordGamePlayed('training_goal');
      }
    }

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _isShooting = false;
        _ballPos = const Offset(0.50, 0.85);
        _gkPos = const Offset(0.50, 0.38);
        _feedbackMessage = 'GLISSEZ LE DOIGT VERS LE BUT POUR TIRER !';
        _feedbackColor = Colors.white70;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'TIRS AU BUT & COUPS FRANCS',
          style: TextStyle(
            color: Color(0xFF00FFCC),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: ConfettiOverlay(
        showCelebration: _showVictory,
        title: 'SÉRIE DE BUTS INCROYABLE ! 🏆',
        subtitle: '3 buts consécutifs • +150 XP enregistrés',
        onDismiss: () => setState(() => _showVictory = false),
        child: SafeArea(
          child: Column(
            children: [
              // HUD Tableau des scores de précision
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10172D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('SCORE TOTAL', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text('$_score', style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 20, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('SÉRIE (STREAK)', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text('🔥 $_streak', style: const TextStyle(color: Color(0xFFFF9F1C), fontSize: 20, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('TIRS TENTÉS', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text('$_shotsTaken', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
              ),

              // Bannière de feedback
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _feedbackMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _feedbackColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                ),
              ),

              // Zone de penalty et cages de but 3D
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onPanDown: _onPanStart,
                      onPanEnd: (details) => _onPanEnd(details, size),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0B2B1B), Color(0xFF1A6B42), Color(0xFF0F472B)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          border: Border.all(color: Colors.white24, width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 18),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            children: [
                              CustomPaint(
                                size: Size.infinite,
                                painter: _PenaltyShootoutPainter(
                                  ballPos: _ballPos,
                                  gkPos: _gkPos,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PenaltyShootoutPainter extends CustomPainter {
  final Offset ballPos;
  final Offset gkPos;

  _PenaltyShootoutPainter({
    required this.ballPos,
    required this.gkPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Cages de but en perspective frontale (x: 0.18 à 0.82, y: 0.14 à 0.42)
    final goalLeft = size.width * 0.18;
    final goalRight = size.width * 0.82;
    final goalTop = size.height * 0.14;
    final goalBottom = size.height * 0.42;

    // Filet du but
    final netPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Quadrillage du filet
    for (double x = goalLeft; x <= goalRight; x += 18) {
      canvas.drawLine(Offset(x, goalTop), Offset(x, goalBottom), netPaint);
    }
    for (double y = goalTop; y <= goalBottom; y += 14) {
      canvas.drawLine(Offset(goalLeft, y), Offset(goalRight, y), netPaint);
    }

    // Poteaux et barre transversale
    final postPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    final postPath = Path()
      ..moveTo(goalLeft, goalBottom)
      ..lineTo(goalLeft, goalTop)
      ..lineTo(goalRight, goalTop)
      ..lineTo(goalRight, goalBottom);
    canvas.drawPath(postPath, postPaint);

    // Cibles dans les lucarnes (Target Rings)
    final targetPaint = Paint()
      ..color = const Color(0xFFFFD166).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(goalLeft + 24, goalTop + 24), 16, targetPaint);
    canvas.drawCircle(Offset(goalRight - 24, goalTop + 24), 16, targetPaint);

    // Ligne de but
    canvas.drawLine(Offset(0, goalBottom), Offset(size.width, goalBottom), Paint()..color = Colors.white70..strokeWidth = 3.0);

    // 2. Gardien de but plongeant athlétique
    final gkX = gkPos.dx * size.width;
    final gkY = gkPos.dy * size.height;

    // Calcul de l'inclinaison du corps lors du plongeon
    final diveOffset = (gkX - size.width * 0.50);
    final diveAngle = (diveOffset / (size.width * 0.35)).clamp(-0.45, 0.45);

    // Ombre sous le gardien au sol
    canvas.drawOval(
      Rect.fromCenter(center: Offset(gkX, goalBottom - 2), width: 44, height: 12),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    canvas.save();
    canvas.translate(gkX, gkY);
    canvas.rotate(diveAngle);

    // --- JAMBES DU GARDIEN (Collant de protection noir & Chaussettes fluo) ---
    final legPaint = Paint()..color = const Color(0xFF151922);
    final sockPaint = Paint()..color = const Color(0xFFFFD166);
    final bootPaint = Paint()..color = const Color(0xFF111111);

    // Jambe gauche
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-14, 6, 9, 18), const Radius.circular(3)), legPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-14, 20, 9, 10), const Radius.circular(2)), sockPaint);
    canvas.drawOval(const Rect.fromLTWH(-16, 28, 12, 6), bootPaint);

    // Jambe droite
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(5, 6, 9, 18), const Radius.circular(3)), legPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(5, 20, 9, 10), const Radius.circular(2)), sockPaint);
    canvas.drawOval(const Rect.fromLTWH(4, 28, 12, 6), bootPaint);

    // Short de gardien
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-16, 2, 32, 12), const Radius.circular(4)), legPaint);

    // --- BUSTE DU GARDIEN (Maillot manches longues rembourré) ---
    final gkJerseyGradient = LinearGradient(
      colors: const [Color(0xFFFF9F1C), Color(0xFFFF5722)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(const Rect.fromLTWH(-18, -20, 36, 26));

    final torsoPath = Path()
      ..moveTo(-18, -18) // Épaule gauche
      ..lineTo(18, -18) // Épaule droite
      ..lineTo(14, 4) // Hanche droite
      ..lineTo(-14, 4) // Hanche gauche
      ..close();

    canvas.drawPath(torsoPath, Paint()..shader = gkJerseyGradient);
    canvas.drawPath(torsoPath, Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Col noir
    canvas.drawCircle(const Offset(0, -18), 5.0, Paint()..color = const Color(0xFF151922));

    // Numéro 1 sur le maillot
    final numSpan = const TextSpan(
      text: '1',
      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
    );
    final numPainter = TextPainter(text: numSpan, textDirection: TextDirection.ltr)..layout();
    numPainter.paint(canvas, Offset(-numPainter.width / 2, -12));

    // --- BRAS TENDUS & GANTS DE GARDIEN PROFESSIONNELS ---
    final armColor = const Color(0xFFFF9F1C);
    // Bras gauche tendu
    final leftArmPath = Path()
      ..moveTo(-18, -16)
      ..lineTo(-30, -28)
      ..lineTo(-26, -32)
      ..lineTo(-14, -14)
      ..close();
    canvas.drawPath(leftArmPath, Paint()..color = armColor);

    // Bras droit tendu
    final rightArmPath = Path()
      ..moveTo(18, -16)
      ..lineTo(30, -28)
      ..lineTo(26, -32)
      ..lineTo(14, -14)
      ..close();
    canvas.drawPath(rightArmPath, Paint()..color = armColor);

    // Gants de gardien (Latex blanc paume + dos fluo avec lanière de poignet)
    // Gant gauche
    canvas.drawCircle(const Offset(-30, -32), 6.5, Paint()..color = const Color(0xFF00FFCC));
    canvas.drawCircle(const Offset(-30, -32), 4.5, Paint()..color = Colors.white);
    // Gant droit
    canvas.drawCircle(const Offset(30, -32), 6.5, Paint()..color = const Color(0xFF00FFCC));
    canvas.drawCircle(const Offset(30, -32), 4.5, Paint()..color = Colors.white);

    // --- TÊTE DU GARDIEN ---
    // Visage
    canvas.drawOval(const Rect.fromLTWH(-6.5, -31, 13, 15), Paint()..color = const Color(0xFFF0C29E));
    // Cheveux courts foncés
    final hairPath = Path()
      ..moveTo(-7, -26)
      ..quadraticBezierTo(0, -35, 7, -26)
      ..lineTo(7, -30)
      ..quadraticBezierTo(0, -37, -7, -30)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = const Color(0xFF22160E));

    canvas.restore();

    // 3. Point de penalty blanc officiel au sol
    canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.85), 6.0, Paint()..color = Colors.white);

    // 4. Ballon de football avec perspective 3D et dégradé cuir réaliste
    final bX = ballPos.dx * size.width;
    final bY = ballPos.dy * size.height;
    // Plus le ballon monte vers le but, plus sa taille diminue (effet de profondeur 3D)
    final ballScale = 1.0 - ((size.height * 0.85 - bY) / size.height * 0.65).clamp(0.0, 0.45);
    final radius = 18.0 * ballScale;

    // Ombre portée sous le ballon
    final ballElevation = (size.height * 0.85 - bY) * 0.15;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bX, bY + radius * 0.7 + ballElevation), width: radius * 2.2, height: radius * 0.8),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // Sphère 3D du ballon (éclairage stadium 3D)
    final ballCenter = Offset(bX, bY);
    final ballShader = RadialGradient(
      center: const Alignment(-0.35, -0.35),
      radius: 0.9,
      colors: const [Colors.white, Color(0xFFEEEEEE), Color(0xFF9E9E9E)],
      stops: const [0.0, 0.65, 1.0],
    ).createShader(Rect.fromCircle(center: ballCenter, radius: radius));

    canvas.drawCircle(ballCenter, radius, Paint()..shader = ballShader);
    canvas.drawCircle(ballCenter, radius, Paint()..color = Colors.black54..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Motifs géométriques pentagonaux en cuir noir
    final pentagonPaint = Paint()..color = const Color(0xFF1E1E1E);
    canvas.drawCircle(ballCenter, radius * 0.35, pentagonPaint);
    canvas.drawCircle(Offset(ballCenter.dx - radius * 0.55, ballCenter.dy - radius * 0.25), radius * 0.22, pentagonPaint);
    canvas.drawCircle(Offset(ballCenter.dx + radius * 0.55, ballCenter.dy + radius * 0.25), radius * 0.22, pentagonPaint);
    canvas.drawCircle(Offset(ballCenter.dx, ballCenter.dy - radius * 0.55), radius * 0.20, pentagonPaint);
  }

  @override
  bool shouldRepaint(covariant _PenaltyShootoutPainter oldDelegate) => true;
}
