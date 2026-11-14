import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';
import 'car_models.dart';

enum GearShifter { park, reverse, neutral, drive }

class DrParkingView extends StatefulWidget {
  final RacingVehicle vehicle;
  final VoidCallback onLevelComplete;

  const DrParkingView({
    super.key,
    required this.vehicle,
    required this.onLevelComplete,
  });

  @override
  State<DrParkingView> createState() => _DrParkingViewState();
}

class _DrParkingViewState extends State<DrParkingView> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  double _lastTimestamp = 0;

  // Position et physique de la voiture
  double _carX = 0.5;
  double _carY = 0.75;
  double _carAngle = -math.pi / 2; // Orientée vers le haut
  double _speed = 0.0;
  double _steeringAngle = 0.0; // -1.0 (gauche) à +1.0 (droite)

  GearShifter _gear = GearShifter.drive;
  bool _isAccelerating = false;
  bool _isBraking = false;
  int _collisionCount = 0;
  bool _isParked = false;
  double _proximityAlarm = 0.0;

  // Zone de stationnement cible
  final Rect _parkingSlot = const Rect.fromLTWH(0.35, 0.18, 0.30, 0.16);

  // Obstacles (Cones et voitures garées)
  final List<Rect> _obstacles = [
    const Rect.fromLTWH(0.10, 0.18, 0.22, 0.16), // Voiture gauche
    const Rect.fromLTWH(0.68, 0.18, 0.22, 0.16), // Voiture droite
    const Rect.fromLTWH(0.05, 0.45, 0.08, 0.08), // Cône 1
    const Rect.fromLTWH(0.87, 0.45, 0.08, 0.08), // Cône 2
    const Rect.fromLTWH(0.46, 0.48, 0.08, 0.08), // Cône médian
  ];

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_onTick)
      ..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick() {
    if (_isParked) return;

    final currentMs = _ticker.lastElapsedDuration?.inMicroseconds ?? 0;
    if (_lastTimestamp == 0) {
      _lastTimestamp = currentMs.toDouble();
      return;
    }
    double dt = (currentMs - _lastTimestamp) / 1000000.0;
    _lastTimestamp = currentMs.toDouble();
    if (dt <= 0 || dt > 0.1) dt = 0.033;

    setState(() {
      // 1. Accélération / Freinage selon vitesse et levier de vitesse
      if (_isBraking) {
        _speed *= math.max(0.0, 1.0 - 5.0 * dt);
      } else if (_isAccelerating) {
        if (_gear == GearShifter.drive) {
          _speed = math.min(_speed + 0.35 * dt, 0.25);
        } else if (_gear == GearShifter.reverse) {
          _speed = math.max(_speed - 0.25 * dt, -0.15);
        }
      } else {
        // Décélération naturelle (friction)
        _speed *= math.max(0.0, 1.0 - 1.5 * dt);
      }

      if (_gear == GearShifter.park || _gear == GearShifter.neutral) {
        _speed *= 0.90;
      }

      // 2. Rotation & Déplacement cinématique
      _carAngle += _speed * _steeringAngle * 2.8 * dt;
      _carX += math.cos(_carAngle) * _speed * dt;
      _carY += math.sin(_carAngle) * _speed * dt;

      // Limites du parking
      _carX = _carX.clamp(0.06, 0.94);
      _carY = _carY.clamp(0.08, 0.92);

      // 3. Détection de proximité des obstacles
      final carRect = Rect.fromCenter(center: Offset(_carX, _carY), width: 0.10, height: 0.16);
      double minObstacleDist = 999.0;

      for (final obs in _obstacles) {
        if (carRect.overlaps(obs)) {
          // Collision !
          _speed = -_speed * 0.5;
          _collisionCount++;
          FeedbackService.triggerImpact();
          break;
        }
        final dist = (Offset(_carX, _carY) - obs.center).distance;
        minObstacleDist = math.min(minObstacleDist, dist);
      }

      _proximityAlarm = (1.0 - (minObstacleDist / 0.25)).clamp(0.0, 1.0);

      // 4. Détection du stationnement parfait
      final inSlot = _parkingSlot.contains(Offset(_carX, _carY));
      final isStopped = _speed.abs() < 0.01;
      final isWellAligned = (_carAngle + math.pi / 2).abs() < 0.25 || (_carAngle - 3 * math.pi / 2).abs() < 0.25;

      if (inSlot && isStopped && isWellAligned && _gear == GearShifter.park) {
        _isParked = true;
        FeedbackService.triggerSuccess();
        widget.onLevelComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Arène de Parking (Canvas 2D avec vue du dessus réaliste)
        Expanded(
          flex: 5,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            decoration: BoxDecoration(
              color: const Color(0xFF141926),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 16),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: _ParkingArenaPainter(
                      parkingSlot: _parkingSlot,
                      obstacles: _obstacles,
                      carX: _carX,
                      carY: _carY,
                      carAngle: _carAngle,
                      vehicleColor: widget.vehicle.primaryColor,
                    ),
                  ),

                  // Télémetrie & Chocs HUD
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _collisionCount > 0 ? Icons.car_crash : Icons.shield_outlined,
                            size: 14,
                            color: _collisionCount > 0 ? Colors.amberAccent : const Color(0xFF00FFCC),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Chocs : $_collisionCount',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Alarme de proximité radar HUD
                  if (_proximityAlarm > 0.3)
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0055).withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('RADAR DE RECUL : OBSTACLE PROCHE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Succès Parking validé
                  if (_isParked)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2618),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF00FFCC), width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 20)],
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF00FFCC), size: 48),
                            SizedBox(height: 8),
                            Text('STATIONNEMENT PARFAIT !', style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.w900, fontSize: 18)),
                            Text('Créneau réussi avec précision • +100 XP', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Tableau de bord de conduite (Volant rotatif, Levier PRND, Pédales)
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: const Color(0xFF0A0E1A),
            child: Row(
              children: [
                // 1. Volant interactif (Steering Wheel)
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            _steeringAngle = (_steeringAngle + details.delta.dx * 0.02).clamp(-1.0, 1.0);
                          });
                        },
                        onPanEnd: (_) {
                          // Retour automatique au centre
                          setState(() => _steeringAngle = 0.0);
                        },
                        child: Transform.rotate(
                          angle: _steeringAngle * 1.5,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [Color(0xFF2C3E50), Color(0xFF0F1524), Color(0xFF060912)],
                              ),
                              border: Border.all(color: const Color(0xFF00FFCC), width: 3),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF00FFCC).withValues(alpha: 0.3), blurRadius: 14),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(Icons.circle_outlined, color: Colors.white24, size: 70),
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: const BoxDecoration(color: Color(0xFF00FFCC), shape: BoxShape.circle),
                                ),
                                Positioned(
                                  top: 10,
                                  child: Container(width: 6, height: 16, color: Colors.amberAccent),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('GLISSEZ LE VOLANT', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // 2. Boîte de vitesses PRND (Gear Shifter)
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13192B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildGearButton('P', GearShifter.park),
                        _buildGearButton('R', GearShifter.reverse),
                        _buildGearButton('N', GearShifter.neutral),
                        _buildGearButton('D', GearShifter.drive),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // 3. Pédales de Frein et d'Accélérateur
                Expanded(
                  flex: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Frein
                      GestureDetector(
                        onTapDown: (_) => setState(() => _isBraking = true),
                        onTapUp: (_) => setState(() => _isBraking = false),
                        onTapCancel: () => setState(() => _isBraking = false),
                        child: Container(
                          width: 48,
                          height: 90,
                          decoration: BoxDecoration(
                            color: _isBraking ? const Color(0xFFFF0055) : const Color(0xFF263238),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.pan_tool, color: Colors.white70, size: 20),
                              SizedBox(height: 4),
                              Text('FREIN', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),

                      // Accélérateur
                      GestureDetector(
                        onTapDown: (_) => setState(() => _isAccelerating = true),
                        onTapUp: (_) => setState(() => _isAccelerating = false),
                        onTapCancel: () => setState(() => _isAccelerating = false),
                        child: Container(
                          width: 48,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: _isAccelerating
                                ? const LinearGradient(colors: [Color(0xFF00FFCC), Color(0xFF009688)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                                : null,
                            color: _isAccelerating ? null : const Color(0xFF37474F),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.speed, color: Colors.white, size: 24),
                              SizedBox(height: 6),
                              Text('GAZ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGearButton(String label, GearShifter g) {
    final isSelected = _gear == g;
    return GestureDetector(
      onTap: () {
        FeedbackService.triggerLight();
        setState(() => _gear = g);
      },
      child: Container(
        width: 38,
        height: 24,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00FFCC) : Colors.black26,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white60,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ParkingArenaPainter extends CustomPainter {
  final Rect parkingSlot;
  final List<Rect> obstacles;
  final double carX;
  final double carY;
  final double carAngle;
  final Color vehicleColor;

  _ParkingArenaPainter({
    required this.parkingSlot,
    required this.obstacles,
    required this.carX,
    required this.carY,
    required this.carAngle,
    required this.vehicleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Marquage au sol du parking
    final linePaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Lignes de couloirs
    canvas.drawLine(Offset(0, size.height * 0.40), Offset(size.width, size.height * 0.40), linePaint);
    canvas.drawLine(Offset(0, size.height * 0.65), Offset(size.width, size.height * 0.65), linePaint);

    // 2. Zone de créneau cible (Vert fluo clignotant)
    final targetPixelRect = Rect.fromLTWH(
      parkingSlot.left * size.width,
      parkingSlot.top * size.height,
      parkingSlot.width * size.width,
      parkingSlot.height * size.height,
    );
    final targetPaint = Paint()
      ..color = const Color(0xFF00FFCC).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(targetPixelRect, const Radius.circular(8)), targetPaint);

    final targetBorder = Paint()
      ..color = const Color(0xFF00FFCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(RRect.fromRectAndRadius(targetPixelRect, const Radius.circular(8)), targetBorder);

    // P dans la zone
    const pSpan = TextSpan(text: 'P', style: TextStyle(color: Color(0xFF00FFCC), fontSize: 28, fontWeight: FontWeight.w900));
    final pPainter = TextPainter(text: pSpan, textDirection: TextDirection.ltr)..layout();
    pPainter.paint(canvas, targetPixelRect.center - Offset(pPainter.width / 2, pPainter.height / 2));

    // 3. Dessin des obstacles (voitures garées et cônes de signalisation)
    for (final obs in obstacles) {
      final obsPixel = Rect.fromLTWH(
        obs.left * size.width,
        obs.top * size.height,
        obs.width * size.width,
        obs.height * size.height,
      );

      if (obs.width > 0.15) {
        // Voiture garée
        canvas.drawRRect(
          RRect.fromRectAndRadius(obsPixel, const Radius.circular(8)),
          Paint()..color = const Color(0xFF34495E),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(obsPixel.deflate(4), const Radius.circular(6)),
          Paint()..color = const Color(0xFF2C3E50),
        );
      } else {
        // Cône de signalisation orange
        canvas.drawCircle(obsPixel.center, obsPixel.width * 0.4, Paint()..color = const Color(0xFFFF5722));
        canvas.drawCircle(obsPixel.center, obsPixel.width * 0.2, Paint()..color = Colors.white);
      }
    }

    // 4. Dessin de la voiture du joueur avec orientation dynamique
    canvas.save();
    final carPx = carX * size.width;
    final carPy = carY * size.height;
    canvas.translate(carPx, carPy);
    canvas.rotate(carAngle + math.pi / 2); // Ajustement de l'axe vers l'avant

    final carWidth = size.width * 0.11;
    final carHeight = size.height * 0.14;
    final carRect = Rect.fromCenter(center: Offset.zero, width: carWidth, height: carHeight);

    // Ombre sous la voiture
    canvas.drawRRect(
      RRect.fromRectAndRadius(carRect.shift(const Offset(3, 4)), const Radius.circular(8)),
      Paint()..color = Colors.black45,
    );

    // Carrosserie
    final bodyPaint = Paint()..color = vehicleColor;
    canvas.drawRRect(RRect.fromRectAndRadius(carRect, const Radius.circular(8)), bodyPaint);

    // Pare-brise et vitres
    final windshieldRect = Rect.fromCenter(center: const Offset(0, -6), width: carWidth * 0.75, height: carHeight * 0.35);
    canvas.drawRRect(RRect.fromRectAndRadius(windshieldRect, const Radius.circular(4)), Paint()..color = const Color(0xFF1A2530));

    // Phares avant jaunes
    canvas.drawCircle(Offset(-carWidth * 0.35, -carHeight * 0.45), 3, Paint()..color = const Color(0xFFFFEB3B));
    canvas.drawCircle(Offset(carWidth * 0.35, -carHeight * 0.45), 3, Paint()..color = const Color(0xFFFFEB3B));

    // Feux arrière rouges
    canvas.drawCircle(Offset(-carWidth * 0.35, carHeight * 0.45), 3, Paint()..color = const Color(0xFFFF1744));
    canvas.drawCircle(Offset(carWidth * 0.35, carHeight * 0.45), 3, Paint()..color = const Color(0xFFFF1744));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ParkingArenaPainter oldDelegate) => true;
}
