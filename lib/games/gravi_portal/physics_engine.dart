import 'package:flutter/material.dart';

enum GravityDirection { down, up, left, right }

enum TileType {
  empty,
  wall,
  bouncyWall,
  portalBlue,
  portalOrange,
  laserHazard,
  quantumKey,
  goalSingularity
}

class QuantumOrb {
  Offset position;
  Offset velocity;
  final double radius;
  final List<Offset> trail = [];

  QuantumOrb({
    required this.position,
    this.velocity = Offset.zero,
    this.radius = 14.0,
  });

  void updateTrail() {
    trail.insert(0, position);
    if (trail.length > 12) {
      trail.removeLast();
    }
  }
}

class PortalPair {
  final Offset entrance;
  final Offset exit;
  final Color entranceColor;
  final Color exitColor;

  PortalPair({
    required this.entrance,
    required this.exit,
    this.entranceColor = const Color(0xFF00F0FF),
    this.exitColor = const Color(0xFFFF9900),
  });
}

class MazeLevel {
  final int id;
  final String title;
  final int cols;
  final int rows;
  final Offset playerStart;
  final List<List<TileType>> grid;
  final PortalPair? portals;
  final int totalKeys;

  MazeLevel({
    required this.id,
    required this.title,
    required this.cols,
    required this.rows,
    required this.playerStart,
    required this.grid,
    this.portals,
    required this.totalKeys,
  });

  static List<MazeLevel> getStandardLevels() {
    return [
      _createLevel1(),
      _createLevel2(),
      _createLevel3(),
    ];
  }

  static MazeLevel _createLevel1() {
    // Niveau 1 : Découverte du changement de gravité
    const cols = 9;
    const rows = 12;
    List<List<TileType>> g = List.generate(
      rows,
      (r) => List.generate(cols, (c) {
        if (r == 0 || r == rows - 1 || c == 0 || c == cols - 1) {
          return TileType.wall;
        }
        return TileType.empty;
      }),
    );

    // Murs intérieurs
    g[4][1] = TileType.wall;
    g[4][2] = TileType.wall;
    g[4][3] = TileType.wall;
    g[4][4] = TileType.wall;

    g[7][4] = TileType.wall;
    g[7][5] = TileType.wall;
    g[7][6] = TileType.wall;
    g[7][7] = TileType.wall;

    // Clé quantique
    g[2][7] = TileType.quantumKey;

    // But final
    g[10][7] = TileType.goalSingularity;

    return MazeLevel(
      id: 1,
      title: "INITIATION : LE FLUX GRAVITIQUE",
      cols: cols,
      rows: rows,
      playerStart: const Offset(2, 2),
      grid: g,
      totalKeys: 1,
    );
  }

  static MazeLevel _createLevel2() {
    // Niveau 2 : Portails quantiques et conservation d'inertie
    const cols = 10;
    const rows = 14;
    List<List<TileType>> g = List.generate(
      rows,
      (r) => List.generate(cols, (c) {
        if (r == 0 || r == rows - 1 || c == 0 || c == cols - 1) {
          return TileType.wall;
        }
        return TileType.empty;
      }),
    );

    // Murs séparateurs
    for (int r = 1; r < 10; r++) {
      g[r][5] = TileType.wall;
    }

    // Portails
    g[11][2] = TileType.portalBlue;
    g[2][8] = TileType.portalOrange;

    // Clés
    g[2][2] = TileType.quantumKey;
    g[11][7] = TileType.quantumKey;

    // But
    g[6][8] = TileType.goalSingularity;

    return MazeLevel(
      id: 2,
      title: "VORTEX & TÉLÉPORTATION",
      cols: cols,
      rows: rows,
      playerStart: const Offset(2, 6),
      grid: g,
      portals: PortalPair(
        entrance: const Offset(2, 11),
        exit: const Offset(8, 2),
      ),
      totalKeys: 2,
    );
  }

  static MazeLevel _createLevel3() {
    // Niveau 3 : Lasers et parois rebondissantes
    const cols = 10;
    const rows = 15;
    List<List<TileType>> g = List.generate(
      rows,
      (r) => List.generate(cols, (c) {
        if (r == 0 || r == rows - 1 || c == 0 || c == cols - 1) {
          return TileType.wall;
        }
        return TileType.empty;
      }),
    );

    // Parois rebondissantes
    g[5][1] = TileType.bouncyWall;
    g[5][2] = TileType.bouncyWall;
    g[5][3] = TileType.bouncyWall;

    // Lasers
    g[8][3] = TileType.laserHazard;
    g[8][4] = TileType.laserHazard;
    g[8][5] = TileType.laserHazard;
    g[8][6] = TileType.laserHazard;

    // Clés
    g[2][8] = TileType.quantumKey;
    g[12][2] = TileType.quantumKey;
    g[6][7] = TileType.quantumKey;

    // But
    g[13][8] = TileType.goalSingularity;

    return MazeLevel(
      id: 3,
      title: "SINGULARITÉ : DÉFI QUANTIQUE",
      cols: cols,
      rows: rows,
      playerStart: const Offset(2, 2),
      grid: g,
      totalKeys: 3,
    );
  }
}
