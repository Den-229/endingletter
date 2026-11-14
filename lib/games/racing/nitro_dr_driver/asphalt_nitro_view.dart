import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';
import 'car_models.dart';

enum DrivingCameraView {
  cockpit, // Vue Intérieure Cockpit (Volant en mains, Tableau de Bord & Rétroviseur)
  chase3D, // Vue 3D Extérieure Arrière Réaliste
  hood,    // Vue Capot / Ras du Sol Ultra Immersive
}

class TrafficCar {
  double x; // -1.0 (gauche) à +1.0 (droite)
  double y; // 0.0 (horizon) à 1.0 (bas de l'écran)
  double speed;
  Color color;
  String model;

  TrafficCar({
    required this.x,
    required this.y,
    required this.speed,
    required this.color,
    this.model = 'sedan',
  });
}

class AsphaltNitroView extends StatefulWidget {
  final RacingVehicle vehicle;
  final VoidCallback onCrash;

  const AsphaltNitroView({
    super.key,
    required this.vehicle,
    required this.onCrash,
  });

  @override
  State<AsphaltNitroView> createState() => _AsphaltNitroViewState();
}

class _AsphaltNitroViewState extends State<AsphaltNitroView> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  double _lastTimestamp = 0;

  double _playerX = 0.0; // -0.85 à +0.85
  double _speedKmh = 140.0;
  double _distanceMeters = 0.0;
  double _nitroTank = 0.85; // 0.0 à 1.0
  bool _isNitroActive = false;
  DrivingCameraView _cameraView = DrivingCameraView.cockpit; // Par défaut vue intérieure immersive

  final List<TrafficCar> _traffic = [];
  double _trafficSpawnTimer = 0.0;
  final math.Random _rnd = math.Random();
  double _roadScroll = 0.0;

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
    final currentMs = _ticker.lastElapsedDuration?.inMicroseconds ?? 0;
    if (_lastTimestamp == 0) {
      _lastTimestamp = currentMs.toDouble();
      return;
    }
    double dt = (currentMs - _lastTimestamp) / 1000000.0;
    _lastTimestamp = currentMs.toDouble();
    if (dt <= 0 || dt > 0.1) dt = 0.033;

    setState(() {
      // Gestion de la vitesse et de la jauge de Nitro
      if (_isNitroActive && _nitroTank > 0) {
        _speedKmh = math.min(_speedKmh + 240 * dt, widget.vehicle.topSpeed);
        _nitroTank = math.max(0.0, _nitroTank - 0.25 * dt);
        if (_nitroTank <= 0) _isNitroActive = false;
      } else {
        _isNitroActive = false;
        _speedKmh = math.max(140.0, _speedKmh - 120 * dt);
        _nitroTank = math.min(1.0, _nitroTank + 0.06 * dt);
      }

      final speedFactor = _speedKmh / 140.0;
      _distanceMeters += _speedKmh * (dt / 3.6);
      _roadScroll = (_roadScroll + dt * 4.2 * speedFactor) % 1.0;

      // Apparition du trafic
      _trafficSpawnTimer += dt * speedFactor;
      if (_trafficSpawnTimer > 1.1) {
        _trafficSpawnTimer = 0.0;
        final lanes = [-0.65, -0.22, 0.22, 0.65];
        final laneX = lanes[_rnd.nextInt(lanes.length)];
        final colors = [
          const Color(0xFFFF2A6D),
          const Color(0xFFFFD166),
          const Color(0xFF00FFCC),
          const Color(0xFF9E00FF),
          Colors.white,
        ];
        final models = ['sport', 'sedan', 'suv'];
        _traffic.add(TrafficCar(
          x: laneX,
          y: 0.0,
          speed: 0.25 + _rnd.nextDouble() * 0.25,
          color: colors[_rnd.nextInt(colors.length)],
          model: models[_rnd.nextInt(models.length)],
        ));
      }

      // Déplacement et collisions du trafic
      for (final car in _traffic) {
        car.y += (speedFactor * 0.45 - car.speed) * dt;
      }

      // Collision avec la voiture du joueur
      for (final car in _traffic) {
        if (car.y > 0.72 && car.y < 0.94) {
          if ((car.x - _playerX).abs() < 0.22) {
            FeedbackService.triggerImpact();
            widget.onCrash();
            break;
          }
        }
      }

      // Nettoyage des véhicules dépassés
      _traffic.removeWhere((c) => c.y > 1.2 || c.y < -0.2);
    });
  }

  void _steer(double deltaX) {
    setState(() {
      _playerX = (_playerX + deltaX).clamp(-0.78, 0.78);
    });
  }

  void _toggleNitro() {
    if (_nitroTank > 0.15) {
      FeedbackService.triggerSuccess();
      setState(() {
        _isNitroActive = true;
      });
    }
  }

  void _cycleCameraView() {
    FeedbackService.triggerSelection();
    setState(() {
      switch (_cameraView) {
        case DrivingCameraView.cockpit:
          _cameraView = DrivingCameraView.chase3D;
          break;
        case DrivingCameraView.chase3D:
          _cameraView = DrivingCameraView.hood;
          break;
        case DrivingCameraView.hood:
          _cameraView = DrivingCameraView.cockpit;
          break;
      }
    });
  }

  String get _cameraLabel {
    switch (_cameraView) {
      case DrivingCameraView.cockpit:
        return 'COCKPIT';
      case DrivingCameraView.chase3D:
        return '3D EXTERNE';
      case DrivingCameraView.hood:
        return 'CAPOT';
    }
  }

  IconData get _cameraIcon {
    switch (_cameraView) {
      case DrivingCameraView.cockpit:
        return Icons.airline_seat_recline_extra;
      case DrivingCameraView.chase3D:
        return Icons.videocam;
      case DrivingCameraView.hood:
        return Icons.speed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Zone Principale du Circuit (Course Pseudo-3D dynamique)
        Expanded(
          flex: 6,
          child: GestureDetector(
            onPanUpdate: (details) {
              _steer(details.delta.dx * 0.005);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isNitroActive ? const Color(0xFF00F0FF) : Colors.white24,
                  width: _isNitroActive ? 3.0 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isNitroActive ? const Color(0xFF00F0FF).withValues(alpha: 0.5) : Colors.black87,
                    blurRadius: 20,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size.infinite,
                      painter: _AsphaltRoadPainter(
                        roadScroll: _roadScroll,
                        playerX: _playerX,
                        traffic: _traffic,
                        vehicleColor: widget.vehicle.primaryColor,
                        isNitro: _isNitroActive,
                        cameraView: _cameraView,
                        speedKmh: _speedKmh,
                      ),
                    ),

                    // Lignes cinématiques Turbo Warp
                    if (_isNitroActive)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SpeedLinesPainter(),
                          ),
                        ),
                      ),

                    // HUD Télémétrie Supérieure avec Commutateur de Caméra
                    Positioned(
                      top: 10,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Compteur de Vitesse
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _isNitroActive ? const Color(0xFF00F0FF) : Colors.white24),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.speed, color: Color(0xFF00FFCC), size: 16),
                                const SizedBox(width: 5),
                                Text(
                                  '${_speedKmh.toInt()} KM/H',
                                  style: TextStyle(
                                    color: _isNitroActive ? const Color(0xFF00F0FF) : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Sélecteur de Caméra Interactif (Cockpit / Capot / 3D)
                          GestureDetector(
                            onTap: _cycleCameraView,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1E2842), Color(0xFF10172D)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF00FFCC), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00FFCC).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_cameraIcon, color: const Color(0xFF00FFCC), size: 15),
                                  const SizedBox(width: 5),
                                  Text(
                                    'VUE : $_cameraLabel',
                                    style: const TextStyle(
                                      color: Color(0xFF00FFCC),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Odomètre / Distance
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.straighten, color: Color(0xFFFFD166), size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  '${_distanceMeters.toInt()} M',
                                  style: const TextStyle(color: Color(0xFFFFD166), fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Barre de Contrôles & Nitro
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: const Color(0xFF0A0E1A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Boutons de virage gauche / droite
                Row(
                  children: [
                    IconButton(
                      iconSize: 42,
                      icon: const Icon(Icons.arrow_circle_left, color: Color(0xFF00FFCC)),
                      onPressed: () => _steer(-0.16),
                    ),
                    IconButton(
                      iconSize: 42,
                      icon: const Icon(Icons.arrow_circle_right, color: Color(0xFF00FFCC)),
                      onPressed: () => _steer(0.16),
                    ),
                  ],
                ),

                // Jauge et Bouton Turbo Nitro
                GestureDetector(
                  onTap: _toggleNitro,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isNitroActive
                            ? [const Color(0xFF00F0FF), const Color(0xFF0055FF)]
                            : [const Color(0xFFFF0055), const Color(0xFFFF7700)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _isNitroActive ? const Color(0xFF00F0FF).withValues(alpha: 0.6) : const Color(0xFFFF0055).withValues(alpha: 0.4),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.white, size: 28),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'BOOST NITRO',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 3),
                            SizedBox(
                              width: 80,
                              child: LinearProgressIndicator(
                                value: _nitroTank,
                                backgroundColor: Colors.black38,
                                valueColor: AlwaysStoppedAnimation<Color>(_isNitroActive ? Colors.white : const Color(0xFFFFD166)),
                                minHeight: 4,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AsphaltRoadPainter extends CustomPainter {
  final double roadScroll;
  final double playerX;
  final List<TrafficCar> traffic;
  final Color vehicleColor;
  final bool isNitro;
  final DrivingCameraView cameraView;
  final double speedKmh;

  _AsphaltRoadPainter({
    required this.roadScroll,
    required this.playerX,
    required this.traffic,
    required this.vehicleColor,
    required this.isNitro,
    required this.cameraView,
    required this.speedKmh,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final horizonY = cameraView == DrivingCameraView.hood ? size.height * 0.42 : size.height * 0.35;

    // 1. Ciel nocturne et Skyline urbaine rétro-éclairée
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF050711), Color(0xFF120B24), Color(0xFF261044)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizonY));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, horizonY), skyPaint);

    // Bâtiments en silhouette à l'horizon
    final bldgPaint = Paint()..color = const Color(0xFF090D1C);
    final neonPaint = Paint()..color = const Color(0xFF00FFCC).withValues(alpha: 0.3);
    for (int b = 0; b < 14; b++) {
      final bx = (b * (size.width / 13) - (playerX * 25)) % size.width;
      final bh = 25.0 + (b % 4) * 15.0;
      canvas.drawRect(Rect.fromLTWH(bx, horizonY - bh, size.width / 14, bh), bldgPaint);
      if (b % 3 == 0) {
        canvas.drawRect(Rect.fromLTWH(bx + 4, horizonY - bh + 6, 3, 3), neonPaint);
      }
    }

    // 2. Route asphaltée en perspective trapézoïdale
    final roadPath = Path()
      ..moveTo(size.width * 0.36, horizonY)
      ..lineTo(size.width * 0.64, horizonY)
      ..lineTo(size.width * 0.99, size.height)
      ..lineTo(size.width * 0.01, size.height)
      ..close();

    final roadPaint = Paint()..color = const Color(0xFF141722);
    canvas.drawPath(roadPath, roadPaint);

    // Bordures latérales réfléchissantes (vibro-marqueurs rouges/blancs)
    final curbPaintL = Paint()
      ..color = isNitro ? const Color(0xFF00F0FF) : const Color(0xFFFF2A6D)
      ..strokeWidth = 4.0;
    canvas.drawLine(Offset(size.width * 0.36, horizonY), Offset(size.width * 0.01, size.height), curbPaintL);
    canvas.drawLine(Offset(size.width * 0.64, horizonY), Offset(size.width * 0.99, size.height), curbPaintL);

    // Lignes de voies dynamiques
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 3.5;

    for (int i = 0; i < 9; i++) {
      final progress = (i / 9.0 + roadScroll) % 1.0;
      final y = horizonY + (size.height - horizonY) * math.pow(progress, 1.8);
      final laneSpread = size.width * (0.16 + progress * 0.36);
      final centerX = size.width * 0.5;

      // Voies médiane gauche, centrale, droite
      canvas.drawLine(Offset(centerX - laneSpread * 0.5, y), Offset(centerX - laneSpread * 0.5, y + 18 * progress), dashPaint);
      canvas.drawLine(Offset(centerX + laneSpread * 0.5, y), Offset(centerX + laneSpread * 0.5, y + 18 * progress), dashPaint);
    }

    // 3. Trafic d'autres voitures en perspective 3D
    for (final car in traffic) {
      final y = horizonY + (size.height - horizonY) * car.y;
      final scale = 0.22 + car.y * 0.82;
      final x = size.width * 0.5 + (car.x * size.width * 0.42 * scale);

      final carW = 44 * scale;
      final carH = 56 * scale;

      // Ombre sous le véhicule
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y + carH * 0.45), width: carW * 1.1, height: carH * 0.3),
        Paint()..color = Colors.black54,
      );

      // Carrosserie
      final carRect = Rect.fromCenter(center: Offset(x, y), width: carW, height: carH);
      canvas.drawRRect(RRect.fromRectAndRadius(carRect, Radius.circular(5 * scale)), Paint()..color = car.color);

      // Toit / Vitre arrière
      final roofRect = Rect.fromCenter(center: Offset(x, y - carH * 0.1), width: carW * 0.72, height: carH * 0.45);
      canvas.drawRRect(RRect.fromRectAndRadius(roofRect, Radius.circular(3 * scale)), Paint()..color = const Color(0xFF0F141F));

      // Feux rouges arrière
      canvas.drawCircle(Offset(x - carW * 0.32, y + carH * 0.38), 2.8 * scale, Paint()..color = const Color(0xFFFF0055));
      canvas.drawCircle(Offset(x + carW * 0.32, y + carH * 0.38), 2.8 * scale, Paint()..color = const Color(0xFFFF0055));
    }

    // 4. Rendu de la Caméra Sélectionnée (COCKPIT / 3D EXTERNE / CAPOT)
    switch (cameraView) {
      case DrivingCameraView.cockpit:
        _drawCockpitView(canvas, size);
        break;
      case DrivingCameraView.chase3D:
        _drawChase3DView(canvas, size);
        break;
      case DrivingCameraView.hood:
        _drawHoodView(canvas, size);
        break;
    }
  }

  // --- VUE COCKPIT INTERIEURE : VOLANT, TABLEAU DE BORD & RETROVISEUR ---
  void _drawCockpitView(Canvas canvas, Size size) {
    final double steerTurnAngle = playerX * 1.2;

    // Pare-brise et reflets en verre
    final glassShine = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.08),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.04),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glassShine);

    // Rétroviseur central supérieur (montre la route et les concurrents derrière)
    final mirrorRect = Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.09), width: size.width * 0.36, height: 26);
    // Boîtier
    canvas.drawRRect(RRect.fromRectAndRadius(mirrorRect.inflate(2), const Radius.circular(8)), Paint()..color = const Color(0xFF0B0E14));
    // Miroir
    canvas.drawRRect(
      RRect.fromRectAndRadius(mirrorRect, const Radius.circular(6)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1E2840), Color(0xFF121828)],
        ).createShader(mirrorRect),
    );
    // Reflet de route arrière dans le miroir
    canvas.drawLine(
      Offset(mirrorRect.left + 15, mirrorRect.bottom - 4),
      Offset(mirrorRect.right - 15, mirrorRect.bottom - 4),
      Paint()..color = Colors.white30..strokeWidth = 2,
    );
    // Petit point de phare suiveur dans le rétroviseur
    canvas.drawCircle(Offset(mirrorRect.center.dx - (playerX * 20), mirrorRect.center.dy), 2.5, Paint()..color = const Color(0xFFFFD166));

    // Montants du pare-brise (Piliers A gauche et droite)
    final pillarPaint = Paint()..color = const Color(0xFF10141D);
    final pathPillarL = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.12, 0)
      ..lineTo(size.width * 0.05, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(pathPillarL, pillarPaint);

    final pathPillarR = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width * 0.88, 0)
      ..lineTo(size.width * 0.95, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(pathPillarR, pillarPaint);

    // Tableau de bord inférieur (Dashboard sportif en cuir texturé & fibre de carbone)
    final dashHeight = size.height * 0.38;
    final dashTop = size.height - dashHeight;

    final dashPath = Path()
      ..moveTo(0, dashTop)
      ..quadraticBezierTo(size.width * 0.5, dashTop - 25, size.width, dashTop)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final dashShader = LinearGradient(
      colors: const [Color(0xFF151A25), Color(0xFF090C13)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, dashTop - 25, size.width, dashHeight + 25));

    canvas.drawPath(dashPath, Paint()..shader = dashShader);

    // Écran télémétrie digital du tableau de bord
    final clusterRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, dashTop + 14),
      width: size.width * 0.44,
      height: 38,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(clusterRect, const Radius.circular(8)), Paint()..color = const Color(0xFF060910));
    canvas.drawRRect(RRect.fromRectAndRadius(clusterRect, const Radius.circular(8)), Paint()..color = const Color(0xFF00FFCC).withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Vitesse digitale et rapport de vitesse
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${speedKmh.toInt()} KM/H  •  GEAR 6',
        style: TextStyle(
          color: isNitro ? const Color(0xFF00F0FF) : const Color(0xFF00FFCC),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, clusterRect.center - Offset(textPainter.width / 2, textPainter.height / 2));

    // Volant de course ultra réaliste avec rotation dynamique
    canvas.save();
    final wheelCenterX = size.width * 0.5;
    final wheelCenterY = size.height - 20;
    canvas.translate(wheelCenterX, wheelCenterY);
    canvas.rotate(steerTurnAngle);

    final double wheelRadius = size.height * 0.26;

    // Jante extérieure du volant
    final rimPaint = Paint()
      ..color = const Color(0xFF181E29)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20.0;
    canvas.drawCircle(Offset.zero, wheelRadius, rimPaint);

    // Repère jaune de centrage au sommet du volant
    final markPaint = Paint()
      ..color = isNitro ? const Color(0xFF00F0FF) : const Color(0xFFFFD166)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20.0;
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: wheelRadius), -math.pi / 2 - 0.12, 0.24, false, markPaint);

    // Branches du volant en fibre de carbone
    final spokePaint = Paint()
      ..color = const Color(0xFF263040)
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(-wheelRadius * 0.95, 0), spokePaint);
    canvas.drawLine(Offset.zero, Offset(wheelRadius * 0.95, 0), spokePaint);
    canvas.drawLine(Offset.zero, Offset(0, wheelRadius * 0.90), spokePaint);

    // Moyeu central du volant
    canvas.drawCircle(Offset.zero, 34, Paint()..color = const Color(0xFF0B0E14));
    canvas.drawCircle(Offset.zero, 34, Paint()..color = vehicleColor..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawCircle(Offset.zero, 12, Paint()..color = vehicleColor);

    // Mains de pilote avec gants de course (gauche et droite sur le volant)
    final glovePaint = Paint()..color = const Color(0xFF1E2838);
    final accentPaint = Paint()..color = vehicleColor;

    // Main gauche
    canvas.drawOval(Rect.fromCenter(center: Offset(-wheelRadius, 0), width: 26, height: 42), glovePaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(-wheelRadius, 0), width: 14, height: 20), accentPaint);

    // Main droite
    canvas.drawOval(Rect.fromCenter(center: Offset(wheelRadius, 0), width: 26, height: 42), glovePaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(wheelRadius, 0), width: 14, height: 20), accentPaint);

    canvas.restore();
  }

  // --- VUE 3D EXTERNE ARRIERE : CARROSSERIE DÉTAILLÉE, FEUX LED & NITRO ---
  void _drawChase3DView(Canvas canvas, Size size) {
    final playerPixelX = size.width * 0.5 + (playerX * size.width * 0.42);
    final playerPixelY = size.height * 0.83;
    final tiltAngle = playerX * 0.18; // Inclinaison de la carrosserie en virage

    canvas.save();
    canvas.translate(playerPixelX, playerPixelY);
    canvas.rotate(tiltAngle);

    // Flammes Nitro jaillissant des doubles pots d'échappement
    if (isNitro) {
      final nitroGlow = Paint()
        ..color = const Color(0xFF00F0FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(const Offset(-22, 44), 14, nitroGlow);
      canvas.drawCircle(const Offset(22, 44), 14, nitroGlow);

      final nitroCore = Paint()..color = Colors.white;
      canvas.drawCircle(const Offset(-22, 44), 6, nitroCore);
      canvas.drawCircle(const Offset(22, 44), 6, nitroCore);
    }

    // Ombre sous le bolide
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 36), width: 84, height: 24),
      Paint()..color = Colors.black87,
    );

    // Pneus larges / Roues arrières
    final tirePaint = Paint()..color = const Color(0xFF0A0C10);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-46, 12, 14, 30), const Radius.circular(4)), tirePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(32, 12, 14, 30), const Radius.circular(4)), tirePaint);

    // Carrosserie sportive (Fuselage aérodynamique)
    final bodyPaint = Paint()..color = vehicleColor;
    final bodyRect = Rect.fromCenter(center: Offset.zero, width: 72, height: 76);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(14)), bodyPaint);

    // Diffuseur arrière en carbone
    final diffuserPaint = Paint()..color = const Color(0xFF10141D);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-32, 28, 64, 12), const Radius.circular(4)), diffuserPaint);

    // Aileron aérodynamique GT
    final spoilerPaint = Paint()..color = const Color(0xFF1A2230);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-42, 36, 84, 8), const Radius.circular(3)), spoilerPaint);
    canvas.drawRect(const Rect.fromLTWH(-24, 30, 4, 8), diffuserPaint);
    canvas.drawRect(const Rect.fromLTWH(20, 30, 4, 8), diffuserPaint);

    // Vitre arrière teintée / Cockpit
    final windowShader = const LinearGradient(
      colors: [Color(0xFF0F1724), Color(0xFF05080E)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(const Rect.fromLTWH(-24, -28, 48, 36));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-24, -28, 48, 36), const Radius.circular(8)),
      Paint()..shader = windowShader,
    );

    // Feux arrière LED horizontaux profilés
    final ledPaint = Paint()
      ..color = const Color(0xFFFF0055)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-30, 18), const Offset(-8, 18), ledPaint);
    canvas.drawLine(const Offset(8, 18), const Offset(30, 18), ledPaint);

    // Doubles sorties d'échappement chromées
    final exhaustPaint = Paint()..color = const Color(0xFFC0C7D0);
    canvas.drawCircle(const Offset(-22, 38), 4, exhaustPaint);
    canvas.drawCircle(const Offset(22, 38), 4, exhaustPaint);

    canvas.restore();
  }

  // --- VUE CAPOT / RAS DU SOL ULTRA IMMERSIVE ---
  void _drawHoodView(Canvas canvas, Size size) {
    // Le capot de la voiture occupe la partie basse de l'écran avec reflets de vitesse
    final hoodHeight = size.height * 0.24;
    final hoodTop = size.height - hoodHeight;

    final hoodPath = Path()
      ..moveTo(size.width * 0.20, hoodTop)
      ..lineTo(size.width * 0.80, hoodTop)
      ..lineTo(size.width * 0.98, size.height)
      ..lineTo(size.width * 0.02, size.height)
      ..close();

    final hoodShader = LinearGradient(
      colors: [
        vehicleColor.withValues(alpha: 0.9),
        vehicleColor,
        const Color(0xFF0A0E18),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, hoodTop, size.width, hoodHeight));

    canvas.drawPath(hoodPath, Paint()..shader = hoodShader);

    // Prise d'air centrale sur le capot
    final scoopRect = Rect.fromCenter(center: Offset(size.width * 0.5, hoodTop + 24), width: size.width * 0.22, height: 14);
    canvas.drawRRect(RRect.fromRectAndRadius(scoopRect, const Radius.circular(4)), Paint()..color = const Color(0xFF0B0E14));

    // Lignes de reflets chromés sur le capot
    final linePaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(size.width * 0.35, hoodTop), Offset(size.width * 0.25, size.height), linePaint);
    canvas.drawLine(Offset(size.width * 0.65, hoodTop), Offset(size.width * 0.75, size.height), linePaint);
  }

  @override
  bool shouldRepaint(covariant _AsphaltRoadPainter oldDelegate) => true;
}

class _SpeedLinesPainter extends CustomPainter {
  final math.Random _rnd = math.Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.45)
      ..strokeWidth = 2.5;

    for (int i = 0; i < 24; i++) {
      final x = _rnd.nextDouble() * size.width;
      final y = _rnd.nextDouble() * size.height;
      canvas.drawLine(Offset(x, y), Offset(x, y + 55), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedLinesPainter oldDelegate) => true;
}
