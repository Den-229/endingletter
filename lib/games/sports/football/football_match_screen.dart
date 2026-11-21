import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'football_models.dart';
import 'football_engine.dart';
import '../../../services/storage_service.dart';

enum FootballCameraMode {
  broadcast, // Vue Télévision Diffusion PES (Perspective latérale classique)
  action,    // Vue Rapprochée Action (Zoom dynamique centré sur le ballon)
  tactical,  // Vue Tactique Aérienne d'Ensemble
}

class TurfParticle {
  double x;
  double y;
  double vx;
  double vy;
  double life; // 1.0 à 0.0
  Color color;

  TurfParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.color,
  });
}

class StadiumFlash {
  double x;
  double y;
  double life;

  StadiumFlash({
    required this.x,
    required this.y,
    required this.life,
  });
}

class FootballMatchScreen extends StatefulWidget {
  final FootballTeam teamA;
  final FootballTeam teamB;

  const FootballMatchScreen({
    super.key,
    required this.teamA,
    required this.teamB,
  });

  @override
  State<FootballMatchScreen> createState() => _FootballMatchScreenState();
}

class _FootballMatchScreenState extends State<FootballMatchScreen> with SingleTickerProviderStateMixin {
  late FootballEngine _engine;
  late AnimationController _ticker;
  double _lastTimestamp = 0.0;

  bool _showGoalBanner = false;
  String _goalMessage = '';
  double _shotCharge = 0.0;
  bool _isChargingShot = false;
  FootballCameraMode _cameraMode = FootballCameraMode.broadcast;
  FootballPlayer? _lastScorer;
  Offset _cameraOffset = const Offset(0.50, 0.50);

  // Contrôles Clavier & Manette
  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _activeKeys = {};
  bool _isTouchJoystickActive = false;

  // Effets vivants de stade & supporters
  double _crowdAnimTime = 0.0;
  final List<TurfParticle> _turfParticles = [];
  final List<StadiumFlash> _cameraFlashes = [];
  final math.Random _rnd = math.Random(1337);
  double _goalNetBulge = 0.0;

  @override
  void initState() {
    super.initState();
    _engine = FootballEngine(teamA: widget.teamA, teamB: widget.teamB);
    _engine.onGoal = _handleGoal;
    _engine.onFullTime = _handleFullTime;

    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_onTick)
      ..repeat();

