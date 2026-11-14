import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';
import 'car_models.dart';

enum GearShifter { park, reverse, neutral, drive }

enum ParkingCameraView {
  cockpit,    // Vue Intérieure Cockpit avec Volant & Caméra de Recul
  isometric,  // Vue 3D Extérieure / Caméra Aérienne de Stationnement
}

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
  ParkingCameraView _cameraView = ParkingCameraView.cockpit; // Par défaut vue cockpit avec caméra de recul
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

      // Limites de l'arène de parking
      _carX = _carX.clamp(0.08, 0.92);
      _carY = _carY.clamp(0.08, 0.92);

      // 3. Détection des obstacles et capteurs de recul / proximité
      double minObstacleDist = 999.0;
      final carPoint = Offset(_carX, _carY);

      for (final obs in _obstacles) {
        final dist = (obs.center - carPoint).distance;
        if (dist < minObstacleDist) minObstacleDist = dist;

        // Collision physique
        if (obs.contains(carPoint)) {
          _speed = -_speed * 0.5; // Rebond
          _collisionCount++;
          FeedbackService.triggerImpact();
          break;
        }
      }

      _proximityAlarm = (1.0 - (minObstacleDist / 0.35)).clamp(0.0, 1.0);

      // 4. Détection du stationnement parfait dans la place
      if (_parkingSlot.contains(carPoint)) {
        final angleDiff = (_carAngle - (-math.pi / 2)).abs();
        if (_speed.abs() < 0.02 && _gear == GearShifter.park && angleDiff < 0.35) {
          _isParked = true;
          FeedbackService.triggerSuccess();
          widget.onLevelComplete();
        }
      }
    });
  }

  void _cycleCamera() {
    FeedbackService.triggerSelection();
    setState(() {
      _cameraView = _cameraView == ParkingCameraView.cockpit
          ? ParkingCameraView.isometric
          : ParkingCameraView.cockpit;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Arène de Parking Haute Résolution
        Expanded(
          flex: 6,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1520),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
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
                      steeringAngle: _steeringAngle,
                      vehicleColor: widget.vehicle.primaryColor,
                      cameraView: _cameraView,
                      gear: _gear,
                      speed: _speed,
                      proximityAlarm: _proximityAlarm,
                    ),
                  ),

                  // HUD Radar de Recul Supérieur & Bouton Caméra
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Alerte Proximité Radar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _proximityAlarm > 0.7
                                  ? const Color(0xFFFF0055)
                                  : (_proximityAlarm > 0.3 ? const Color(0xFFFFD166) : const Color(0xFF00FFCC)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.sensors,
                                color: _proximityAlarm > 0.7
                                    ? const Color(0xFFFF0055)
                                    : (_proximityAlarm > 0.3 ? const Color(0xFFFFD166) : const Color(0xFF00FFCC)),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _proximityAlarm > 0.8
                                    ? 'STOP ! DANGER'
                                    : (_proximityAlarm > 0.3 ? 'RADAR: PROCHE' : 'RADAR: DÉGAGÉ'),
                                style: TextStyle(
                                  color: _proximityAlarm > 0.7 ? const Color(0xFFFF0055) : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Switcher Caméra (Cockpit / Vue Aérienne 3D)
                        GestureDetector(
                          onTap: _cycleCamera,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E2842), Color(0xFF10172D)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF00FFCC), width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _cameraView == ParkingCameraView.cockpit ? Icons.airline_seat_recline_extra : Icons.videocam,
                                  color: const Color(0xFF00FFCC),
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _cameraView == ParkingCameraView.cockpit ? 'VUE : COCKPIT' : 'VUE : EXTÉRIEUR',
                                  style: const TextStyle(
                                    color: Color(0xFF00FFCC),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Compteur d'accrochages
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber, color: Color(0xFFFF9F1C), size: 15),
                              const SizedBox(width: 4),
                              Text(
                                'CHOCS : $_collisionCount',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Succès du Créneau Parfait
                  if (_isParked)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                          setState(() => _steeringAngle = 0.0);
                        },
                        child: Transform.rotate(
                          angle: _steeringAngle * 1.5,
                          child: Container(
                            width: 104,
                            height: 104,
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
                                const Icon(Icons.circle_outlined, color: Colors.white24, size: 68),
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: const BoxDecoration(color: Color(0xFF00FFCC), shape: BoxShape.circle),
                                ),
                                Positioned(
                                  top: 8,
                                  child: Container(width: 6, height: 14, color: Colors.amberAccent),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('GLISSEZ LE VOLANT', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // 2. Boîte de vitesses PRND (Gear Shifter)
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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

                const SizedBox(width: 12),

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
                          height: 86,
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
                              Text('FREIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
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
                          width: 44,
                          height: 104,
                          decoration: BoxDecoration(
                            color: _isAccelerating ? const Color(0xFF00FFCC) : const Color(0xFF1E2838),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF00FFCC), width: 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.speed, color: _isAccelerating ? Colors.black : const Color(0xFF00FFCC), size: 20),
                              const SizedBox(height: 4),
                              Text(
                                'GAZ',
                                style: TextStyle(
                                  color: _isAccelerating ? Colors.black : const Color(0xFF00FFCC),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
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

  Widget _buildGearButton(String label, GearShifter targetGear) {
    final isSelected = _gear == targetGear;
    return GestureDetector(
      onTap: () {
        FeedbackService.triggerLight();
        setState(() => _gear = targetGear);
      },
      child: Container(
        width: 36,
        height: 24,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00FFCC) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
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
  final double steeringAngle;
  final Color vehicleColor;
  final ParkingCameraView cameraView;
  final GearShifter gear;
  final double speed;
  final double proximityAlarm;

  _ParkingArenaPainter({
    required this.parkingSlot,
    required this.obstacles,
    required this.carX,
    required this.carY,
    required this.carAngle,
    required this.steeringAngle,
    required this.vehicleColor,
    required this.cameraView,
    required this.gear,
    required this.speed,
    required this.proximityAlarm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cameraView == ParkingCameraView.cockpit) {
      _paintCockpitParking(canvas, size);
    } else {
      _paintIsometricParking(canvas, size);
    }
  }

  // --- VUE COCKPIT PARKING : PARE-BRISE, VOLANT & ÉCRAN CAMÉRA DE RECUL ---
  void _paintCockpitParking(Canvas canvas, Size size) {
    // 1. Vue extérieure à travers le pare-brise
    // Sol de parking goudronné
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF141924));

    // Lignes de guidage au sol projetées
    final markPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(size.width * 0.25, size.height * 0.2), Offset(size.width * 0.1, size.height * 0.7), markPaint);
    canvas.drawLine(Offset(size.width * 0.75, size.height * 0.2), Offset(size.width * 0.9, size.height * 0.7), markPaint);

    // Obstacles visibles au loin à travers le pare-brise
    for (final obs in obstacles) {
      final double relX = (obs.center.dx - carX);
      final double relY = (obs.center.dy - carY);
      final screenX = size.width * 0.5 + relX * size.width * 1.5;
      final screenY = size.height * 0.35 + relY * size.height * 1.2;

      if (screenY > 0 && screenY < size.height * 0.6) {
        if (obs.width > 0.15) {
          // Voiture adverse
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(screenX, screenY), width: 70, height: 40), const Radius.circular(6)),
            Paint()..color = const Color(0xFF34495E),
          );
        } else {
          // Plot cône orange
          canvas.drawCircle(Offset(screenX, screenY), 10, Paint()..color = const Color(0xFFFF5722));
        }
      }
    }

    // 2. Tableau de bord bas (Dashboard)
    final dashHeight = size.height * 0.42;
    final dashTop = size.height - dashHeight;

    final dashShader = const LinearGradient(
      colors: [Color(0xFF161C26), Color(0xFF090D14)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, dashTop, size.width, dashHeight));

    canvas.drawRect(Rect.fromLTWH(0, dashTop, size.width, dashHeight), Paint()..shader = dashShader);

    // Piliers A gauche et droite
    final pillarPaint = Paint()..color = const Color(0xFF0B0E14);
    final pL = Path()..moveTo(0, 0)..lineTo(size.width * 0.1, 0)..lineTo(size.width * 0.04, size.height)..lineTo(0, size.height)..close();
    final pR = Path()..moveTo(size.width, 0)..lineTo(size.width * 0.9, 0)..lineTo(size.width * 0.96, size.height)..lineTo(size.width, size.height)..close();
    canvas.drawPath(pL, pillarPaint);
    canvas.drawPath(pR, pillarPaint);

    // 3. ÉCRAN CENTRAL : CAMÉRA DE RECUL / GPS DE PARKING
    final screenRect = Rect.fromCenter(center: Offset(size.width * 0.5, dashTop + 36), width: size.width * 0.55, height: 58);
    canvas.drawRRect(RRect.fromRectAndRadius(screenRect, const Radius.circular(8)), Paint()..color = Colors.black);
    canvas.drawRRect(RRect.fromRectAndRadius(screenRect, const Radius.circular(8)), Paint()..color = (gear == GearShifter.reverse ? const Color(0xFF00FFCC) : Colors.white24)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    if (gear == GearShifter.reverse) {
      // Affichage Caméra de recul dynamique avec lignes de guidage de braquage vertes/jaunes/rouges
      final camGuidePaintG = Paint()..color = const Color(0xFF00FFCC)..strokeWidth = 2.0;
      final camGuidePaintR = Paint()..color = const Color(0xFFFF0055)..strokeWidth = 2.0;

      final turnOffset = steeringAngle * 14.0;
      // Lignes de guidage dynamiques
      canvas.drawLine(Offset(screenRect.left + 16, screenRect.bottom - 4), Offset(screenRect.left + 26 + turnOffset, screenRect.top + 10), camGuidePaintG);
      canvas.drawLine(Offset(screenRect.right - 16, screenRect.bottom - 4), Offset(screenRect.right - 26 + turnOffset, screenRect.top + 10), camGuidePaintG);
      canvas.drawLine(Offset(screenRect.left + 22 + turnOffset * 0.5, screenRect.top + 24), Offset(screenRect.right - 22 + turnOffset * 0.5, screenRect.top + 24), camGuidePaintR);

      final camText = TextPainter(
        text: const TextSpan(text: 'CAMÉRA DE RECUL ACTIVE', style: TextStyle(color: Color(0xFF00FFCC), fontSize: 8, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      camText.paint(canvas, Offset(screenRect.left + 8, screenRect.top + 4));
    } else {
      // Radar de stationnement numérique
      final gpsText = TextPainter(
        text: TextSpan(
          text: 'ASSISTANCE CRÉNEAU PARK PILOT\nMARCHE AVANT ACTIVE [${gear.name.toUpperCase()}]',
          style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold, height: 1.3),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      gpsText.paint(canvas, Offset(screenRect.left + 10, screenRect.top + 14));
    }

    // Mini volant au centre bas tournant avec steeringAngle
    canvas.save();
    canvas.translate(size.width * 0.5, size.height - 12);
    canvas.rotate(steeringAngle * 1.5);
    final wheelRadius = size.height * 0.22;
    canvas.drawCircle(Offset.zero, wheelRadius, Paint()..color = const Color(0xFF1E2838)..style = PaintingStyle.stroke..strokeWidth = 14);
    canvas.drawCircle(Offset.zero, 18, Paint()..color = vehicleColor);
    canvas.restore();
  }

  // --- VUE 3D ISOMETRIQUE / AERIENNE DE STATIONNEMENT ---
  void _paintIsometricParking(Canvas canvas, Size size) {
    // 1. Marquage au sol du parking
    final linePaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(Offset(0, size.height * 0.40), Offset(size.width, size.height * 0.40), linePaint);
    canvas.drawLine(Offset(0, size.height * 0.65), Offset(size.width, size.height * 0.65), linePaint);

    // 2. Zone de créneau cible
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

    const pSpan = TextSpan(text: 'P', style: TextStyle(color: Color(0xFF00FFCC), fontSize: 26, fontWeight: FontWeight.w900));
    final pPainter = TextPainter(text: pSpan, textDirection: TextDirection.ltr)..layout();
    pPainter.paint(canvas, targetPixelRect.center - Offset(pPainter.width / 2, pPainter.height / 2));

    // 3. Dessin des obstacles
    for (final obs in obstacles) {
      final obsPixel = Rect.fromLTWH(
        obs.left * size.width,
        obs.top * size.height,
        obs.width * size.width,
        obs.height * size.height,
      );

      if (obs.width > 0.15) {
        canvas.drawRRect(RRect.fromRectAndRadius(obsPixel, const Radius.circular(8)), Paint()..color = const Color(0xFF34495E));
        canvas.drawRRect(RRect.fromRectAndRadius(obsPixel.deflate(4), const Radius.circular(6)), Paint()..color = const Color(0xFF2C3E50));
      } else {
        canvas.drawCircle(obsPixel.center, obsPixel.width * 0.4, Paint()..color = const Color(0xFFFF5722));
        canvas.drawCircle(obsPixel.center, obsPixel.width * 0.2, Paint()..color = Colors.white);
      }
    }

    // 4. Voiture du joueur réaliste avec orientation cinématique
    canvas.save();
    final carPx = carX * size.width;
    final carPy = carY * size.height;
    canvas.translate(carPx, carPy);
    canvas.rotate(carAngle + math.pi / 2);

    final carWidth = size.width * 0.11;
    final carHeight = size.height * 0.14;
    final carRect = Rect.fromCenter(center: Offset.zero, width: carWidth, height: carHeight);

    // Ombre sous la voiture
    canvas.drawRRect(RRect.fromRectAndRadius(carRect.shift(const Offset(3, 4)), const Radius.circular(8)), Paint()..color = Colors.black45);

    // Carrosserie avec dégradé
    canvas.drawRRect(RRect.fromRectAndRadius(carRect, const Radius.circular(8)), Paint()..color = vehicleColor);

    // Pare-brise et toit
    final windshieldRect = Rect.fromCenter(center: const Offset(0, -6), width: carWidth * 0.75, height: carHeight * 0.35);
    canvas.drawRRect(RRect.fromRectAndRadius(windshieldRect, const Radius.circular(4)), Paint()..color = const Color(0xFF1A2530));

    // Phares avant jaunes
    canvas.drawCircle(Offset(-carWidth * 0.35, -carHeight * 0.45), 3, Paint()..color = const Color(0xFFFFEB3B));
    canvas.drawCircle(Offset(carWidth * 0.35, -carHeight * 0.45), 3, Paint()..color = const Color(0xFFFFEB3B));

    // Feux arrière (Rouges ou Blancs si marche arrière R)
    final rearLightColor = gear == GearShifter.reverse ? Colors.white : const Color(0xFFFF1744);
    canvas.drawCircle(Offset(-carWidth * 0.35, carHeight * 0.45), 3, Paint()..color = rearLightColor);
    canvas.drawCircle(Offset(carWidth * 0.35, carHeight * 0.45), 3, Paint()..color = rearLightColor);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ParkingArenaPainter oldDelegate) => true;
}
