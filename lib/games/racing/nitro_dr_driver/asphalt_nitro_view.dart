import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';
import 'car_models.dart';

class TrafficCar {
  double x; // -1.0 (gauche) à +1.0 (droite)
  double y; // 0.0 (horizon) à 1.0 (bas de l'écran)
  double speed;
  Color color;

  TrafficCar({required this.x, required this.y, required this.speed, required this.color});
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
        _speedKmh = math.min(_speedKmh + 220 * dt, widget.vehicle.topSpeed);
        _nitroTank = math.max(0.0, _nitroTank - 0.25 * dt);
        if (_nitroTank <= 0) _isNitroActive = false;
      } else {
        _isNitroActive = false;
        _speedKmh = math.max(140.0, _speedKmh - 120 * dt);
        _nitroTank = math.min(1.0, _nitroTank + 0.05 * dt);
      }

      final speedFactor = _speedKmh / 140.0;
      _distanceMeters += _speedKmh * (dt / 3.6);
      _roadScroll = (_roadScroll + dt * 4.0 * speedFactor) % 1.0;

      // Apparition du trafic
      _trafficSpawnTimer += dt * speedFactor;
      if (_trafficSpawnTimer > 1.2) {
        _trafficSpawnTimer = 0.0;
        final lanes = [-0.65, -0.22, 0.22, 0.65];
        final laneX = lanes[_rnd.nextInt(lanes.length)];
        final colors = [const Color(0xFFFF2A6D), const Color(0xFFFFD166), const Color(0xFF00FFCC), Colors.white70];
        _traffic.add(TrafficCar(
          x: laneX,
          y: 0.0,
          speed: 0.25 + _rnd.nextDouble() * 0.2,
          color: colors[_rnd.nextInt(colors.length)],
        ));
      }

      // Déplacement et collisions du trafic
      for (final car in _traffic) {
        car.y += (speedFactor * 0.45 - car.speed) * dt;
      }

      // Collision avec la voiture du joueur
      for (final car in _traffic) {
        if (car.y > 0.72 && car.y < 0.92) {
          if ((car.x - _playerX).abs() < 0.24) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Vue Course Pseudo-3D (Canvas Asphalt Nitro)
        Expanded(
          flex: 6,
          child: GestureDetector(
            onPanUpdate: (details) {
              _steer(details.delta.dx * 0.005);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      ),
                    ),

                    // Effet visuel de Lignes de Vitesse Turbo / Warp
                    if (_isNitroActive)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SpeedLinesPainter(),
                          ),
                        ),
                      ),

                    // HUD Télémétrie en direct
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.speed, color: Color(0xFF00FFCC), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '${_speedKmh.toInt()} KM/H',
                                  style: TextStyle(
                                    color: _isNitroActive ? const Color(0xFF00F0FF) : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.straighten, color: Color(0xFFFFD166), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '${_distanceMeters.toInt()} M',
                                  style: const TextStyle(color: Color(0xFFFFD166), fontWeight: FontWeight.bold, fontSize: 13),
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

        // Barre de Contrôles & Bouton Nitro
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
                              height: 6,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: _nitroTank,
                                  backgroundColor: Colors.black38,
                                  valueColor: AlwaysStoppedAnimation(
                                    _nitroTank > 0.3 ? const Color(0xFF00FFCC) : const Color(0xFFFF0055),
                                  ),
                                ),
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

  _AsphaltRoadPainter({
    required this.roadScroll,
    required this.playerX,
    required this.traffic,
    required this.vehicleColor,
    required this.isNitro,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final horizonY = size.height * 0.35;

    // Ciel nocturne dégradé
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF070B18), Color(0xFF1E1038)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizonY));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, horizonY), skyPaint);

    // Route asphaltée en perspective trapézoïdale
    final roadPath = Path()
      ..moveTo(size.width * 0.35, horizonY)
      ..lineTo(size.width * 0.65, horizonY)
      ..lineTo(size.width * 0.98, size.height)
      ..lineTo(size.width * 0.02, size.height)
      ..close();

    final roadPaint = Paint()..color = const Color(0xFF181D26);
    canvas.drawPath(roadPath, roadPaint);

    // Lignes de séparation de voies en mouvement
    final dashPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 3.0;

    for (int i = 0; i < 8; i++) {
      final progress = (i / 8.0 + roadScroll) % 1.0;
      final y = horizonY + (size.height - horizonY) * math.pow(progress, 1.8);
      final laneSpread = size.width * (0.15 + progress * 0.35);
      final centerX = size.width * 0.5;

      // Voie gauche et droite
      canvas.drawLine(Offset(centerX - laneSpread * 0.5, y), Offset(centerX - laneSpread * 0.5, y + 15 * progress), dashPaint);
      canvas.drawLine(Offset(centerX + laneSpread * 0.5, y), Offset(centerX + laneSpread * 0.5, y + 15 * progress), dashPaint);
    }

    // Trafic d'autres voitures en perspective
    for (final car in traffic) {
      final y = horizonY + (size.height - horizonY) * car.y;
      final scale = 0.2 + car.y * 0.8;
      final x = size.width * 0.5 + (car.x * size.width * 0.42 * scale);

      final carW = 38 * scale;
      final carH = 50 * scale;

      final carRect = Rect.fromCenter(center: Offset(x, y), width: carW, height: carH);
      canvas.drawRRect(RRect.fromRectAndRadius(carRect, Radius.circular(4 * scale)), Paint()..color = car.color);

      // Feux rouges arrière
      canvas.drawCircle(Offset(x - carW * 0.3, y + carH * 0.4), 2 * scale, Paint()..color = Colors.redAccent);
      canvas.drawCircle(Offset(x + carW * 0.3, y + carH * 0.4), 2 * scale, Paint()..color = Colors.redAccent);
    }

    // Voiture du joueur
    final playerPixelX = size.width * 0.5 + (playerX * size.width * 0.42);
    final playerPixelY = size.height * 0.84;
    const playerW = 54.0;
    const playerH = 74.0;

    final playerRect = Rect.fromCenter(center: Offset(playerPixelX, playerPixelY), width: playerW, height: playerH);

    // Flammes d'échappement Nitro
    if (isNitro) {
      final flamePaint = Paint()
        ..color = const Color(0xFF00F0FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(playerPixelX - 16, playerPixelY + 42), 9, flamePaint);
      canvas.drawCircle(Offset(playerPixelX + 16, playerPixelY + 42), 9, flamePaint);
    }

    // Carrosserie du bolide
    canvas.drawRRect(
      RRect.fromRectAndRadius(playerRect, const Radius.circular(10)),
      Paint()..color = vehicleColor,
    );

    // Vitres sombres
    final cabinRect = Rect.fromCenter(center: Offset(playerPixelX, playerPixelY - 6), width: 38, height: 32);
    canvas.drawRRect(RRect.fromRectAndRadius(cabinRect, const Radius.circular(6)), Paint()..color = const Color(0xFF0F1520));

    // Feux arrière lumineux
    canvas.drawCircle(Offset(playerPixelX - 20, playerPixelY + 32), 4, Paint()..color = const Color(0xFFFF0055));
    canvas.drawCircle(Offset(playerPixelX + 20, playerPixelY + 32), 4, Paint()..color = const Color(0xFFFF0055));
  }

  @override
  bool shouldRepaint(covariant _AsphaltRoadPainter oldDelegate) => true;
}

class _SpeedLinesPainter extends CustomPainter {
  final math.Random _rnd = math.Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.4)
      ..strokeWidth = 2.0;

    for (int i = 0; i < 20; i++) {
      final x = _rnd.nextDouble() * size.width;
      final y = _rnd.nextDouble() * size.height;
      canvas.drawLine(Offset(x, y), Offset(x, y + 40), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedLinesPainter oldDelegate) => true;
}
