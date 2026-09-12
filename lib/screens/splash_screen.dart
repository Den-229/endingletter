import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'main_menu.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigateTimer;

  @override
  void initState() {
    super.initState();
    _navigateTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainMenu(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _navigateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.abc_rounded,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ).animate().fade(duration: 800.ms).scale(delay: 200.ms),
            const SizedBox(height: 20),
            Text(
              'ENDING LETTER',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ).animate().fade(delay: 400.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 10),
            Text(
              'Le Jeu de Mots',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ).animate().fade(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}
