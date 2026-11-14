import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models_3d.dart';

/// Moteur de rendu 3D temps réel pur Flutter avec CustomPainter
class Render3DEngine {
  static const double fov = 340.0;
  static const double maxDrawDistance = 850.0;

  /// Transforme un point 3D en coordonnées 2D écran
  static Offset? project(Point3D point, Size screenSize) {
    if (point.z <= 5.0) return null; // Derrière ou trop près de la caméra
    final scale = fov / point.z;
    final x = (screenSize.width / 2) + (point.x * scale);
    final y = (screenSize.height / 2) + (point.y * scale);
    return Offset(x, y);
  }

  /// Génère les polygones d'un astéroïde low-poly
  static List<Polygon3D> createAsteroid(WorldEntity3D entity) {
    final s = 28.0 * entity.scale;
    // Sommets d'un octaèdre irrégulier
    final v0 = Point3D(0, -s * 1.1, 0);
    final v1 = Point3D(s, 0, 0);
    final v2 = Point3D(0, 0, s);
    final v3 = Point3D(-s, 0, 0);
    final v4 = Point3D(0, 0, -s);
    final v5 = Point3D(0, s * 1.1, 0);

    final rawVertices = [v0, v1, v2, v3, v4, v5];
    final rotated = rawVertices.map((v) {
      var pt = v.rotateX(entity.rotX);
      pt = pt.rotateY(entity.rotY);
      pt = pt.rotateZ(entity.rotZ);
      return pt.add(entity.pos);
    }).toList();

    List<Polygon3D> polys = [];
    final faces = [
      [0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 1],
      [5, 2, 1], [5, 3, 2], [5, 4, 3], [5, 1, 4]
    ];

    for (int i = 0; i < faces.length; i++) {
      final f = faces[i];
      final color = i % 2 == 0 
          ? const Color(0xFFE056FD) 
          : const Color(0xFF686DE0);
      polys.add(Polygon3D(
        vertices: [rotated[f[0]], rotated[f[1]], rotated[f[2]]],
        baseColor: color,
      ));
    }
    return polys;
  }

  /// Génère un drone de combat néon (pyramide inversée + cockpit)
  static List<Polygon3D> createDrone(WorldEntity3D entity) {
    final s = 24.0 * entity.scale;
    final apex = Point3D(0, s * 0.9, 0);
    final base0 = Point3D(-s, -s * 0.6, -s);
    final base1 = Point3D(s, -s * 0.6, -s);
    final base2 = Point3D(s, -s * 0.6, s);
    final base3 = Point3D(-s, -s * 0.6, s);

    final raw = [apex, base0, base1, base2, base3];
    final transformed = raw.map((v) {
      var pt = v.rotateX(entity.rotX);
      pt = pt.rotateY(entity.rotY);
      pt = pt.rotateZ(entity.rotZ);
      return pt.add(entity.pos);
    }).toList();

    List<Polygon3D> polys = [];
    final faces = [
      [0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 1],
      [1, 2, 3] // Base
    ];

    for (final f in faces) {
      polys.add(Polygon3D(
        vertices: f.map((idx) => transformed[idx]).toList(),
        baseColor: const Color(0xFFFF2A6D),
      ));
    }
    return polys;
  }

  /// Génère un anneau hyper-espace (Ring Gate)
  static List<Polygon3D> createRingGate(WorldEntity3D entity) {
    final r = 60.0 * entity.scale;
    const segments = 8;
    List<Point3D> ringPts = [];
    for (int i = 0; i < segments; i++) {
      final angle = (i / segments) * 2 * math.pi;
      ringPts.add(Point3D(
        math.cos(angle) * r,
        math.sin(angle) * r,
        0,
      ));
    }

    final transformed = ringPts.map((v) {
      var pt = v.rotateZ(entity.rotZ);
      return pt.add(entity.pos);
    }).toList();

    List<Polygon3D> polys = [];
    for (int i = 0; i < segments; i++) {
      final p1 = transformed[i];
      final p2 = transformed[(i + 1) % segments];
      polys.add(Polygon3D(
        vertices: [p1, p2],
        baseColor: const Color(0xFF05D9E8),
        isWireframe: true,
        strokeWidth: 3.5,
      ));
    }
    return polys;
  }

