import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  double vRotation;
  double size;
  Color color;
  double opacity = 1.0;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.vRotation,
    required this.size,
    required this.color,
  });

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 380 * dt; // Gravité
    vx *= 0.98; // Frottement air
    rotation += vRotation * dt;
    opacity = (opacity - 0.25 * dt).clamp(0.0, 1.0);
  }
}

class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool showCelebration;
  final String title;
  final String subtitle;
  final VoidCallback? onDismiss;

  const ConfettiOverlay({
    super.key,
    required this.child,
    required this.showCelebration,
    this.title = 'VICTOIRE ÉCLATANTE ! 🏆',
    this.subtitle = '+100 XP enregistrés dans votre profil',
    this.onDismiss,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final math.Random _rnd = math.Random();
  double _lastTime = 0;

  static const List<Color> _confettiColors = [
    Color(0xFFFF2A6D),
    Color(0xFF00FFCC),
    Color(0xFFFFD166),
    Color(0xFF00F0FF),
    Color(0xFFE056FD),
    Color(0xFF05FFA1),
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this)..addListener(_onTick);
    if (widget.showCelebration) {
      _triggerBurst();
    }
  }

  @override
  void didUpdateWidget(covariant ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showCelebration && !oldWidget.showCelebration) {
      _triggerBurst();
    }
  }

  void _triggerBurst() {
    _particles.clear();
    _lastTime = 0;
    for (int i = 0; i < 90; i++) {
      final angle = -math.pi / 2 + (_rnd.nextDouble() - 0.5) * 1.6;
      final speed = 250.0 + _rnd.nextDouble() * 450.0;
      _particles.add(ConfettiParticle(
        x: 0.5,
        y: 0.45,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        rotation: _rnd.nextDouble() * math.pi * 2,
        vRotation: (_rnd.nextDouble() - 0.5) * 10,
        size: 7 + _rnd.nextDouble() * 8,
        color: _confettiColors[_rnd.nextInt(_confettiColors.length)],
      ));
    }
    _controller.repeat(period: const Duration(days: 1));
  }

  void _onTick() {
    final currentMs = _controller.lastElapsedDuration?.inMicroseconds ?? 0;
    if (_lastTime == 0) {
      _lastTime = currentMs.toDouble();
      return;
    }
    double dt = (currentMs - _lastTime) / 1000000.0;
    _lastTime = currentMs.toDouble();
    if (dt > 0.1) dt = 0.033;

    if (_particles.isEmpty) {
      _controller.stop();
      return;
    }

    setState(() {
      for (final p in _particles) {
        p.update(dt);
      }
      _particles.removeWhere((p) => p.opacity <= 0.05 || p.y > 1.2);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_particles.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ConfettiPainter(particles: _particles),
              ),
            ),
          ),
        if (widget.showCelebration)
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E2952), Color(0xFF0F152E)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD166), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD166).withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFD166), Color(0xFFFF9F1C)],
                        ),
                      ),
                      child: const Icon(Icons.emoji_events, color: Colors.black, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Color(0xFFFFD166),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onDismiss != null)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: widget.onDismiss,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      final px = p.x * size.width;
      final py = p.y * size.height;
      canvas.translate(px, py);
      canvas.rotate(p.rotation);

      // Rubans rectangulaires animés
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size * 1.5, height: p.size * 0.7),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

