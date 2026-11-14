import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/storage_service.dart';
import 'physics_engine.dart';

class GraviPortalScreen extends StatefulWidget {
  const GraviPortalScreen({super.key});

  @override
  State<GraviPortalScreen> createState() => _GraviPortalScreenState();
}

class _GraviPortalScreenState extends State<GraviPortalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final List<MazeLevel> _levels = MazeLevel.getStandardLevels();
  int _currentLevelIndex = 0;

  late MazeLevel _level;
  late List<List<TileType>> _grid;
  late QuantumOrb _orb;
  GravityDirection _gravity = GravityDirection.down;
  double _lastTimestamp = 0;

  int _collectedKeys = 0;
  int _movesCount = 0;
  double _elapsedTime = 0.0;
  bool _isLevelWon = false;
  bool _isDead = false;
  int _highScore = 0;

  // Téléportation cooldown
  double _portalCooldown = 0.0;

  @override
  void initState() {
    super.initState();
    _highScore = StorageService.getGraviHighScore();
    _loadLevel(_currentLevelIndex);

    _ticker = AnimationController.unbounded(vsync: this)
      ..addListener(_onTick);
    _ticker.repeat(period: const Duration(days: 1));
  }

  void _loadLevel(int index) {
    _currentLevelIndex = index;
    final proto = _levels[index];
    _level = proto;
    // Copie de la grille
    _grid = List.generate(
      proto.rows,
      (r) => List.generate(proto.cols, (c) => proto.grid[r][c]),
    );

    // Initialisation orbe
    const tileSize = 36.0;
    _orb = QuantumOrb(
      position: Offset(
        proto.playerStart.dx * tileSize + tileSize / 2,
        proto.playerStart.dy * tileSize + tileSize / 2,
      ),
    );

    _gravity = GravityDirection.down;
    _collectedKeys = 0;
    _movesCount = 0;
    _elapsedTime = 0.0;
    _isLevelWon = false;
    _isDead = false;
    _portalCooldown = 0.0;
  }

  void _setGravity(GravityDirection newDir) {
    if (_gravity != newDir && !_isLevelWon && !_isDead) {
      setState(() {
        _gravity = newDir;
        _movesCount++;
      });
      FeedbackService.triggerLight();
    }
  }

  void _onTick() {
    if (_isLevelWon || _isDead) return;

    final currentMs = _ticker.lastElapsedDuration?.inMicroseconds ?? 0;
    if (_lastTimestamp == 0) {
      _lastTimestamp = currentMs.toDouble();
      return;
    }
    double dt = (currentMs - _lastTimestamp) / 1000000.0;
    _lastTimestamp = currentMs.toDouble();
    if (dt > 0.1) dt = 0.033;

    _elapsedTime += dt;
    if (_portalCooldown > 0) _portalCooldown -= dt;

    _updatePhysics(dt);
    setState(() {});
  }

  void _updatePhysics(double dt) {
    // Calcul de l'accélération de gravité
    const double gMagnitude = 850.0;
    Offset gAcc = Offset.zero;
    switch (_gravity) {
      case GravityDirection.down:
        gAcc = const Offset(0, gMagnitude);
        break;
      case GravityDirection.up:
        gAcc = const Offset(0, -gMagnitude);
        break;
      case GravityDirection.left:
        gAcc = const Offset(-gMagnitude, 0);
        break;
      case GravityDirection.right:
        gAcc = const Offset(gMagnitude, 0);
        break;
    }

    _orb.velocity += gAcc * dt;
    // Résistance de l'air
    _orb.velocity *= math.pow(0.985, dt * 60).toDouble();

    // Déplacement
    Offset newPos = _orb.position + _orb.velocity * dt;

    // Détection de collision avec les tuiles
    const tileSize = 36.0;
    final r = _orb.radius;

    // Vérifier les 4 coins et centre
    final checkOffsets = [
      Offset(newPos.dx - r, newPos.dy),
      Offset(newPos.dx + r, newPos.dy),
      Offset(newPos.dx, newPos.dy - r),
      Offset(newPos.dx, newPos.dy + r),
      newPos,
    ];

    bool collidedHorizontal = false;
    bool collidedVertical = false;

    for (final pt in checkOffsets) {
      final col = (pt.dx / tileSize).floor();
      final row = (pt.dy / tileSize).floor();

      if (row >= 0 && row < _level.rows && col >= 0 && col < _level.cols) {
        final tile = _grid[row][col];

        if (tile == TileType.wall) {
          // Collision mur standard
          final tileCenterX = col * tileSize + tileSize / 2;
          final tileCenterY = row * tileSize + tileSize / 2;
          final diffX = newPos.dx - tileCenterX;
          final diffY = newPos.dy - tileCenterY;

          if (diffX.abs() > diffY.abs()) {
            _orb.velocity = Offset(-_orb.velocity.dx * 0.45, _orb.velocity.dy);
            collidedHorizontal = true;
          } else {
            _orb.velocity = Offset(_orb.velocity.dx, -_orb.velocity.dy * 0.45);
            collidedVertical = true;
          }
          FeedbackService.triggerLight();
        } else if (tile == TileType.bouncyWall) {
          // Rebond ultra dynamique
          _orb.velocity = -_orb.velocity * 1.3;
          FeedbackService.triggerImpact();
        } else if (tile == TileType.quantumKey) {
          // Ramassage de clé
          _grid[row][col] = TileType.empty;
          _collectedKeys++;
          FeedbackService.triggerSuccess();
        } else if (tile == TileType.laserHazard) {
          // Mort au contact du laser
          _isDead = true;
          FeedbackService.triggerImpact();
          return;
        } else if (tile == TileType.portalBlue && _portalCooldown <= 0) {
          // Téléportation vers portail orange
          if (_level.portals != null) {
            final exit = _level.portals!.exit;
            newPos = Offset(exit.dx * tileSize + tileSize / 2, exit.dy * tileSize + tileSize / 2);
            _portalCooldown = 0.6;
            FeedbackService.triggerSuccess();
          }
        } else if (tile == TileType.portalOrange && _portalCooldown <= 0) {
          // Téléportation vers portail bleu
          if (_level.portals != null) {
            final entrance = _level.portals!.entrance;
            newPos = Offset(entrance.dx * tileSize + tileSize / 2, entrance.dy * tileSize + tileSize / 2);
            _portalCooldown = 0.6;
            FeedbackService.triggerSuccess();
          }
        } else if (tile == TileType.goalSingularity) {
          // Atteinte de l'objectif si toutes les clés sont acquises
          if (_collectedKeys >= _level.totalKeys) {
            _triggerVictory();
            return;
          }
        }
      }
    }

    if (!collidedHorizontal && !collidedVertical) {
      _orb.position = newPos;
    } else {
      // Re-clamp position si collision
      _orb.position += _orb.velocity * dt;
    }

    _orb.updateTrail();
  }

  void _triggerVictory() {
    _isLevelWon = true;
    FeedbackService.triggerSuccess();
    final levelScore = math.max(100, 1000 - (_elapsedTime * 20).toInt() - (_movesCount * 15));
    StorageService.saveGraviHighScore(levelScore);
    _highScore = math.max(_highScore, levelScore);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const tileSize = 36.0;
    final mazeWidth = _level.cols * tileSize;
    final mazeHeight = _level.rows * tileSize;

    return Scaffold(
      backgroundColor: const Color(0xFF070B19),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.keyS) {
              _setGravity(GravityDirection.down);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.keyW) {
              _setGravity(GravityDirection.up);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.keyA) {
              _setGravity(GravityDirection.left);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.keyD) {
              _setGravity(GravityDirection.right);
            }
          }
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          onPanEnd: (details) {
            final vx = details.velocity.pixelsPerSecond.dx;
            final vy = details.velocity.pixelsPerSecond.dy;
            if (vx.abs() > vy.abs()) {
              if (vx > 100) _setGravity(GravityDirection.right);
              if (vx < -100) _setGravity(GravityDirection.left);
            } else {
              if (vy > 100) _setGravity(GravityDirection.down);
              if (vy < -100) _setGravity(GravityDirection.up);
            }
          },
          child: Stack(
            children: [
              // 1. Fond avec lueurs quantiques
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.3),
                      radius: 1.1,
                      colors: [Color(0xFF0F1E3D), Color(0xFF050710)],
                    ),
                  ),
                ),
              ),

              // 2. HUD Supérieur
              Positioned(
                top: 40,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Column(
                      children: [
                        Text(
                          _level.title,
                          style: const TextStyle(
                            color: Color(0xFF00FFCC),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.vpn_key, color: Colors.amberAccent, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$_collectedKeys / ${_level.totalKeys}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.timer_outlined, color: Colors.cyanAccent, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${_elapsedTime.toStringAsFixed(1)}s',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: () => _loadLevel(_currentLevelIndex),
                    ),
                  ],
                ),
              ),

              // 3. Aire de jeu du labyrinthe quantique centrée
              Center(
                child: Container(
                  width: mazeWidth,
                  height: mazeHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF091026),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _GraviMazePainter(
                      grid: _grid,
                      cols: _level.cols,
                      rows: _level.rows,
                      tileSize: tileSize,
                      orb: _orb,
                      gravity: _gravity,
                      allKeysFound: _collectedKeys >= _level.totalKeys,
                    ),
                  ),
                ),
              ),

              // 4. Pavé directionnel tactile de gravité en bas
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Cercle central indicateur de gravité
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF00FFCC).withValues(alpha: 0.2),
                            border: Border.all(color: const Color(0xFF00FFCC), width: 2),
                          ),
                          child: Icon(
                            _getGravityIcon(_gravity),
                            color: const Color(0xFF00FFCC),
                            size: 26,
                          ),
                        ),
                        // Bouton HAUT
                        Align(
                          alignment: Alignment.topCenter,
                          child: _gravityArrowButton(GravityDirection.up, Icons.keyboard_arrow_up),
                        ),
                        // Bouton BAS
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: _gravityArrowButton(GravityDirection.down, Icons.keyboard_arrow_down),
                        ),
                        // Bouton GAUCHE
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _gravityArrowButton(GravityDirection.left, Icons.keyboard_arrow_left),
                        ),
                        // Bouton DROITE
                        Align(
                          alignment: Alignment.centerRight,
                          child: _gravityArrowButton(GravityDirection.right, Icons.keyboard_arrow_right),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Modal Victoire
              if (_isLevelWon)
                Container(
                  color: Colors.black.withValues(alpha: 0.85),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1E3D),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00FFCC), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FFCC).withValues(alpha: 0.4),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFF00FFCC), size: 55),
                          const SizedBox(height: 12),
                          const Text(
                            'FAILLE QUANTIQUE FRANCHIE !',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF00FFCC),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Temps : ${_elapsedTime.toStringAsFixed(2)}s | Gravités : $_movesCount',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              OutlinedButton(
                                onPressed: () => _loadLevel(_currentLevelIndex),
                                child: const Text('REJOUER', style: TextStyle(color: Colors.white)),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  if (_currentLevelIndex + 1 < _levels.length) {
                                    _loadLevel(_currentLevelIndex + 1);
                                  } else {
                                    Navigator.of(context).pop();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00FFCC),
                                ),
                                child: Text(
                                  _currentLevelIndex + 1 < _levels.length
                                      ? 'NIVEAU SUIVANT'
                                      : 'TERMINER',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 6. Modal Défaite (Laser)
              if (_isDead)
                Container(
                  color: Colors.black.withValues(alpha: 0.85),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF260D19),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.redAccent, width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 55),
                          const SizedBox(height: 12),
                          const Text(
                            'DÉSINTÉGRATION LASER',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => _loadLevel(_currentLevelIndex),
                            icon: const Icon(Icons.refresh, color: Colors.black),
                            label: const Text('RÉESSAYER', style: TextStyle(color: Colors.black)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gravityArrowButton(GravityDirection dir, IconData icon) {
    final isSelected = _gravity == dir;
    return GestureDetector(
      onTap: () => _setGravity(dir),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00FFCC) : Colors.white10,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [const BoxShadow(color: Color(0xFF00FFCC), blurRadius: 10)]
              : [],
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.black : Colors.white70,
          size: 28,
        ),
      ),
    );
  }

  IconData _getGravityIcon(GravityDirection dir) {
    switch (dir) {
      case GravityDirection.down:
        return Icons.arrow_downward;
      case GravityDirection.up:
        return Icons.arrow_upward;
      case GravityDirection.left:
        return Icons.arrow_back;
      case GravityDirection.right:
        return Icons.arrow_forward;
    }
  }
}