  /// Génère un cristal d'énergie quantique
  static List<Polygon3D> createEnergyCore(WorldEntity3D entity) {
    final s = 16.0 * entity.scale;
    final top = Point3D(0, -s * 1.4, 0);
    final bottom = Point3D(0, s * 1.4, 0);
    final m0 = Point3D(-s, 0, -s);
    final m1 = Point3D(s, 0, -s);
    final m2 = Point3D(s, 0, s);
    final m3 = Point3D(-s, 0, s);

    final raw = [top, bottom, m0, m1, m2, m3];
    final rotated = raw.map((v) {
      var pt = v.rotateY(entity.rotY * 1.5);
      return pt.add(entity.pos);
    }).toList();

    List<Polygon3D> polys = [];
    // Faces supérieures
    polys.add(Polygon3D(vertices: [rotated[0], rotated[2], rotated[3]], baseColor: const Color(0xFF00FFCC)));
    polys.add(Polygon3D(vertices: [rotated[0], rotated[3], rotated[4]], baseColor: const Color(0xFF01CDFE)));
    polys.add(Polygon3D(vertices: [rotated[0], rotated[4], rotated[5]], baseColor: const Color(0xFF00FFCC)));
    polys.add(Polygon3D(vertices: [rotated[0], rotated[5], rotated[2]], baseColor: const Color(0xFF01CDFE)));
    // Faces inférieures
    polys.add(Polygon3D(vertices: [rotated[1], rotated[3], rotated[2]], baseColor: const Color(0xFF05D9E8)));
    polys.add(Polygon3D(vertices: [rotated[1], rotated[4], rotated[3]], baseColor: const Color(0xFF00FFCC)));
    polys.add(Polygon3D(vertices: [rotated[1], rotated[5], rotated[4]], baseColor: const Color(0xFF05D9E8)));
    polys.add(Polygon3D(vertices: [rotated[1], rotated[2], rotated[5]], baseColor: const Color(0xFF00FFCC)));
    return polys;
  }

  /// Polygones du vaisseau spatial du joueur (Vue arrière dynamique)
  static List<Polygon3D> createPlayerShip(Point3D shipPos, double rollAngle, double pitchAngle) {
    // Vaisseau interceptor futuriste en coordonnées locales
    final nose = Point3D(0, 4, 38);
    final cockpitTop = Point3D(0, -10, 10);
    final leftWingTip = Point3D(-34, 4, -14);
    final rightWingTip = Point3D(34, 4, -14);
    final engineLeft = Point3D(-10, 2, -18);
    final engineRight = Point3D(10, 2, -18);
    final tailFin = Point3D(0, -18, -14);
    final underbelly = Point3D(0, 10, 2);

    final raw = [
      nose, cockpitTop, leftWingTip, rightWingTip,
      engineLeft, engineRight, tailFin, underbelly
    ];

    final rotated = raw.map((v) {
      var pt = v.rotateZ(rollAngle);
      pt = pt.rotateX(pitchAngle);
      return pt.add(shipPos);
    }).toList();

    return [
      // Fuselage central
      Polygon3D(vertices: [rotated[0], rotated[1], rotated[4]], baseColor: const Color(0xFF1F1B3E)),
      Polygon3D(vertices: [rotated[0], rotated[1], rotated[5]], baseColor: const Color(0xFF292452)),
      // Aile gauche
      Polygon3D(vertices: [rotated[0], rotated[4], rotated[2]], baseColor: const Color(0xFF00F0FF)),
      // Aile droite
      Polygon3D(vertices: [rotated[0], rotated[3], rotated[5]], baseColor: const Color(0xFF00F0FF)),
      // Cockpit verrière brillante
      Polygon3D(vertices: [rotated[0], rotated[1], rotated[7]], baseColor: const Color(0xFFFF0055)),
      // Dérive arrière
      Polygon3D(vertices: [rotated[1], rotated[6], rotated[4]], baseColor: const Color(0xFF7000FF)),
      Polygon3D(vertices: [rotated[1], rotated[6], rotated[5]], baseColor: const Color(0xFF9000FF)),
    ];
  }
}

