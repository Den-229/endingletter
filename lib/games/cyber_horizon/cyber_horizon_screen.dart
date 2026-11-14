import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/storage_service.dart';
import 'models_3d.dart';
import 'engine_3d.dart';

class CyberHorizonScreen extends StatefulWidget {
  const CyberHorizonScreen({super.key});

  @override
  State<CyberHorizonScreen> createState() => _CyberHorizonScreenState();
}

class _CyberHorizonScreenState extends State<CyberHorizonScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final math.Random _rnd = math.Random();

  // État du Joueur
  Point3D _playerPos = Point3D(0, 40, 60);
  Point3D _targetPos = Point3D(0, 40, 60);
  double _shipRoll = 0.0;
  double _shipPitch = 0.0;
  double _health = 100.0;
  double _bulletTimeEnergy = 100.0;
  bool _isBulletTimeActive = false;
  bool _isShieldActive = false;
  double _shieldDuration = 0.0;
  int _score = 0;
  int _highScore = 0;
  int _multiplier = 1;
  int _comboCount = 0;
  bool _isGameOver = false;
  final bool _isPaused = false;

  // Univers 3D
  final List<WorldEntity3D> _entities = [];
  final List<LaserBolt3D> _lasers = [];
  final List<Particle3D> _particles = [];
  final List<Point3D> _stars = [];
  double _gridOffset = 0.0;

  // Paramètres de vol
  final double _baseForwardSpeed = 240.0;
  double _lastTimestamp = 0;
  double _spawnTimer = 0;
  double _droneShootTimer = 0;

  // Clavier
  final Set<LogicalKeyboardKey> _pressedKeys = {};

  @override
  void initState() {
    super.initState();
    _highScore = StorageService.getCyberHighScore();
    _initStars();

    _ticker = AnimationController.unbounded(vsync: this)
      ..addListener(_onTick);
    _ticker.repeat(period: const Duration(days: 1));
  }

  void _initStars() {
    _stars.clear();
    for (int i = 0; i < 90; i++) {
      _stars.add(Point3D(
        (_rnd.nextDouble() - 0.5) * 1200,
        (_rnd.nextDouble() - 0.5) * 800 - 100,
        _rnd.nextDouble() * 900 + 40,
      ));
    }
  }

  void _onTick() {
    if (_isGameOver || _isPaused) return;

    final currentMs = _ticker.lastElapsedDuration?.inMicroseconds ?? 0;
    if (_lastTimestamp == 0) {
      _lastTimestamp = currentMs.toDouble();
      return;
    }
    double dt = (currentMs - _lastTimestamp) / 1000000.0;
    _lastTimestamp = currentMs.toDouble();
    if (dt > 0.1) dt = 0.033; // Anti-lag clamp

    // Ralenti quantique (Bullet Time)
    final timeFactor = _isBulletTimeActive ? 0.28 : 1.0;
    final effectiveDt = dt * timeFactor;

    _updateControls(dt);
    _updateFlightPhysics(effectiveDt, dt);
    _updateEntities(effectiveDt);
    _updateLasers(effectiveDt);
    _updateParticles(effectiveDt);
    _checkCollisions();

    setState(() {});
  }

  void _updateControls(double dt) {
    double moveX = 0;
    double moveY = 0;

    if (_pressedKeys.contains(LogicalKeyboardKey.arrowLeft) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyA)) {
      moveX -= 220;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowRight) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyD)) {
      moveX += 220;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowUp) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyW)) {
      moveY -= 180;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowDown) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyS)) {
      moveY += 180;
    }

    if (moveX != 0 || moveY != 0) {
      _targetPos.x = (_targetPos.x + moveX * dt).clamp(-180.0, 180.0);
      _targetPos.y = (_targetPos.y + moveY * dt).clamp(-120.0, 110.0);
    }

    // Lissage fluide du vaisseau vers la cible tactile ou clavier
    _playerPos.x += (_targetPos.x - _playerPos.x) * 12.0 * dt;
    _playerPos.y += (_targetPos.y - _playerPos.y) * 12.0 * dt;

    // Roulis dynamique selon la direction horizontale
    final targetRoll = ((_targetPos.x - _playerPos.x) / 30.0).clamp(-0.55, 0.55);
    _shipRoll += (targetRoll - _shipRoll) * 10.0 * dt;

    // Tangage selon le déplacement vertical
    final targetPitch = ((_targetPos.y - _playerPos.y) / 40.0).clamp(-0.25, 0.25);
    _shipPitch += (targetPitch - _shipPitch) * 10.0 * dt;
  }

  void _updateFlightPhysics(double effectiveDt, double realDt) {
    // Vitesse qui augmente graduellement avec le score
    final currentSpeed = _baseForwardSpeed + (_score / 25.0).clamp(0.0, 300.0);

    // Défilement de la grille sol
    _gridOffset = (_gridOffset + (currentSpeed * 0.0018 * effectiveDt)) % 1.0;

    // Gestion du Bouclier temporaire
    if (_isShieldActive) {
      _shieldDuration -= realDt;
      if (_shieldDuration <= 0) _isShieldActive = false;
    }

    // Gestion de l'énergie Bullet Time
    if (_isBulletTimeActive) {
      _bulletTimeEnergy -= realDt * 35.0;
      if (_bulletTimeEnergy <= 0) {
        _bulletTimeEnergy = 0;
        _isBulletTimeActive = false;
      }
    } else {
      if (_bulletTimeEnergy < 100.0) {
        _bulletTimeEnergy = math.min(100.0, _bulletTimeEnergy + realDt * 18.0);
      }
    }

    // Déplacement des étoiles vers la caméra
    for (final s in _stars) {
      s.z -= currentSpeed * effectiveDt;
      if (s.z < 10) {
        s.z = 900;
        s.x = (_rnd.nextDouble() - 0.5) * 1200;
        s.y = (_rnd.nextDouble() - 0.5) * 800 - 100;
      }
    }

    // Réacteur de particules du joueur
    _particles.add(Particle3D(
      pos: Point3D(_playerPos.x + (_rnd.nextDouble() - 0.5) * 8, _playerPos.y + 4, _playerPos.z - 20),
      vel: Point3D((_rnd.nextDouble() - 0.5) * 20, (_rnd.nextDouble() - 0.5) * 20, -140),
      color: _isBulletTimeActive ? Colors.cyanAccent : const Color(0xFFFF5500),
      size: 4.5,
      maxLife: 0.35,
    ));
  }

  void _updateEntities(double dt) {
    final currentSpeed = _baseForwardSpeed + (_score / 25.0).clamp(0.0, 300.0);

    // Génération périodique d'obstacles / bonus
    _spawnTimer += dt;
    if (_spawnTimer > 0.85) {
      _spawnTimer = 0;
      _spawnNextEntity();
    }

    // Tir des drones ennemis
    _droneShootTimer += dt;
    if (_droneShootTimer > 1.4) {
      _droneShootTimer = 0;
      for (final e in _entities) {
        if (e.type == EntityType.drone && e.pos.z > 200 && e.pos.z < 600) {
          _lasers.add(LaserBolt3D(
            pos: Point3D(e.pos.x, e.pos.y, e.pos.z),
            speed: -450.0,
            color: const Color(0xFFFF0055),
            isPlayer: false,
          ));
        }
      }
    }

    for (final e in _entities) {
      e.update(dt, currentSpeed);
    }
    _entities.removeWhere((e) => e.isDestroyed);
  }

  void _spawnNextEntity() {
    final roll = _rnd.nextDouble();
    final spawnZ = 800.0;
    final spawnX = (_rnd.nextDouble() - 0.5) * 360.0;
    final spawnY = (_rnd.nextDouble() - 0.5) * 220.0;

    if (roll < 0.45) {
      // Astéroïde
      _entities.add(WorldEntity3D(
        pos: Point3D(spawnX, spawnY, spawnZ),
        type: EntityType.asteroid,
        scale: 0.8 + _rnd.nextDouble() * 0.8,
        collisionRadius: 32.0,
      ));
    } else if (roll < 0.70) {
      // Drone ennemi
      _entities.add(WorldEntity3D(
        pos: Point3D(spawnX, spawnY, spawnZ),
        type: EntityType.drone,
        scale: 0.9,
        collisionRadius: 26.0,
        health: 2.0,
      ));
    } else if (roll < 0.85) {
      // Anneau de vitesse hyper-espace
      _entities.add(WorldEntity3D(
        pos: Point3D(spawnX * 0.5, spawnY * 0.5, spawnZ),
        type: EntityType.ringGate,
        scale: 1.1,
        collisionRadius: 55.0,
      ));
    } else {
      // Cristal d'énergie quantique
      _entities.add(WorldEntity3D(
        pos: Point3D(spawnX * 0.7, spawnY * 0.7, spawnZ),
        type: EntityType.energyCore,
        scale: 1.0,
        collisionRadius: 24.0,
      ));
    }
  }

  void _updateLasers(double dt) {
    for (final l in _lasers) {
      l.update(dt);
    }
    _lasers.removeWhere((l) => !l.isAlive);
  }

  void _updateParticles(double dt) {
    _particles.removeWhere((p) => !p.update(dt));
  }

  void _checkCollisions() {
    // 1. Lasers du joueur vs Entités
    for (final laser in _lasers.where((l) => l.isPlayer && l.isAlive)) {
      for (final entity in _entities.where((e) => !e.isDestroyed)) {
        if (entity.type == EntityType.ringGate) continue;
        final dx = laser.pos.x - entity.pos.x;
        final dy = laser.pos.y - entity.pos.y;
        final dz = laser.pos.z - entity.pos.z;
        final dist = math.sqrt(dx * dx + dy * dy + dz * dz);

        if (dist < entity.collisionRadius * entity.scale) {
          laser.isAlive = false;
          entity.health -= 1.0;
          _createExplosion(laser.pos, Colors.yellowAccent, 8);
          FeedbackService.triggerLight();

          if (entity.health <= 0) {
            entity.isDestroyed = true;
            _createExplosion(
              entity.pos,
              entity.type == EntityType.drone ? const Color(0xFFFF2A6D) : const Color(0xFF00FFCC),
              20,
            );
            _score += 150 * _multiplier;
            _comboCount++;
            if (_comboCount % 5 == 0) _multiplier++;
            FeedbackService.triggerImpact();
          }
          break;
        }
      }
    }

    // 2. Vaisseau du joueur vs Entités
    for (final entity in _entities.where((e) => !e.isDestroyed)) {
      final dx = _playerPos.x - entity.pos.x;
      final dy = _playerPos.y - entity.pos.y;
      final dz = _playerPos.z - entity.pos.z;
      final dist = math.sqrt(dx * dx + dy * dy + dz * dz);

      if (dist < (entity.collisionRadius + 22.0)) {
        if (entity.type == EntityType.energyCore) {
          // Bonus collecté !
          entity.isDestroyed = true;
          _score += 300 * _multiplier;
          _health = math.min(100.0, _health + 20.0);
          _isShieldActive = true;
          _shieldDuration = 4.0;
          _createExplosion(_playerPos, const Color(0xFF00FFCC), 16);
          FeedbackService.triggerSuccess();
        } else if (entity.type == EntityType.ringGate) {
          // Traversée d'anneau : accélération et boost combo
          entity.isDestroyed = true;
          _score += 500 * _multiplier;
          _multiplier = math.min(10, _multiplier + 1);
          _createExplosion(_playerPos, const Color(0xFF05D9E8), 12);
          FeedbackService.triggerSuccess();
        } else {
          // Collision obstacle / ennemi
          entity.isDestroyed = true;
          _createExplosion(_playerPos, Colors.redAccent, 24);
          FeedbackService.triggerImpact();

          if (!_isShieldActive) {
            _health -= 35.0;
            _comboCount = 0;
            _multiplier = 1;
            if (_health <= 0) {
              _triggerGameOver();
            }
          }
        }
      }
    }

    // 3. Lasers ennemis vs Vaisseau
    for (final laser in _lasers.where((l) => !l.isPlayer && l.isAlive)) {
      final dx = laser.pos.x - _playerPos.x;
      final dy = laser.pos.y - _playerPos.y;
      final dz = laser.pos.z - _playerPos.z;
      final dist = math.sqrt(dx * dx + dy * dy + dz * dz);

      if (dist < 26.0) {
        laser.isAlive = false;
        _createExplosion(_playerPos, Colors.red, 12);
        FeedbackService.triggerImpact();
        if (!_isShieldActive) {
          _health -= 15.0;
          if (_health <= 0) _triggerGameOver();
        }
      }
    }
  }

  void _createExplosion(Point3D center, Color color, int count) {
    for (int i = 0; i < count; i++) {
      final speed = 80.0 + _rnd.nextDouble() * 120.0;
      final theta = _rnd.nextDouble() * 2 * math.pi;
      final phi = _rnd.nextDouble() * math.pi;

      _particles.add(Particle3D(
        pos: center.copy(),
        vel: Point3D(
          speed * math.sin(phi) * math.cos(theta),
          speed * math.sin(phi) * math.sin(theta),
          speed * math.cos(phi),
        ),
        color: color,
        size: 3.0 + _rnd.nextDouble() * 3.5,
        maxLife: 0.4 + _rnd.nextDouble() * 0.4,
      ));
    }
  }

  void _fireLaser() {
    if (_isGameOver || _isPaused) return;

    // Double canon plasma
    _lasers.add(LaserBolt3D(
      pos: Point3D(_playerPos.x - 14, _playerPos.y, _playerPos.z + 10),
      speed: 680.0,
      color: const Color(0xFF00F0FF),
      isPlayer: true,
    ));
    _lasers.add(LaserBolt3D(
      pos: Point3D(_playerPos.x + 14, _playerPos.y, _playerPos.z + 10),
      speed: 680.0,
      color: const Color(0xFF00F0FF),
      isPlayer: true,
    ));
    FeedbackService.triggerLight();
  }

  void _toggleBulletTime() {
    if (_bulletTimeEnergy > 20.0 && !_isGameOver) {
      setState(() {
        _isBulletTimeActive = !_isBulletTimeActive;
      });
      FeedbackService.triggerSelection();
    }
  }

  void _triggerGameOver() {
    _health = 0;
    _isGameOver = true;
    _isBulletTimeActive = false;
    _createExplosion(_playerPos, Colors.orangeAccent, 40);
    StorageService.saveCyberHighScore(_score);
    _highScore = math.max(_highScore, _score);
  }

  void _restartGame() {
    setState(() {
      _health = 100.0;
      _score = 0;
      _multiplier = 1;
      _comboCount = 0;
      _bulletTimeEnergy = 100.0;
      _isBulletTimeActive = false;
      _isShieldActive = false;
      _isGameOver = false;
      _entities.clear();
      _lasers.clear();
      _particles.clear();
      _playerPos = Point3D(0, 40, 60);
      _targetPos = Point3D(0, 40, 60);
      _initStars();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            _pressedKeys.add(event.logicalKey);
            if (event.logicalKey == LogicalKeyboardKey.space) {
              _fireLaser();
            } else if (event.logicalKey == LogicalKeyboardKey.shiftLeft) {
              _toggleBulletTime();
            }
          } else if (event is KeyUpEvent) {
            _pressedKeys.remove(event.logicalKey);
          }
          return KeyEventResult.handled;
        },
        child: Stack(
          children: [
            // 1. Scène 3D avec détection des gestes tactiles
            Positioned.fill(
              child: GestureDetector(
                onPanUpdate: (details) {
                  // Déplacement tactile fluide
                  setState(() {
                    _targetPos.x = (_targetPos.x + details.delta.dx * 0.9).clamp(-180.0, 180.0);
                    _targetPos.y = (_targetPos.y + details.delta.dy * 0.9).clamp(-120.0, 110.0);
                  });
                },
                child: CustomPaint(
                  painter: CyberHorizon3DPainter(
                    playerPos: _playerPos,
                    shipRoll: _shipRoll,
                    shipPitch: _shipPitch,
                    entities: _entities,
                    lasers: _lasers,
                    particles: _particles,
                    stars: _stars,
                    gridOffset: _gridOffset,
                    bulletTimeFactor: _isBulletTimeActive ? 0.3 : 1.0,
                    isShieldActive: _isShieldActive,
                  ),
                ),
              ),
            ),

            // 2. HUD Futuriste Néon en haut
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Santé et Shield
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isShieldActive ? Icons.shield : Icons.favorite,
                            color: _isShieldActive ? Colors.cyanAccent : Colors.redAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 110,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _health / 100.0,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation(
                                  _health > 30 ? const Color(0xFF00FFCC) : Colors.redAccent,
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Jauge Bullet Time
                      Row(
                        children: [
                          const Icon(Icons.bolt, color: Colors.purpleAccent, size: 18),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 110,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _bulletTimeEnergy / 100.0,
                                backgroundColor: Colors.white10,
                                valueColor: const AlwaysStoppedAnimation(Color(0xFFE056FD)),
                                minHeight: 5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Score & Combo Multiplier
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$_score PTS',
                        style: const TextStyle(
                          color: Color(0xFF00F0FF),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          shadows: [
                            Shadow(color: Color(0xFF00F0FF), blurRadius: 10),
                          ],
                        ),
                      ),
                      Text(
                        'COMBO x$_multiplier  (RECORD: $_highScore)',
                        style: const TextStyle(
                          color: Color(0xFFFF007F),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Boutons d'action tactiles en bas
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Bouton Bullet-Time (Slow Motion)
                  GestureDetector(
                    onTap: _toggleBulletTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isBulletTimeActive
                            ? const Color(0xFFE056FD).withValues(alpha: 0.4)
                            : Colors.black54,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: _isBulletTimeActive ? Colors.purpleAccent : Colors.white24,
                          width: 2,
                        ),
                        boxShadow: _isBulletTimeActive
                            ? [const BoxShadow(color: Colors.purpleAccent, blurRadius: 15)]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.hourglass_bottom,
                            color: _isBulletTimeActive ? Colors.purpleAccent : Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isBulletTimeActive ? 'BULLET-TIME [ON]' : 'MATRIX SLOW',
                            style: TextStyle(
                              color: _isBulletTimeActive ? Colors.purpleAccent : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bouton TIR PLASMA
                  GestureDetector(
                    onTap: _fireLaser,
                    child: Container(
                      width: 75,
                      height: 75,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00F0FF), Color(0xFF7000FF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00F0FF).withValues(alpha: 0.5),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.flash_on, color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Modal Game Over
            if (_isGameOver)
              Container(
                color: Colors.black.withValues(alpha: 0.85),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF100926),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFF0055), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF0055).withValues(alpha: 0.4),
                          blurRadius: 25,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'MISSION ÉCHOUÉE',
                          style: TextStyle(
                            color: Color(0xFFFF0055),
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'SCORE FINAL : $_score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'MEILLEUR RECORD : $_highScore',
                          style: const TextStyle(
                            color: Color(0xFF00FFCC),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back, color: Colors.white70),
                              label: const Text('MENU', style: TextStyle(color: Colors.white70)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _restartGame,
                              icon: const Icon(Icons.replay, color: Colors.black),
                              label: const Text(
                                'REJOUER',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00FFCC),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bouton retour en haut à gauche
            Positioned(
              top: 40,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