class _GraviMazePainter extends CustomPainter {
  final List<List<TileType>> grid;
  final int cols;
  final int rows;
  final double tileSize;
  final QuantumOrb orb;
  final GravityDirection gravity;
  final bool allKeysFound;

  _GraviMazePainter({
    required this.grid,
    required this.cols,
    required this.rows,
    required this.tileSize,
    required this.orb,
    required this.gravity,
    required this.allKeysFound,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dessin de la grille et des obstacles
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(c * tileSize, r * tileSize, tileSize, tileSize);
        final tile = grid[r][c];

        switch (tile) {
          case TileType.wall:
            final wallPaint = Paint()..color = const Color(0xFF1E294B);
            canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), wallPaint);
            final borderPaint = Paint()
              ..color = const Color(0xFF3B4D80)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0;
            canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), borderPaint);
            break;

          case TileType.bouncyWall:
            final bPaint = Paint()..color = const Color(0xFFFF007F);
            canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), bPaint);
            break;

          case TileType.portalBlue:
            final pPaint = Paint()..color = const Color(0xFF00F0FF);
            canvas.drawCircle(rect.center, tileSize * 0.38, pPaint);
            break;

          case TileType.portalOrange:
            final pPaint = Paint()..color = const Color(0xFFFF9900);
            canvas.drawCircle(rect.center, tileSize * 0.38, pPaint);
            break;

          case TileType.laserHazard:
            final lPaint = Paint()..color = Colors.redAccent.withValues(alpha: 0.85);
            canvas.drawRect(rect.deflate(6), lPaint);
            break;

          case TileType.quantumKey:
            final keyPaint = Paint()..color = Colors.amberAccent;
            canvas.drawCircle(rect.center, 7.0, keyPaint);
            break;

          case TileType.goalSingularity:
            final goalPaint = Paint()
              ..color = allKeysFound ? const Color(0xFF00FFCC) : Colors.white24
              ..style = PaintingStyle.fill;
            canvas.drawCircle(rect.center, tileSize * 0.42, goalPaint);
            break;

          case TileType.empty:
            break;
        }
      }
    }

    // 2. Traînée de l'orbe quantique
    for (int i = 0; i < orb.trail.length; i++) {
      final alpha = (1.0 - (i / orb.trail.length)).clamp(0.0, 1.0);
      final trailPaint = Paint()
        ..color = const Color(0xFF00FFCC).withValues(alpha: alpha * 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(orb.trail[i], orb.radius * (1.0 - i * 0.05), trailPaint);
    }

    // 3. Dessin de l'orbe quantique
    final orbPaint = Paint()..color = const Color(0xFF00FFCC);
    canvas.drawCircle(orb.position, orb.radius, orbPaint);

    final glowPaint = Paint()
      ..color = const Color(0xFF00FFCC).withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(orb.position, orb.radius * 1.3, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _GraviMazePainter oldDelegate) => true;
}