/// Peintre personnalisé pour la scène spatiale 3D
class CyberHorizon3DPainter extends CustomPainter {
  final Point3D playerPos;
  final double shipRoll;
  final double shipPitch;
  final List<WorldEntity3D> entities;
  final List<LaserBolt3D> lasers;
  final List<Particle3D> particles;
  final List<Point3D> stars;
  final double gridOffset;
  final double bulletTimeFactor;
  final bool isShieldActive;

  CyberHorizon3DPainter({
    required this.playerPos,
    required this.shipRoll,
    required this.shipPitch,
    required this.entities,
    required this.lasers,
    required this.particles,
    required this.stars,
    required this.gridOffset,
    required this.bulletTimeFactor,
    required this.isShieldActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fond cosmique en dégradé profond
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 1.2,
        colors: [
          bulletTimeFactor < 0.9 ? const Color(0xFF0B1B3D) : const Color(0xFF16002B),
          const Color(0xFF03010D),
          Colors.black,
        ],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // 2. Grille Synthwave au sol
    _drawSynthwaveGrid(canvas, size);

    // 3. Étoiles filantes 3D
    _drawStars(canvas, size);

    // 4. Rassemblement et Tri de tous les polygones 3D (Painter's algorithm)
    List<Polygon3D> allPolys = [];

    // Polygones du joueur
    allPolys.addAll(Render3DEngine.createPlayerShip(playerPos, shipRoll, shipPitch));

    // Polygones des entités du monde
    for (final entity in entities) {
      if (entity.pos.z < 10.0 || entity.pos.z > Render3DEngine.maxDrawDistance) continue;
      switch (entity.type) {
        case EntityType.asteroid:
          allPolys.addAll(Render3DEngine.createAsteroid(entity));
          break;
        case EntityType.drone:
          allPolys.addAll(Render3DEngine.createDrone(entity));
          break;
        case EntityType.ringGate:
          allPolys.addAll(Render3DEngine.createRingGate(entity));
          break;
        case EntityType.energyCore:
          allPolys.addAll(Render3DEngine.createEnergyCore(entity));
          break;
      }
    }

    // Tri par profondeur décroissante (z le plus lointain d'abord)
    allPolys.sort((a, b) => b.averageZ.compareTo(a.averageZ));

    // 5. Rendu des polygones triés
    for (final poly in allPolys) {
      _renderPolygon(canvas, size, poly);
    }

    // 6. Rendu des lasers 3D
    _renderLasers(canvas, size);

    // 7. Rendu des particules 3D
    _renderParticles(canvas, size);

    // 8. Rendu du bouclier d'énergie du joueur (si actif)
    if (isShieldActive) {
      _renderShield(canvas, size);
    }

    // 9. Réticule de visée holographique projeté à 300 unités devant
    _drawCrosshair(canvas, size);
  }

  void _drawSynthwaveGrid(Canvas canvas, Size size) {
    final horizonY = size.height * 0.58;
    final gridPaint = Paint()
      ..color = const Color(0x33FF007F)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Lignes de fuite vers le centre
    const lineCount = 18;
    for (int i = 0; i <= lineCount; i++) {
      final bottomX = (size.width / lineCount) * i;
      canvas.drawLine(
        Offset(size.width / 2, horizonY),
        Offset(bottomX, size.height),
        gridPaint,
      );
    }

    // Lignes horizontales avec effet de perspective exponentielle
    for (double i = 0; i < 1.0; i += 0.08) {
      final p = (i + gridOffset) % 1.0;
      final y = horizonY + math.pow(p, 2.5) * (size.height - horizonY);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawStars(Canvas canvas, Size size) {
    final starPaint = Paint()..color = Colors.white;
    for (final s in stars) {
      final p2d = Render3DEngine.project(s, size);
      if (p2d != null) {
        final brightness = (1.0 - (s.z / 900.0)).clamp(0.1, 1.0);
        starPaint.color = Colors.cyanAccent.withValues(alpha: brightness * 0.8);
        canvas.drawCircle(p2d, (1.8 * brightness).clamp(0.8, 2.5), starPaint);
      }
    }
  }

  void _renderPolygon(Canvas canvas, Size size, Polygon3D poly) {
    final projected = <Offset>[];
    for (final v in poly.vertices) {
      final p2d = Render3DEngine.project(v, size);
      if (p2d == null) return; // Point derrière la caméra
      projected.add(p2d);
    }

    if (projected.isEmpty) return;

    // Calcul de l'atténuation de brouillard atmosphérique néon
    final depthFactor = (1.0 - (poly.averageZ / Render3DEngine.maxDrawDistance)).clamp(0.1, 1.0);
    final adjustedColor = poly.baseColor.withValues(
      alpha: (poly.baseColor.a * depthFactor).clamp(0.1, 1.0),
    );

    final path = Path()..moveTo(projected[0].dx, projected[0].dy);
    for (int i = 1; i < projected.length; i++) {
      path.lineTo(projected[i].dx, projected[i].dy);
    }

    if (poly.isWireframe) {
      final wirePaint = Paint()
        ..color = adjustedColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = poly.strokeWidth * depthFactor;
      canvas.drawPath(path, wirePaint);
    } else {
      path.close();
      // Rendu de la face pleine
      final fillPaint = Paint()
        ..color = adjustedColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Bordure néon subtile pour le style vectoriel 3D cyberpunk
      final edgePaint = Paint()
        ..color = adjustedColor.withValues(alpha: (0.9 * depthFactor).clamp(0.1, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(path, edgePaint);
    }
  }

  void _renderLasers(Canvas canvas, Size size) {
    for (final laser in lasers) {
      final start = Render3DEngine.project(laser.pos, size);
      final tail = Render3DEngine.project(
        Point3D(laser.pos.x, laser.pos.y, laser.pos.z - (laser.isPlayer ? 25 : -25)),
        size,
      );
      if (start != null && tail != null) {
        final laserPaint = Paint()
          ..color = laser.color
          ..strokeWidth = laser.isPlayer ? 4.0 : 3.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(tail, start, laserPaint);

        // Halo lumineux
        final glowPaint = Paint()
          ..color = laser.color.withValues(alpha: 0.4)
          ..strokeWidth = 8.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(tail, start, glowPaint);
      }
    }
  }

  void _renderParticles(Canvas canvas, Size size) {
    for (final p in particles) {
      final p2d = Render3DEngine.project(p.pos, size);
      if (p2d != null) {
        final opacity = (p.life / p.maxLife).clamp(0.0, 1.0);
        final pPaint = Paint()..color = p.color.withValues(alpha: opacity);
        canvas.drawCircle(p2d, p.size * opacity, pPaint);
      }
    }
  }

  void _renderShield(Canvas canvas, Size size) {
    final ship2D = Render3DEngine.project(playerPos, size);
    if (ship2D != null) {
      final shieldPaint = Paint()
        ..color = const Color(0x5500F0FF)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = const Color(0xFF00F0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(ship2D, 55.0, shieldPaint);
      canvas.drawCircle(ship2D, 55.0, borderPaint);
    }
  }

  void _drawCrosshair(Canvas canvas, Size size) {
    final targetPos = Point3D(playerPos.x * 0.7, playerPos.y * 0.7, 320.0);
    final target2D = Render3DEngine.project(targetPos, size);
    if (target2D != null) {
      final chPaint = Paint()
        ..color = const Color(0x9900FFCC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(target2D, 14.0, chPaint);
      canvas.drawLine(
        Offset(target2D.dx - 18, target2D.dy),
        Offset(target2D.dx - 6, target2D.dy),
        chPaint,
      );
      canvas.drawLine(
        Offset(target2D.dx + 6, target2D.dy),
        Offset(target2D.dx + 18, target2D.dy),
        chPaint,
      );
      canvas.drawLine(
        Offset(target2D.dx, target2D.dy - 18),
        Offset(target2D.dx, target2D.dy - 6),
        chPaint,
      );
      canvas.drawLine(
        Offset(target2D.dx, target2D.dy + 6),
        Offset(target2D.dx, target2D.dy + 18),
        chPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CyberHorizon3DPainter oldDelegate) => true;
}