    StorageService.recordGamePlayed('football');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ticker.dispose();
    super.dispose();
  }

  void _cycleCamera() {
    FeedbackService.triggerSelection();
    setState(() {
      switch (_cameraMode) {
        case FootballCameraMode.broadcast:
          _cameraMode = FootballCameraMode.action;
          break;
        case FootballCameraMode.action:
          _cameraMode = FootballCameraMode.tactical;
          break;
        case FootballCameraMode.tactical:
          _cameraMode = FootballCameraMode.broadcast;
          break;
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final teamAHasBall = _engine.ballCarrier != null && widget.teamA.players.contains(_engine.ballCarrier);

    if (event is KeyDownEvent) {
      _activeKeys.add(event.logicalKey);

      // Espace / Touche L : Tir ou Tacle
      if (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.keyL) {
        if (teamAHasBall) {
          setState(() {
            _isChargingShot = true;
            _shotCharge = 0.2;
          });
        } else {
          _engine.tackleBall();
        }
        return KeyEventResult.handled;
      }

      // X / J : Passe courte ou Changement de joueur
      if (event.logicalKey == LogicalKeyboardKey.keyX || event.logicalKey == LogicalKeyboardKey.keyJ) {
        if (teamAHasBall) {
          _engine.passBall();
        } else {
          _engine.switchActivePlayer();
        }
        return KeyEventResult.handled;
      }

      // C / F : Tacle ou Pressing
      if (event.logicalKey == LogicalKeyboardKey.keyC || event.logicalKey == LogicalKeyboardKey.keyF) {
        _engine.tackleBall();
        return KeyEventResult.handled;
      }

      // V : Passe longue / Centre / Lob
      if (event.logicalKey == LogicalKeyboardKey.keyV) {
        if (teamAHasBall) {
          _engine.shootBall(0.60);
        } else {
          _engine.tackleBall();
        }
        return KeyEventResult.handled;
      }

      // Touche C pour changer de caméra
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        _cycleCamera();
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      _activeKeys.remove(event.logicalKey);

      if (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.keyL) {
        if (_isChargingShot) {
          setState(() => _isChargingShot = false);
          _engine.shootBall(_shotCharge);
        }
        return KeyEventResult.handled;
      }
    }

    _updateKeyboardDirection();
    return KeyEventResult.handled;
  }

  void _updateKeyboardDirection() {
    final up = _activeKeys.contains(LogicalKeyboardKey.keyW) ||
        _activeKeys.contains(LogicalKeyboardKey.keyZ) ||
        _activeKeys.contains(LogicalKeyboardKey.arrowUp);
    final down = _activeKeys.contains(LogicalKeyboardKey.keyS) ||
        _activeKeys.contains(LogicalKeyboardKey.arrowDown);
    final left = _activeKeys.contains(LogicalKeyboardKey.keyA) ||
        _activeKeys.contains(LogicalKeyboardKey.keyQ) ||
        _activeKeys.contains(LogicalKeyboardKey.arrowLeft);
    final right = _activeKeys.contains(LogicalKeyboardKey.keyD) ||
        _activeKeys.contains(LogicalKeyboardKey.arrowRight);

    final sprint = _activeKeys.contains(LogicalKeyboardKey.shiftLeft) ||
        _activeKeys.contains(LogicalKeyboardKey.shiftRight) ||
        _activeKeys.contains(LogicalKeyboardKey.keyR);

    double dx = 0.0;
    double dy = 0.0;
    if (up) dy -= 1.0;
    if (down) dy += 1.0;
    if (left) dx -= 1.0;
    if (right) dx += 1.0;

    if (dx != 0.0 || dy != 0.0) {
      final mag = math.sqrt(dx * dx + dy * dy);
      _engine.joystickA = Offset(dx / mag, dy / mag);
    } else if (!_isTouchJoystickActive) {
      _engine.joystickA = Offset.zero;
    }

    _engine.isSprintingA = sprint;
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

    if (_isChargingShot) {
      _shotCharge = (_shotCharge + dt * 1.5).clamp(0.0, 1.0);
    }

    // Suivi fluide de la caméra façon TV Broadcast PES (avec anticipation du jeu)
    final targetPos = _engine.ballCarrier?.pos ?? _engine.ballPos;
    final leadX = (_engine.ballVelocity.dx * 0.12).clamp(-0.06, 0.06);
    final camTarget = Offset(
      (targetPos.dx + leadX).clamp(0.12, 0.88),
      targetPos.dy.clamp(0.18, 0.82),
    );
    _cameraOffset = Offset.lerp(_cameraOffset, camTarget, 0.08)!;

    setState(() {
      _engine.update(dt);
      _crowdAnimTime += dt * 3.8;

      // Amorti du filet de but
      if (_goalNetBulge > 0.01) {
        _goalNetBulge *= 0.94;
      }

      // Éjection de brins d'herbe / terre (Turf Particles) sous les crampons
      if (_engine.activePlayerA.isSliding || _engine.isSprintingA || _engine.ballCarrier != null) {
        final pos = _engine.activePlayerA.pos;
        if (_rnd.nextDouble() < 0.45) {
          _turfParticles.add(TurfParticle(
            x: pos.dx + (_rnd.nextDouble() - 0.5) * 0.02,
            y: pos.dy + (_rnd.nextDouble() - 0.5) * 0.02,
            vx: (_rnd.nextDouble() - 0.5) * 0.06,
            vy: -0.04 - _rnd.nextDouble() * 0.05,
            life: 0.6,
            color: _rnd.nextBool() ? const Color(0xFF1E824C) : const Color(0xFF27AE60),
          ));
        }
      }

      // Mise à jour de la physique des particules de pelouse
      for (final p in _turfParticles) {
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.vy += 0.15 * dt; // Gravité
        p.life -= dt * 1.8;
      }
      _turfParticles.removeWhere((p) => p.life <= 0);

      // Flashs d'appareils photo aléatoires dans les tribunes de supporters
      if (_rnd.nextDouble() < 0.22) {
        _cameraFlashes.add(StadiumFlash(
          x: 0.04 + _rnd.nextDouble() * 0.92,
          y: 0.005 + _rnd.nextDouble() * 0.038,
          life: 0.22,
        ));
      }
      for (final f in _cameraFlashes) {
        f.life -= dt * 4.2;
      }
      _cameraFlashes.removeWhere((f) => f.life <= 0);
    });
  }

  void _handleGoal() {
    FootballPlayer scorer;
    if (_engine.ballPos.dx > 0.8) {
      scorer = _engine.ballCarrier ?? widget.teamA.players.firstWhere((p) => p.role == PlayerRole.fwd, orElse: () => widget.teamA.players.first);
    } else {
      scorer = _engine.ballCarrier ?? widget.teamB.players.firstWhere((p) => p.role == PlayerRole.fwd, orElse: () => widget.teamB.players.first);
    }

    setState(() {
      _lastScorer = scorer;
      _showGoalBanner = true;
      _goalMessage = 'GOOOOOOAL !';
      _goalNetBulge = 1.0; // Vibration intense du filet
    });

    FeedbackService.triggerSuccess();

    Future.delayed(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      setState(() {
        _showGoalBanner = false;
        _engine.resetKickoff(teamAServing: _engine.scoreA <= _engine.scoreB);
      });
    });
  }

  void _handleFullTime() {
    _showMatchStatsDialog();
  }

  void _showMatchStatsDialog() {
    final totalPoss = _engine.possessionSecondsA + _engine.possessionSecondsB;
    final possA = ((_engine.possessionSecondsA / totalPoss) * 100).round();
    final possB = 100 - possA;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1524),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF00FFCC), width: 1.5),
        ),
        title: const Center(
          child: Text(
            'FIN DU MATCH',
            style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(widget.teamA.emblem, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 4),
                    Text(widget.teamA.shortName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('${_engine.scoreA}', style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 28, fontWeight: FontWeight.w900)),
                  ],
                ),
                const Text('VS', style: TextStyle(color: Colors.white30, fontSize: 18, fontWeight: FontWeight.bold)),
                Column(
                  children: [
                    Text(widget.teamB.emblem, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 4),
                    Text(widget.teamB.shortName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('${_engine.scoreB}', style: const TextStyle(color: Color(0xFFFF0055), fontSize: 28, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 28),
            _buildStatRow('Possession', '$possA%', '$possB%'),
            _buildStatRow('Tirs Totaux', '${_engine.shotsA}', '${_engine.shotsB}'),
            _buildStatRow('Tirs Cadrés', '${_engine.shotsOnTargetA}', '${_engine.shotsOnTargetB}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('QUITTER', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FFCC),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _engine = FootballEngine(teamA: widget.teamA, teamB: widget.teamB);
                _engine.onGoal = _handleGoal;
                _engine.onFullTime = _handleFullTime;
              });
            },
            child: const Text('REJOUER LE MATCH', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String valA, String valB) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(valA, style: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(valB, style: const TextStyle(color: Color(0xFFFF0055), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamAHasBall = _engine.ballCarrier != null && widget.teamA.players.contains(_engine.ballCarrier);
    final isWide = MediaQuery.of(context).size.width >= 700;

    final pitchWidget = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 20),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _FootballPitchPainter(
                teamA: widget.teamA,
                teamB: widget.teamB,
                activePlayerA: _engine.activePlayerA,
                activePlayerB: _engine.activePlayerB,
                ballPos: _engine.ballPos,
                ballHeight: _engine.ballHeight,
                cameraMode: _cameraMode,
                cameraOffset: _cameraOffset,
                passTargetPos: _engine.passTargetPos,
                passTrajectoryTimer: _engine.passTrajectoryTimer,
                kickAnimTimerA: _engine.kickAnimTimerA,
                crowdAnimTime: _crowdAnimTime,
                turfParticles: _turfParticles,
                cameraFlashes: _cameraFlashes,
                goalNetBulge: _goalNetBulge,
              ),
            ),

            // Bouton Sélecteur de Caméra PES
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _cycleCamera,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00FFCC), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FFCC).withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam, color: Color(0xFF00FFCC), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _cameraMode == FootballCameraMode.broadcast
                            ? 'VUE : TÉLÉ PES'
                            : (_cameraMode == FootballCameraMode.action ? 'VUE : ACTION 3D' : 'VUE : TACTIQUE'),
                        style: const TextStyle(
                          color: Color(0xFF00FFCC),
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Radar minimap en bas au centre + HUD Clavier en mode bureau
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRadarMinimap(),
                  if (isWide) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.4)),
                        boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 6)],
                      ),
                      child: const Text(
                        '🎮 CLAVIER / MANETTE :  ZQSD / Flèches = Déplacer  •  X = Passe  •  Espace = Tir  •  Shift = Sprint  •  C = Tacle  •  V = Centre',
                        style: TextStyle(color: Color(0xFF00FFCC), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Carte Athlétique 3D du Joueur Actif
            Positioned(
              bottom: 8,
              left: 8,
              child: _buildActivePlayerHUDCard(),
            ),

            // En mode bureau large, les boutons virtuels restent accessibles en surimpression semi-transparente
            if (isWide) ...[
              Positioned(
                bottom: 8,
                left: 175,
                child: Opacity(
                  opacity: 0.55,
                  child: Transform.scale(scale: 0.82, child: _buildVirtualJoystick()),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Opacity(
                  opacity: 0.65,
                  child: Transform.scale(scale: 0.85, child: _buildActionPad(teamAHasBall: teamAHasBall)),
                ),
              ),
            ],

            // Jauge de tir en charge
            if (_isChargingShot)
              Positioned(
                top: 20,
                left: 60,
                right: 60,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF0055), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('PUISSANCE DU TIR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _shotCharge,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation(
                            _shotCharge > 0.85 ? Colors.redAccent : const Color(0xFF00FFCC),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF070B14),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // 1. Scoreboard HUD façon PES 2017
                  _buildScoreboardHUD(),

                  // 2. Terrain de Football (Pelouse 3D, Supporters vivants & Joueurs)
                  if (isWide)
                    Expanded(child: pitchWidget)
                  else ...[
                    Expanded(flex: 7, child: pitchWidget),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        color: const Color(0xFF0A0F1D),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildVirtualJoystick(),
                            _buildActionPad(teamAHasBall: teamAHasBall),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Goal Celebration Replay avec Rendu 3D Photoréaliste du Buteur
              if (_showGoalBanner)
                _buildCinematicGoalCutscene(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivePlayerHUDCard() {
    final player = _engine.activePlayerA;
    final asset = player.avatarAsset ?? 'assets/images/players/striker_mbappe_3d.jpg';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00FFCC), width: 1.2),
        boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              asset,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Color(0xFF00FFCC), size: 28),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '#${player.number} ${player.name.toUpperCase()}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FFCC).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${player.overallRating}',
                      style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.flash_on, color: Color(0xFFFFD166), size: 10),
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 55,
                    child: LinearProgressIndicator(
                      value: _engine.isSprintingA ? 0.65 : 1.0,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF00FFCC)),
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCinematicGoalCutscene() {
    final scorer = _lastScorer ?? widget.teamA.players.firstWhere((p) => p.role == PlayerRole.fwd);
    final asset = scorer.avatarAsset ?? (scorer.name == 'Vinicius' ? 'assets/images/players/madrid_star_3d.jpg' : 'assets/images/players/striker_mbappe_3d.jpg');

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: Container(
            width: 320,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E2842), Color(0xFF0A0F1D), Color(0xFF050811)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFD166), width: 2),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFFD166).withValues(alpha: 0.4), blurRadius: 28),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge Replay Broadcast HD
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFFF0055), borderRadius: BorderRadius.circular(6)),
                      child: const Row(
                        children: [
                          Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                          SizedBox(width: 4),
                          Text('REPLAY 4K', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    Text(
                      _goalMessage,
                      style: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFFFD166), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        '${scorer.overallRating} OVR',
                        style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Rendu 3D Photoréaliste du Buteur
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          asset,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 220,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.sports_soccer, size: 72, color: Color(0xFF00FFCC)),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Colors.black87],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Text(
                              '⭐ ${scorer.celebration.toUpperCase()}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFFFD166), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Identité du Joueur
                Text(
                  '#${scorer.number} ${scorer.name.toUpperCase()}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
                const SizedBox(height: 2),
                const Text(
                  'BUT DE CLASSE MONDIALE • PES 2026 PRO',
                  style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreboardHUD() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF13192B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),

          // Équipe A
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    widget.teamA.shortName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
                Text(widget.teamA.emblem, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),

          // Score central & Horloge
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00FFCC), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_engine.scoreA}', style: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.w900, fontSize: 16)),
                const Text(' - ', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                Text('${_engine.scoreB}', style: const TextStyle(color: Color(0xFFFF0055), fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF00FFCC).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text('${_engine.matchMinutes}\'', style: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ),

          // Équipe B
          Expanded(
            child: Row(
              children: [
                Text(widget.teamB.emblem, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.teamB.shortName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualJoystick() {
    return GestureDetector(
      onPanDown: (_) => setState(() => _isTouchJoystickActive = true),
      onPanUpdate: (details) {
        final localPos = details.localPosition - const Offset(55, 55);
        final dist = localPos.distance;
        if (dist > 0) {
          final clampedDist = math.min(dist, 40.0);
          final norm = (localPos / dist) * (clampedDist / 40.0);
          setState(() {
            _engine.joystickA = norm;
          });
        }
      },
      onPanEnd: (_) {
        setState(() {
          _isTouchJoystickActive = false;
          _engine.joystickA = Offset.zero;
        });
      },
      onPanCancel: () {
        setState(() {
          _isTouchJoystickActive = false;
          _engine.joystickA = Offset.zero;
        });
      },
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF141C30).withValues(alpha: 0.8),
          border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.4), width: 2),
          boxShadow: [
            BoxShadow(color: const Color(0xFF00FFCC).withValues(alpha: 0.15), blurRadius: 10),
          ],
        ),
        child: Center(
          child: Transform.translate(
            offset: _engine.joystickA * 35.0,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF00FFCC), Color(0xFF008B8B)],
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00FFCC).withValues(alpha: 0.5), blurRadius: 8),
                ],
              ),
              child: const Icon(Icons.navigation, color: Colors.black87, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionPad({required bool teamAHasBall}) {
    return SizedBox(
      width: 180,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bouton Haut : Tir (en attaque) ou Tacle Glissé (en défense)
          Positioned(
            top: 0,
            child: GestureDetector(
              onTapDown: (_) {
                if (teamAHasBall) {
                  setState(() {
                    _isChargingShot = true;
                    _shotCharge = 0.2;
                  });
                } else {
                  _engine.tackleBall();
                }
              },
              onTapUp: (_) {
                if (teamAHasBall) {
                  setState(() => _isChargingShot = false);
                  _engine.shootBall(_shotCharge);
                }
              },
              child: _buildActionButton(
                label: teamAHasBall ? 'TIR' : 'TACLE',
                color: const Color(0xFFFF0055),
                icon: teamAHasBall ? Icons.sports_soccer : Icons.clear,
              ),
            ),
          ),

          // Bouton Bas : Passe Courte (attaque) ou Pressing (défense)
          Positioned(
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                if (teamAHasBall) {
                  _engine.passBall();
                } else {
                  _engine.switchActivePlayer();
                }
              },
              child: _buildActionButton(
                label: teamAHasBall ? 'PASSE' : 'CHANGER',
                color: const Color(0xFF00FFCC),
                icon: teamAHasBall ? Icons.arrow_forward : Icons.swap_horiz,
              ),
            ),
          ),

          // Bouton Droite : Sprint (Accélération)
          Positioned(
            right: 0,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _engine.isSprintingA = true),
              onTapUp: (_) => setState(() => _engine.isSprintingA = false),
              onTapCancel: () => setState(() => _engine.isSprintingA = false),
              child: _buildActionButton(
                label: 'SPRINT',
                color: const Color(0xFF00F0FF),
                icon: Icons.bolt,
              ),
            ),
          ),

          // Bouton Gauche : Passe Longue / Centre
          Positioned(
            left: 0,
            child: GestureDetector(
              onTap: () {
                if (teamAHasBall) {
                  _engine.shootBall(0.55);
                } else {
                  _engine.tackleBall();
                }
              },
              child: _buildActionButton(
                label: teamAHasBall ? 'LOB' : 'PRESS',
                color: const Color(0xFFFFD166),
                icon: Icons.north_east,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarMinimap() {
    return Container(
      width: 140,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: CustomPaint(
        painter: _RadarMinimapPainter(
          teamA: widget.teamA,
          teamB: widget.teamB,
          ballPos: _engine.ballPos,
        ),
      ),
    );
  }
}

class _RadarMinimapPainter extends CustomPainter {
  final FootballTeam teamA;
  final FootballTeam teamB;
  final Offset ballPos;

  _RadarMinimapPainter({
    required this.teamA,
    required this.teamB,
    required this.ballPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Ligne médiane
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height), linePaint);

    // Joueurs Team A (Bleu/Cyan)
    final paintA = Paint()..color = const Color(0xFF00FFCC);
    for (final p in teamA.players) {
      canvas.drawCircle(Offset(p.pos.dx * size.width, p.pos.dy * size.height), 2.2, paintA);
    }

    // Joueurs Team B (Rouge)
    final paintB = Paint()..color = const Color(0xFFFF0055);
    for (final p in teamB.players) {
      canvas.drawCircle(Offset(p.pos.dx * size.width, p.pos.dy * size.height), 2.2, paintB);
    }

    // Ballon (Jaune)
    final paintBall = Paint()..color = const Color(0xFFFFD166);
    canvas.drawCircle(Offset(ballPos.dx * size.width, ballPos.dy * size.height), 2.5, paintBall);
  }

  @override
  bool shouldRepaint(covariant _RadarMinimapPainter oldDelegate) => true;
}

class _FootballPitchPainter extends CustomPainter {
  final FootballTeam teamA;
  final FootballTeam teamB;
  final FootballPlayer activePlayerA;
  final FootballPlayer activePlayerB;
  final Offset ballPos;
  final double ballHeight;
  final FootballCameraMode cameraMode;
  final Offset cameraOffset;
  final Offset? passTargetPos;
  final double passTrajectoryTimer;
  final double kickAnimTimerA;
  final double crowdAnimTime;
  final List<TurfParticle> turfParticles;
  final List<StadiumFlash> cameraFlashes;
  final double goalNetBulge;

  _FootballPitchPainter({
    required this.teamA,
    required this.teamB,
    required this.activePlayerA,
    required this.activePlayerB,
    required this.ballPos,
    required this.ballHeight,
    required this.cameraMode,
    required this.cameraOffset,
    required this.passTargetPos,
    required this.passTrajectoryTimer,
    required this.kickAnimTimerA,
    required this.crowdAnimTime,
    required this.turfParticles,
    required this.cameraFlashes,
    required this.goalNetBulge,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double zoom;
    switch (cameraMode) {
      case FootballCameraMode.broadcast:
        zoom = 1.95; // Caméra téléviseur PES
        break;
      case FootballCameraMode.action:
        zoom = 2.65; // Caméra action rapprochée
        break;
      case FootballCameraMode.tactical:
        zoom = 1.0; // Vue tactique globale
        break;
    }

    canvas.save();

    if (zoom > 1.0) {
      final halfSpanX = 0.5 / zoom;
      final halfSpanY = 0.5 / zoom;
      final clampedX = cameraOffset.dx.clamp(halfSpanX, 1.0 - halfSpanX);
      final clampedY = cameraOffset.dy.clamp(halfSpanY * 0.75, 1.0 - halfSpanY * 0.75);

      canvas.translate(size.width * 0.5, size.height * 0.5);
      canvas.scale(zoom);
      canvas.translate(-clampedX * size.width, -clampedY * size.height);
    }

    // 1. TRIBUNES DES SUPPORTERS VIVANTES EN HAUT DU TERRAIN (Stade en ébullition)
    final crowdHeight = size.height * 0.09;
    // Gradins en béton en perspective
    final standShader = const LinearGradient(
      colors: [Color(0xFF090D18), Color(0xFF161E30), Color(0xFF0B1020)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, size.width, crowdHeight));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, crowdHeight), Paint()..shader = standShader);

    // Supporters animés (rangées de fans aux couleurs des 2 équipes)
    const int fanCols = 32;
    for (int row = 0; row < 3; row++) {
      final yRow = 4.0 + row * 8.0;
      for (int i = 0; i < fanCols; i++) {
        final xFan = (i + 0.5) * (size.width / fanCols);
        final isHomeSide = xFan < size.width * 0.48;
        final isAwaySide = xFan > size.width * 0.52;
        final fanColor = isHomeSide
            ? teamA.primaryColor
            : (isAwaySide ? teamB.primaryColor : const Color(0xFFBDC3C7));

        // Mouvement de liesse / saut des supporters en vague (Ola)
        final jumpOffset = math.sin(crowdAnimTime * 2.2 + i * 0.45 + row) * 2.2;
        final fanY = yRow - jumpOffset.clamp(0.0, 4.0);

        // Tête et buste du supporter
        canvas.drawCircle(Offset(xFan, fanY), 2.2, Paint()..color = const Color(0xFFE0AC69));
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(xFan, fanY + 3.5), width: 4.8, height: 4.2), const Radius.circular(1.5)),
          Paint()..color = fanColor,
        );

        // Écharpes et drapeaux brandis
        if (i % 4 == 0) {
          final flagWave = math.sin(crowdAnimTime * 3.0 + i) * 3.0;
          final scarfPaint = Paint()
            ..color = fanColor
            ..strokeWidth = 1.8;
          canvas.drawLine(Offset(xFan - 2, fanY - 2 + flagWave), Offset(xFan + 3, fanY - 4 - flagWave), scarfPaint);
        }
      }
    }

    // Flashs d'appareils photo dans la foule
    for (final f in cameraFlashes) {
      final flashX = f.x * size.width;
      final flashY = f.y * size.height;
      final flashRadius = 3.0 + f.life * 6.0;
      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: (f.life * 4.0).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(flashX, flashY), flashRadius, glowPaint);
      canvas.drawCircle(Offset(flashX, flashY), 1.5, Paint()..color = Colors.white);
    }

    // 2. PANNEAUX LED PUBLICITAIRES DU STADE (PES Broadcast style avec animations)
    final adBoardRect = Rect.fromLTWH(size.width * 0.03, crowdHeight - 2, size.width * 0.94, size.height * 0.035);
    canvas.drawRect(adBoardRect, Paint()..color = const Color(0xFF070B16));
    final adBorder = Paint()..color = const Color(0xFF00FFCC)..style = PaintingStyle.stroke..strokeWidth = 1.0;
    canvas.drawRect(adBoardRect, adBorder);

    final adScrollOffset = (crowdAnimTime * 15.0) % 200.0;
    final adText = TextPainter(
      text: const TextSpan(
        text: 'PES PRO LEAGUE 2026  ★  KONAMI MASTER CHAMPIONSHIP  ★  OMNI MULTIVERSE ARENA  ★  FAIR PLAY',
        style: TextStyle(color: Color(0xFF00FFCC), fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.clipRect(adBoardRect);
    adText.paint(canvas, Offset(size.width * 0.5 - adText.width / 2 - adScrollOffset + 100, adBoardRect.center.dy - adText.height / 2));
    canvas.restore();

    // 3. TERRAIN DE FOOTBALL VIVANT (Herbe tondue 3D & éclairage)
    final pitchTop = crowdHeight + size.height * 0.025;
    final pitchHeight = size.height - pitchTop - 4;

    // Bandes d'herbe alternées en tondeuse professionnelle
    final stripeCount = 10;
    final stripeWidth = size.width / stripeCount;
    final greenDark = Paint()..color = const Color(0xFF196335);
    final greenLight = Paint()..color = const Color(0xFF227842);

    for (int i = 0; i < stripeCount; i++) {
      final rect = Rect.fromLTWH(i * stripeWidth, pitchTop, stripeWidth, pitchHeight);
      canvas.drawRect(rect, i.isEven ? greenLight : greenDark);
    }

    // 4. RAYONS VOLUMÉTRIQUES DES 4 PROJECTEURS DU STADE
    final lightColor = Colors.white.withValues(alpha: 0.06);
    final beamPaint = Paint()
      ..color = lightColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    // Projecteur Haut Gauche
    final beamL = Path()..moveTo(0, 0)..lineTo(size.width * 0.45, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(beamL, beamPaint);
    // Projecteur Haut Droite
    final beamR = Path()..moveTo(size.width, 0)..lineTo(size.width * 0.55, size.height)..lineTo(size.width, size.height)..close();
    canvas.drawPath(beamR, beamPaint);

    // Lignes tactiques en mode tactique
    if (cameraMode == FootballCameraMode.tactical) {
      final tacPaintA = Paint()..color = const Color(0xFF00FFCC).withValues(alpha: 0.35)..strokeWidth = 1.2;
      for (int i = 0; i < teamA.players.length - 1; i++) {
        canvas.drawLine(
          Offset(teamA.players[i].pos.dx * size.width, teamA.players[i].pos.dy * size.height),
          Offset(teamA.players[i + 1].pos.dx * size.width, teamA.players[i + 1].pos.dy * size.height),
          tacPaintA,
        );
      }
    }

    // 5. MARQUAGES RÉALISTES DU TERRAIN
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Ligne de touche extérieure
    canvas.drawRect(Rect.fromLTWH(size.width * 0.03, pitchTop + 4, size.width * 0.94, pitchHeight - 8), linePaint);

    // Ligne médiane
    final midX = size.width * 0.50;
    canvas.drawLine(Offset(midX, pitchTop + 4), Offset(midX, size.height - 4), linePaint);

    // Rond central & point central
    final pitchCenterY = pitchTop + pitchHeight * 0.50;
    canvas.drawCircle(Offset(midX, pitchCenterY), pitchHeight * 0.22, linePaint);
    canvas.drawCircle(Offset(midX, pitchCenterY), 3.0, Paint()..color = Colors.white70);

    // 6. CAGES DE BUT 3D AVEC FILET HEXAGONAL DYNAMIQUE
    final goalDepth = 14.0 + goalNetBulge * 10.0;
    final goalH = pitchHeight * 0.30;
    final goalY = pitchCenterY - goalH * 0.5;

    // Cage Gauche (Team A)
    final goalPostPaint = Paint()..color = Colors.white..strokeWidth = 3.0..strokeCap = StrokeCap.round;
    final goalNetPaint = Paint()..color = Colors.white.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 1.0;

    // Filet et montants But Gauche
    canvas.drawRect(Rect.fromLTWH(size.width * 0.03 - goalDepth, goalY, goalDepth, goalH), goalNetPaint);
    canvas.drawLine(Offset(size.width * 0.03, goalY), Offset(size.width * 0.03, goalY + goalH), goalPostPaint);

    // Cage Droite (Team B)
    canvas.drawRect(Rect.fromLTWH(size.width * 0.97, goalY, goalDepth, goalH), goalNetPaint);
    canvas.drawLine(Offset(size.width * 0.97, goalY), Offset(size.width * 0.97, goalY + goalH), goalPostPaint);

    // Surfaces de réparation
    canvas.drawRect(Rect.fromLTWH(size.width * 0.03, pitchCenterY - pitchHeight * 0.32, size.width * 0.16, pitchHeight * 0.64), linePaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.81, pitchCenterY - pitchHeight * 0.32, size.width * 0.16, pitchHeight * 0.64), linePaint);

    // Drapeaux de corner animés au vent
    _drawCornerFlag(canvas, Offset(size.width * 0.03, pitchTop + 4), crowdAnimTime);
    _drawCornerFlag(canvas, Offset(size.width * 0.97, pitchTop + 4), crowdAnimTime + 1.2);
    _drawCornerFlag(canvas, Offset(size.width * 0.03, size.height - 4), crowdAnimTime + 2.4);
    _drawCornerFlag(canvas, Offset(size.width * 0.97, size.height - 4), crowdAnimTime + 3.6);

    // 7. PARTICULES D'HERBE ÉJECTÉES (Turf Particles)
    for (final tp in turfParticles) {
      canvas.drawCircle(
        Offset(tp.x * size.width, tp.y * size.height),
        1.8 * tp.life,
        Paint()..color = tp.color.withValues(alpha: tp.life),
      );
    }

    // Trajectoire de passe PES avec flèche et anneau de réception
    if (passTargetPos != null && passTrajectoryTimer > 0) {
      final passAlpha = (passTrajectoryTimer * 0.9).clamp(0.0, 0.9);
      final pStart = Offset(ballPos.dx * size.width, ballPos.dy * size.height);
      final pEnd = Offset(passTargetPos!.dx * size.width, passTargetPos!.dy * size.height);

      final passPaint = Paint()
        ..color = const Color(0xFF00FFCC).withValues(alpha: passAlpha)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(pStart, pEnd, passPaint);

      final targetRingPaint = Paint()
        ..color = const Color(0xFF00FFCC).withValues(alpha: passAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(pEnd, 12.0 * (1.0 + (1.0 - passTrajectoryTimer) * 0.5), targetRingPaint);
      canvas.drawCircle(pEnd, 3.5, Paint()..color = const Color(0xFF00FFCC).withValues(alpha: passAlpha));
    }

    // 8. DESSIN DES JOUEURS VIVANTS & ATHLÉTIQUES TEAM A
    for (final p in teamA.players) {
      _drawLivingPlayer(
        canvas,
        size,
        p,
        teamA.primaryColor,
        teamA.secondaryColor,
        isControlled: p == activePlayerA,
        ballPos: ballPos,
        kickAnimTimer: p == activePlayerA ? kickAnimTimerA : 0.0,
      );
    }

    // 9. DESSIN DES JOUEURS VIVANTS & ATHLÉTIQUES TEAM B
    for (final p in teamB.players) {
      _drawLivingPlayer(
        canvas,
        size,
        p,
        teamB.primaryColor,
        teamB.secondaryColor,
        isControlled: p == activePlayerB,
        ballPos: ballPos,
        kickAnimTimer: 0.0,
      );
    }

    // 10. BALLON TELSTAR 3D AVEC TEXTURE CUIR & OMBRE PORTÉE ÉLEVÉE
    final bX = ballPos.dx * size.width;
    final bY = ballPos.dy * size.height;
    final elevation = ballHeight * 26.0;

    // Ombre sous le ballon
    final shadowScale = 1.0 + (elevation * 0.05);
    final shadowOpacity = (0.48 - elevation * 0.015).clamp(0.10, 0.48);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bX + (elevation * 0.38), bY + 4 + (elevation * 0.3)),
        width: 14 * shadowScale,
        height: 8 * shadowScale,
      ),
      Paint()..color = Colors.black.withValues(alpha: shadowOpacity),
    );

    // Sphère 3D du ballon de football
    final ballCenter = Offset(bX, bY - elevation);
    const ballRadius = 7.5;

    // Dégradé d'éclairage 3D réaliste
    final ballShader = RadialGradient(
      center: const Alignment(-0.35, -0.35),
      radius: 0.9,
      colors: const [Colors.white, Color(0xFFECEFF1), Color(0xFF90A4AE)],
      stops: const [0.0, 0.65, 1.0],
    ).createShader(Rect.fromCircle(center: ballCenter, radius: ballRadius));

    canvas.drawCircle(ballCenter, ballRadius, Paint()..shader = ballShader);
    canvas.drawCircle(ballCenter, ballRadius, Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 0.8);

    // Panneaux pentagonaux Telstar
    final patchPaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(ballCenter, 2.6, patchPaint);
    canvas.drawCircle(Offset(ballCenter.dx - 4.2, ballCenter.dy - 2.0), 1.6, patchPaint);
    canvas.drawCircle(Offset(ballCenter.dx + 4.2, ballCenter.dy + 2.0), 1.6, patchPaint);

    canvas.restore();
  }

  void _drawCornerFlag(Canvas canvas, Offset pos, double time) {
    // Poteau du drapeau
    canvas.drawLine(pos, pos - const Offset(0, 10), Paint()..color = Colors.white..strokeWidth = 1.5);
    // Tissu du drapeau qui ondule dans le vent
    final wave = math.sin(time * 2.5) * 2.0;
    final flagPath = Path()
      ..moveTo(pos.dx, pos.dy - 10)
      ..lineTo(pos.dx + 7, pos.dy - 7 + wave)
      ..lineTo(pos.dx, pos.dy - 4)
      ..close();
    canvas.drawPath(flagPath, Paint()..color = const Color(0xFFFFD166));
  }

  void _drawLivingPlayer(
    Canvas canvas,
    Size size,
    FootballPlayer p,
    Color primaryColor,
    Color secondaryColor, {
    required bool isControlled,
    required Offset ballPos,
    required double kickAnimTimer,
  }) {
    final px = p.pos.dx * size.width;
    final py = p.pos.dy * size.height;

    // 1. Ombre portée dynamique sous les projecteurs
    canvas.drawOval(
      Rect.fromCenter(center: Offset(px + 3, py + 8), width: 24, height: 11),
      Paint()..color = Colors.black.withValues(alpha: 0.42),
    );

    // Trace de glissade sur l'herbe en cas de tacle glissé
    if (p.isSliding) {
      final skidPaint = Paint()
        ..color = const Color(0xFF0F3D1C)
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(px - 16, py + 4), Offset(px + 6, py + 4), skidPaint);
    }

    // 2. Rendu de l'athlète avec orientation corporelle et tête tournée vers le ballon
    canvas.save();
    canvas.translate(px, py);
    canvas.rotate(p.facingAngle);

    final bool isGk = p.role == PlayerRole.gk;
    final Color jerseyColor = isGk ? const Color(0xFFFF9F1C) : primaryColor;
    final Color shortsColor = isGk ? const Color(0xFF1E2842) : (primaryColor == Colors.white ? const Color(0xFF1E2842) : Colors.white);
    final Color socksColor = isGk ? const Color(0xFFFF9F1C) : secondaryColor;

    // Cycle d'animation athlétique de course
    final double legCycle = math.sin(p.animTime) * 5.2;

    // --- JAMBES ATHLÉTIQUES & CHAUSSURES DE FOOTBALL ---
    if (p.isSliding) {
      // Pose de tacle glissé pro : jambe avant tendue pour crocheter le ballon
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -5, 8, 4.5), const Radius.circular(2)), Paint()..color = socksColor);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 2, 16, 4.5), const Radius.circular(2)), Paint()..color = socksColor);
      canvas.drawOval(const Rect.fromLTWH(13, 1, 6.5, 4.8), Paint()..color = const Color(0xFF111111));
    } else if (kickAnimTimer > 0) {
      // Pose athlétique de tir / frappe de balle PES
      final kickPhase = (kickAnimTimer / 0.40).clamp(0.0, 1.0);
      final kickReach = 4.0 + (1.0 - kickPhase) * 14.0;
      // Jambe d'appui
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -7, 7, 4.2), const Radius.circular(2)),
        Paint()..color = socksColor,
      );
      canvas.drawOval(const Rect.fromLTWH(1, -7.2, 5.5, 4.5), Paint()..color = const Color(0xFF111111));
      // Jambe de frappe détendue vers l'avant !
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(kickReach - 4, 3, 10, 4.5), const Radius.circular(2)),
        Paint()..color = socksColor,
      );
      canvas.drawOval(Rect.fromLTWH(kickReach + 5, 2.8, 6.5, 5.0), Paint()..color = const Color(0xFFFF0055));
    } else {
      // Jambe Gauche
      final leftY = -5.0;
      final leftX = -4.0 + legCycle;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(leftX - 3, leftY - 2, 7.5, 4.2), const Radius.circular(2)),
        Paint()..color = socksColor,
      );
      canvas.drawOval(Rect.fromLTWH(leftX + 2.5, leftY - 2.2, 5.8, 4.5), Paint()..color = const Color(0xFF111111));

      // Jambe Droite
      final rightY = 5.0;
      final rightX = -4.0 - legCycle;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(rightX - 3, rightY - 2, 7.5, 4.2), const Radius.circular(2)),
        Paint()..color = socksColor,
      );
      canvas.drawOval(Rect.fromLTWH(rightX + 2.5, rightY - 2.2, 5.8, 4.5), Paint()..color = const Color(0xFF111111));
    }

    // --- SHORT DE MATCH ATHLÉTIQUE ---
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-6.5, -6.5, 8.0, 13.0), const Radius.circular(3)),
      Paint()..color = shortsColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-6.5, -6.5, 8.0, 13.0), const Radius.circular(3)),
      Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 0.8,
    );

    // --- BUSTE & MAILLOT OFFICIEL (Ombrage 3D & reflets musculaires) ---
    final jerseyPath = Path()
      ..moveTo(5.5, -8.5) // Épaule gauche
      ..lineTo(5.5, 8.5) // Épaule droite
      ..lineTo(-3.0, 6.5) // Hanche droite
      ..lineTo(-3.0, -6.5) // Hanche gauche
      ..close();

    // Dégradé 3D simulant l'éclairage des projecteurs sur la musculature
    final jerseyShader = LinearGradient(
      colors: [jerseyColor.withValues(alpha: 0.9), jerseyColor, Colors.black.withValues(alpha: 0.35)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(const Rect.fromLTWH(-3, -8.5, 8.5, 17));

    canvas.drawPath(jerseyPath, Paint()..shader = jerseyShader);
    canvas.drawPath(jerseyPath, Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 0.9);

    // Brassard de capitaine doré sur joueur #10 ou #7
    if (p.number == 10 || p.number == 7) {
      canvas.drawRect(const Rect.fromLTWH(1.5, -9.0, 2.5, 4.0), Paint()..color = const Color(0xFFFFD166));
    }

    // Col / Échancrure du maillot en couleur secondaire
    final collarPath = Path()
      ..moveTo(4.5, -3.5)
      ..lineTo(2.0, 0.0)
      ..lineTo(4.5, 3.5)
      ..close();
    canvas.drawPath(collarPath, Paint()..color = secondaryColor);

    // Numéro officiel de maillot sur le dos
    final numSpan = TextSpan(
      text: '${p.number}',
      style: TextStyle(
        color: jerseyColor == Colors.white ? Colors.black87 : Colors.white,
        fontSize: 5.5,
        fontWeight: FontWeight.w900,
      ),
    );
    final numPainter = TextPainter(text: numSpan, textDirection: TextDirection.ltr)..layout();
    numPainter.paint(canvas, Offset(-1.5 - numPainter.width / 2, -numPainter.height / 2));

    // --- BRAS ATHLÉTIQUES & GANTS DE GARDIEN ---
    final armSwing = math.sin(p.animTime) * 3.8;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(2.2 - armSwing, -9.5), width: 6.8, height: 3.8),
      Paint()..color = p.skinTone,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(2.2 + armSwing, 9.5), width: 6.8, height: 3.8),
      Paint()..color = p.skinTone,
    );

    // Gants de gardien rembourrés pour les goals
    if (isGk) {
      canvas.drawCircle(Offset(4.8 - armSwing, -9.5), 3.2, Paint()..color = const Color(0xFFFF5722));
      canvas.drawCircle(Offset(4.8 + armSwing, 9.5), 3.2, Paint()..color = const Color(0xFFFF5722));
    }

    // --- TÊTE AVEC ORIENTATION VISUELLE VERS LE BALLON ---
    final double headRelX = ballPos.dx * size.width - px;
    final double headRelY = ballPos.dy * size.height - py;
    final double headAngle = (math.atan2(headRelY, headRelX) - p.facingAngle).clamp(-0.4, 0.4);

    canvas.save();
    canvas.rotate(headAngle);

    // Cou & Tête sculptée avec traits de visage réalistes
    canvas.drawCircle(const Offset(3.2, 0.0), 3.4, Paint()..color = p.skinTone);
    canvas.drawOval(
      const Rect.fromLTWH(1.5, -4.2, 7.8, 8.4),
      Paint()..color = p.skinTone,
    );
    // Cheveux sculptés
    final hairPaint = Paint()..color = p.hairColor;
    canvas.drawArc(
      const Rect.fromLTWH(0.8, -4.4, 6.2, 8.8),
      math.pi / 2,
      math.pi,
      true,
      hairPaint,
    );

    // Yeux réalistes avec sclère blanche et pupille
    final eyeWhite = Paint()..color = Colors.white;
    final eyePupil = Paint()..color = const Color(0xFF1E1108);
    // Œil gauche
    canvas.drawOval(const Rect.fromLTWH(6.4, -2.8, 1.8, 1.3), eyeWhite);
    canvas.drawCircle(const Offset(7.5, -2.1), 0.55, eyePupil);
    // Œil droit
    canvas.drawOval(const Rect.fromLTWH(6.4, 1.5, 1.8, 1.3), eyeWhite);
    canvas.drawCircle(const Offset(7.5, 2.1), 0.55, eyePupil);

    // Arête du nez
    canvas.drawLine(const Offset(6.8, 0.0), const Offset(8.4, 0.0), Paint()..color = p.skinTone.withValues(alpha: 0.85)..strokeWidth = 1.0);
    // Bouche déterminée
    canvas.drawLine(const Offset(6.2, -1.0), const Offset(6.2, 1.0), Paint()..color = const Color(0xFF6B3A1E)..strokeWidth = 0.8);
    // Oreilles gauche et droite
    canvas.drawOval(const Rect.fromLTWH(3.2, -4.8, 1.8, 1.4), Paint()..color = p.skinTone);
    canvas.drawOval(const Rect.fromLTWH(3.2, 3.4, 1.8, 1.4), Paint()..color = p.skinTone);
    canvas.restore();

    canvas.restore();

    // 3. Étiquette PES TV broadcast au-dessus du joueur
    final textSpan = TextSpan(
      text: '${p.number} ${p.name.toUpperCase()}',
      style: TextStyle(
        color: isControlled ? const Color(0xFF00FFCC) : Colors.white,
        fontSize: 7.5,
        fontWeight: isControlled ? FontWeight.w900 : FontWeight.bold,
        shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
      ),
    );
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();

    final badgeRect = Rect.fromCenter(
      center: Offset(px, py + 14),
      width: textPainter.width + 8,
      height: 12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)),
      Paint()..color = Colors.black.withValues(alpha: 0.70),
    );
    textPainter.paint(canvas, Offset(px - textPainter.width / 2, py + 14 - textPainter.height / 2));

    // 4. Curseur tactique PES au-dessus de la tête du joueur contrôlé
    if (isControlled) {
      final markerPath = Path()
        ..moveTo(px, py - 18)
        ..lineTo(px - 5, py - 25)
        ..lineTo(px + 5, py - 25)
        ..close();
      canvas.drawPath(markerPath, Paint()..color = const Color(0xFF00FFCC));
      canvas.drawPath(markerPath, Paint()..color = Colors.black54..style = PaintingStyle.stroke..strokeWidth = 1.0);
    }
  }

  @override
  bool shouldRepaint(covariant _FootballPitchPainter oldDelegate) => true;
}
