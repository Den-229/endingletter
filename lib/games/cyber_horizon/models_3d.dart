import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Point dans l'espace tridimensionnel (X=droite, Y=bas, Z=profondeur)
class Point3D {
  double x;
  double y;
  double z;

  Point3D(this.x, this.y, this.z);

  Point3D copy() => Point3D(x, y, z);

  Point3D rotateX(double angle) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return Point3D(
      x,
      y * cosA - z * sinA,
      y * sinA + z * cosA,
    );
  }

  Point3D rotateY(double angle) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return Point3D(
      x * cosA + z * sinA,
      y,
      -x * sinA + z * cosA,
    );
  }

  Point3D rotateZ(double angle) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return Point3D(
      x * cosA - y * sinA,
      x * sinA + y * cosA,
      z,
    );
  }

  Point3D add(Point3D other) => Point3D(x + other.x, y + other.y, z + other.z);
}

/// Face polygonale pour le rendu 3D avec tri de profondeur
class Polygon3D {
  final List<Point3D> vertices;
  final Color baseColor;
  final bool isWireframe;
  final double strokeWidth;

  Polygon3D({
    required this.vertices,
    required this.baseColor,
    this.isWireframe = false,
    this.strokeWidth = 1.5,
  });

  /// Calcule la profondeur moyenne pour le tri du peintre
  double get averageZ {
    if (vertices.isEmpty) return 0;
    double sum = 0;
    for (final v in vertices) {
      sum += v.z;
    }
    return sum / vertices.length;
  }
}

/// Projectile laser tiré par le vaisseau ou les ennemis
class LaserBolt3D {
  Point3D pos;
  double speed;
  final Color color;
  final bool isPlayer;
  bool isAlive = true;

  LaserBolt3D({
    required this.pos,
    required this.speed,
    required this.color,
    required this.isPlayer,
  });

  void update(double dt) {
    pos.z += speed * dt;
    if (pos.z > 800 || pos.z < -10) {
      isAlive = false;
    }
  }
}

/// Particule 3D pour les explosions, étincelles et réacteurs
class Particle3D {
  Point3D pos;
  Point3D vel;
  Color color;
  double size;
  double life;
  final double maxLife;

  Particle3D({
    required this.pos,
    required this.vel,
    required this.color,
    required this.size,
    required this.maxLife,
  }) : life = maxLife;

  bool update(double dt) {
    pos.x += vel.x * dt;
    pos.y += vel.y * dt;
    pos.z += vel.z * dt;
    life -= dt;
    return life > 0;
  }
}

/// Obstacle ou Ennemi dans le monde 3D
enum EntityType { asteroid, drone, energyCore, ringGate }

class WorldEntity3D {
  Point3D pos;
  double rotX = 0;
  double rotY = 0;
  double rotZ = 0;
  double rotSpeedX;
  double rotSpeedY;
  double rotSpeedZ;
  double scale;
  final EntityType type;
  double health;
  bool isDestroyed = false;
  final double collisionRadius;

  WorldEntity3D({
    required this.pos,
    required this.type,
    this.scale = 1.0,
    this.health = 1.0,
    this.collisionRadius = 25.0,
    double? rx,
    double? ry,
    double? rz,
  })  : rotSpeedX = rx ?? (math.Random().nextDouble() - 0.5) * 2.5,
        rotSpeedY = ry ?? (math.Random().nextDouble() - 0.5) * 2.5,
        rotSpeedZ = rz ?? (math.Random().nextDouble() - 0.5) * 2.0;

  void update(double dt, double forwardSpeed) {
    // L'entité se rapproche du joueur (le joueur avance dans le monde)
    pos.z -= forwardSpeed * dt;
    rotX += rotSpeedX * dt;
    rotY += rotSpeedY * dt;
    rotZ += rotSpeedZ * dt;

    if (pos.z < -30) {
      isDestroyed = true;
    }
  }
}
