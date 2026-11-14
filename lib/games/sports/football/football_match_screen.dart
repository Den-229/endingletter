import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'football_models.dart';
import 'football_engine.dart';
import '../../../widgets/confetti_overlay.dart';
import '../../../services/storage_service.dart';

enum FootballCameraMode {
  broadcast, // Vue Télévision Diffusion PES (Perspective classique)
  action,    // Vue Rapprochée Action (Zoom dynamique centré sur le ballon)
  tactical,  // Vue Tactique Aérienne d'Ensemble
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

    if (_isChargingShot) {
      _shotCharge = (_shotCharge + dt * 1.5).clamp(0.0, 1.0);
    }

    setState(() {
      _engine.update(dt);
    });
  }

  void _handleGoal() {
    setState(() {
      _showGoalBanner = true;
      _goalMessage = 'GOOOOOOAL !';
    });

    FeedbackService.triggerSuccess();

    Future.delayed(const Duration(milliseconds: 2200), () {
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
            child: const Text('REJOUER', style: TextStyle(fontWeight: FontWeight.bold)),
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
          SizedBox(width: 50, child: Text(valA, style: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold))),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          SizedBox(width: 50, child: Text(valB, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFFFF0055), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool teamAHasBall = _engine.ballCarrier != null && widget.teamA.players.contains(_engine.ballCarrier);

    return Scaffold(
      backgroundColor: const Color(0xFF060B12),
      body: ConfettiOverlay(
        showCelebration: _showGoalBanner,
        title: 'GOOOOOAL ! ⚽',
        subtitle: 'But exceptionnel marqué !',
        child: SafeArea(
          child: Stack(
          children: [
            Column(
              children: [
                // 1. Scoreboard HUD façon PES 2017
                _buildScoreboardHUD(),

                // 2. Terrain de Football (Pelouse et Joueurs)
                Expanded(
                  flex: 6,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E6F3D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 18),
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
                            ),
                          ),

                          // Bouton Sélecteur de Caméra PES
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
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
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
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

                          // Radar minimap en haut au centre
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _buildRadarMinimap(),
                            ),
                          ),

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
                  ),
                ),

                // 3. Panneau de Contrôle Inférieur (Joystick Virtuel & Boutons PES)
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFF0A0F1D),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Joystick Directionnel Gauche
                        _buildVirtualJoystick(),

                        // Boutons d'Action Droite (Attaque ou Défense)
                        _buildActionPad(teamAHasBall: teamAHasBall),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Goal Celebration Overlay
            if (_showGoalBanner)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sports_soccer, color: Color(0xFF00FFCC), size: 64),
                        const SizedBox(height: 12),
                        Text(
                          _goalMessage,
                          style: const TextStyle(
                            color: Color(0xFF00FFCC),
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            shadows: [Shadow(color: Color(0xFF00FFCC), blurRadius: 20)],
                          ),
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

  _FootballPitchPainter({
    required this.teamA,
    required this.teamB,
    required this.activePlayerA,
    required this.activePlayerB,
    required this.ballPos,
    required this.ballHeight,
    required this.cameraMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    if (cameraMode == FootballCameraMode.action) {
      // Zoom caméra dynamique action centrée sur la zone de jeu du ballon
      final targetX = ballPos.dx * size.width;
      final targetY = ballPos.dy * size.height;
      canvas.translate(size.width * 0.5, size.height * 0.5);
      canvas.scale(1.30);
      canvas.translate(-targetX, -targetY);
    }

    // 1. Bandes d'herbe tondue (alternance de tons verts)
    final stripeCount = 10;
    final stripeWidth = size.width / stripeCount;
    final greenDark = Paint()..color = const Color(0xFF1B6A3A);
    final greenLight = Paint()..color = const Color(0xFF227D45);

    for (int i = 0; i < stripeCount; i++) {
      final rect = Rect.fromLTWH(i * stripeWidth, 0, stripeWidth, size.height);
      canvas.drawRect(rect, i.isEven ? greenLight : greenDark);
    }

    // Panneaux LED publicitaires du stade (PES Broadcast style)
    if (cameraMode == FootballCameraMode.broadcast) {
      final adBoardRect = Rect.fromLTWH(size.width * 0.03, 0, size.width * 0.94, size.height * 0.04);
      canvas.drawRect(adBoardRect, Paint()..color = const Color(0xFF0D1525));
      final adBorder = Paint()..color = const Color(0xFF00FFCC)..style = PaintingStyle.stroke..strokeWidth = 1.0;
      canvas.drawRect(adBoardRect, adBorder);

      final adText = TextPainter(
        text: const TextSpan(
          text: 'PES PRO LEAGUE 2026  ★  KONAMI MASTER CHAMPIONSHIP  ★  OMNI MULTIVERSE ARENA',
          style: TextStyle(color: Color(0xFF00FFCC), fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      adText.paint(canvas, Offset(size.width * 0.5 - adText.width / 2, size.height * 0.02 - adText.height / 2));
    }

    // Lignes tactiques en mode tactique
    if (cameraMode == FootballCameraMode.tactical) {
      final tacPaintA = Paint()..color = const Color(0xFF00FFCC).withValues(alpha: 0.25)..strokeWidth = 1.0;
      for (int i = 0; i < teamA.players.length - 1; i++) {
        canvas.drawLine(
          Offset(teamA.players[i].pos.dx * size.width, teamA.players[i].pos.dy * size.height),
          Offset(teamA.players[i + 1].pos.dx * size.width, teamA.players[i + 1].pos.dy * size.height),
          tacPaintA,
        );
      }
    }

    // 2. Marquages du terrain en blanc
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Ligne de touche extérieure
    canvas.drawRect(Rect.fromLTWH(size.width * 0.03, size.height * 0.05, size.width * 0.94, size.height * 0.90), linePaint);

    // Ligne médiane
    canvas.drawLine(Offset(size.width * 0.50, size.height * 0.05), Offset(size.width * 0.50, size.height * 0.95), linePaint);

    // Rond central & point central
    canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.50), size.height * 0.18, linePaint);
    canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.50), 3.0, Paint()..color = Colors.white70);

    // Surface de réparation Gauche (But A)
    canvas.drawRect(Rect.fromLTWH(size.width * 0.03, size.height * 0.28, size.width * 0.16, size.height * 0.44), linePaint);
    // Cage de but A
    canvas.drawRect(Rect.fromLTWH(size.width * 0.005, size.height * 0.40, size.width * 0.025, size.height * 0.20), Paint()..color = Colors.white30);

    // Surface de réparation Droite (But B)
    canvas.drawRect(Rect.fromLTWH(size.width * 0.81, size.height * 0.28, size.width * 0.16, size.height * 0.44), linePaint);
    // Cage de but B
    canvas.drawRect(Rect.fromLTWH(size.width * 0.97, size.height * 0.40, size.width * 0.025, size.height * 0.20), Paint()..color = Colors.white30);

    // 3. Dessin des Joueurs Team A
    for (final p in teamA.players) {
      _drawPlayer(canvas, size, p, teamA.primaryColor, teamA.secondaryColor, isControlled: p == activePlayerA);
    }

    // 4. Dessin des Joueurs Team B
    for (final p in teamB.players) {
      _drawPlayer(canvas, size, p, teamB.primaryColor, teamB.secondaryColor, isControlled: p == activePlayerB);
    }

    // 5. Dessin du Ballon avec texture 3D et ombre portée réaliste
    final bX = ballPos.dx * size.width;
    final bY = ballPos.dy * size.height;
    final elevation = ballHeight * 24.0;

    // Ombre portée sous le ballon (s'éloigne et s'estompe avec l'élévation)
    final shadowScale = 1.0 + (elevation * 0.05);
    final shadowOpacity = (0.45 - elevation * 0.015).clamp(0.10, 0.45);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bX + (elevation * 0.4), bY + 4 + (elevation * 0.3)),
        width: 14 * shadowScale,
        height: 8 * shadowScale,
      ),
      Paint()..color = Colors.black.withValues(alpha: shadowOpacity),
    );

    // Sphère 3D du ballon de football
    final ballCenter = Offset(bX, bY - elevation);
    final ballRadius = 7.5;

    // Fond sphère en dégradé radial (éclairage stadium 3D)
    final ballShader = RadialGradient(
      center: const Alignment(-0.4, -0.4),
      radius: 0.9,
      colors: const [Colors.white, Color(0xFFE0E0E0), Color(0xFF9E9E9E)],
      stops: const [0.0, 0.65, 1.0],
    ).createShader(Rect.fromCircle(center: ballCenter, radius: ballRadius));

    canvas.drawCircle(ballCenter, ballRadius, Paint()..shader = ballShader);
    canvas.drawCircle(ballCenter, ballRadius, Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 0.8);

    // Panneaux géométriques en cuir (Pentagones noirs Telstar)
    final patchPaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(ballCenter, 2.6, patchPaint);
    canvas.drawCircle(Offset(ballCenter.dx - 4.2, ballCenter.dy - 2.0), 1.6, patchPaint);
    canvas.drawCircle(Offset(ballCenter.dx + 4.2, ballCenter.dy + 2.0), 1.6, patchPaint);

    canvas.restore();
  }

  void _drawPlayer(
    Canvas canvas,
    Size size,
    FootballPlayer p,
    Color primaryColor,
    Color secondaryColor, {
    required bool isControlled,
  }) {
    final px = p.pos.dx * size.width;
    final py = p.pos.dy * size.height;

    // 1. Ombre portée dynamique sous les projecteurs du stade
    canvas.drawOval(
      Rect.fromCenter(center: Offset(px + 3, py + 8), width: 22, height: 10),
      Paint()..color = Colors.black.withValues(alpha: 0.38),
    );

    // Trace de glissade sur la pelouse en cas de tacle glissé
    if (p.isSliding) {
      final skidPaint = Paint()
        ..color = const Color(0xFF0F3D1C)
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(px - 14, py + 4), Offset(px + 4, py + 4), skidPaint);
    }

    // 2. Rendu de l'athlète avec orientation corporelle réaliste
    canvas.save();
    canvas.translate(px, py);
    canvas.rotate(p.facingAngle);

    final bool isGk = p.role == PlayerRole.gk;
    final Color jerseyColor = isGk ? const Color(0xFFFFD166) : primaryColor;
    final Color shortsColor = isGk ? const Color(0xFF1E2842) : (primaryColor == Colors.white ? const Color(0xFF1E2842) : Colors.white);
    final Color socksColor = isGk ? const Color(0xFFFFD166) : secondaryColor;

    // Cycle d'animation des jambes
    final double legCycle = math.sin(p.animTime) * 5.0;

    // --- JAMBES & CHAUSSURES DE FOOTBALL (CLEATS) ---
    if (p.isSliding) {
      // Pose de tacle glissé : jambe avant tendue, jambe arrière repliée
      // Jambe arrière repliée
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -5, 8, 4), const Radius.circular(2)), Paint()..color = socksColor);
      // Jambe avant tendue
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 2, 14, 4), const Radius.circular(2)), Paint()..color = socksColor);
      // Crampon avant
      canvas.drawOval(const Rect.fromLTWH(11, 1, 6, 4.5), Paint()..color = const Color(0xFF111111));
    } else {
      // Jambe Gauche : Cuisse + Chaussette haute + Crampon
      final leftY = -5.0;
      final leftX = -4.0 + legCycle;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(leftX - 3, leftY - 2, 7, 4), const Radius.circular(2)),
        Paint()..color = socksColor,
      );
      // Crampon gauche (noir avec semelle)
      canvas.drawOval(Rect.fromLTWH(leftX + 2, leftY - 2.2, 5.5, 4.2), Paint()..color = const Color(0xFF111111));

      // Jambe Droite : Cuisse + Chaussette haute + Crampon
      final rightY = 5.0;
      final rightX = -4.0 - legCycle;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(rightX - 3, rightY - 2, 7, 4), const Radius.circular(2)),
        Paint()..color = socksColor,
      );
      // Crampon droit
      canvas.drawOval(Rect.fromLTWH(rightX + 2, rightY - 2.2, 5.5, 4.2), Paint()..color = const Color(0xFF111111));
    }

    // --- SHORT DE MATCH ATHLÉTIQUE ---
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-6.5, -6.0, 7.5, 12.0), const Radius.circular(3)),
      Paint()..color = shortsColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-6.5, -6.0, 7.5, 12.0), const Radius.circular(3)),
      Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 0.8,
    );

    // --- BUSTE & MAILLOT OFFICIEL (Coupe athlétique en V) ---
    final jerseyPath = Path()
      ..moveTo(5.0, -8.0) // Épaule gauche
      ..lineTo(5.0, 8.0) // Épaule droite
      ..lineTo(-3.0, 6.0) // Hanche droite
      ..lineTo(-3.0, -6.0) // Hanche gauche
      ..close();

    canvas.drawPath(jerseyPath, Paint()..color = jerseyColor);
    canvas.drawPath(jerseyPath, Paint()..color = Colors.black38..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // Col / Échancrure du maillot en couleur secondaire
    final collarPath = Path()
      ..moveTo(4.0, -3.5)
      ..lineTo(1.5, 0.0)
      ..lineTo(4.0, 3.5)
      ..close();
    canvas.drawPath(collarPath, Paint()..color = secondaryColor);

    // Numéro de maillot sur le dos (Typographie officielle)
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
    final armSwing = math.sin(p.animTime) * 3.5;
    // Bras Gauche
    canvas.drawOval(
      Rect.fromCenter(center: Offset(2.0 - armSwing, -9.0), width: 6.5, height: 3.5),
      Paint()..color = p.skinTone,
    );
    // Bras Droit
    canvas.drawOval(
      Rect.fromCenter(center: Offset(2.0 + armSwing, 9.0), width: 6.5, height: 3.5),
      Paint()..color = p.skinTone,
    );

    // Gants de gardien rembourrés pour les goals
    if (isGk) {
      canvas.drawCircle(Offset(4.5 - armSwing, -9.0), 3.0, Paint()..color = const Color(0xFFFF5722));
      canvas.drawCircle(Offset(4.5 + armSwing, 9.0), 3.0, Paint()..color = const Color(0xFFFF5722));
    }

    // --- TÊTE & COUPE DE CHEVEUX SCULPTÉE ---
    // Cou
    canvas.drawCircle(const Offset(3.0, 0.0), 3.2, Paint()..color = p.skinTone);
    // Tête anatomique
    canvas.drawOval(
      const Rect.fromLTWH(1.5, -4.0, 7.5, 8.0),
      Paint()..color = p.skinTone,
    );
    // Cheveux sculptés
    final hairPaint = Paint()..color = p.hairColor;
    canvas.drawArc(
      const Rect.fromLTWH(0.8, -4.2, 6.0, 8.4),
      math.pi / 2,
      math.pi,
      true,
      hairPaint,
    );

    canvas.restore();

    // 3. Étiquette broadcast avec Nom du joueur & Numéro façon PES TV
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

    // Fond étiquette noir translucide
    final badgeRect = Rect.fromCenter(
      center: Offset(px, py + 14),
      width: textPainter.width + 8,
      height: 12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)),
      Paint()..color = Colors.black.withValues(alpha: 0.65),
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
