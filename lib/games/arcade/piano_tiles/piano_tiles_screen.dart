import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';

class PianoTile {
  final int lane; // 0, 1, 2, 3
  double y; // 0..1
  bool isTapped = false;

  PianoTile({required this.lane, required this.y});
}

class PianoTilesScreen extends StatefulWidget {
  const PianoTilesScreen({super.key});

  @override
  State<PianoTilesScreen> createState() => _PianoTilesScreenState();
}

class _PianoTilesScreenState extends State<PianoTilesScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final List<PianoTile> _tiles = [];
  double _speed = 0.55;
  int _score = 0;
  int _highScore = 0;
  bool _isPlaying = false;
  bool _isGameOver = false;
  double _lastTs = 0;
  final math.Random _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _highScore = StorageService.getHighScore('piano_tiles');
    _ticker = AnimationController.unbounded(vsync: this)..addListener(_onTick);
    _ticker.repeat(period: const Duration(days: 1));
  }

  void _startGame() {
    setState(() {
      _tiles.clear();
      _score = 0;
      _speed = 0.55;
      _isGameOver = false;
      _isPlaying = true;
      // Première tuile
      _tiles.add(PianoTile(lane: _rnd.nextInt(4), y: 0.1));
    });
    FeedbackService.triggerLight();
  }

  void _onTick() {
    if (!_isPlaying || _isGameOver) return;

    final currentMs = _ticker.lastElapsedDuration?.inMicroseconds ?? 0;
    if (_lastTs == 0) {
      _lastTs = currentMs.toDouble();
      return;
    }
    double dt = (currentMs - _lastTs) / 1000000.0;
    _lastTs = currentMs.toDouble();
    if (dt > 0.1) dt = 0.033;

    setState(() {
      // Déplacement des tuiles vers le bas
      for (final t in _tiles) {
        t.y += _speed * dt;
        // Si une tuile non touchée sort par le bas : Défaite !
        if (t.y > 1.05 && !t.isTapped) {
          _triggerGameOver();
          return;
        }
      }

      // Supprimer les tuiles hors écran touchées
      _tiles.removeWhere((t) => t.y > 1.1 && t.isTapped);

      // Générer une nouvelle tuile périodiquement
      if (_tiles.isEmpty || _tiles.last.y > 0.32) {
        _tiles.add(PianoTile(lane: _rnd.nextInt(4), y: -0.1));
      }
    });
  }

  void _onLaneTap(int lane) {
    if (!_isPlaying) {
      _startGame();
      return;
    }
    if (_isGameOver) return;

    // Chercher la tuile la plus basse dans cette voie
    PianoTile? target;
    for (final t in _tiles) {
      if (t.lane == lane && !t.isTapped && t.y > 0.45 && t.y < 1.05) {
        if (target == null || t.y > target.y) {
          target = t;
        }
      }
    }

    if (target != null) {
      // Coup réussi !
      FeedbackService.triggerImpact();
      setState(() {
        target!.isTapped = true;
        _score++;
        _speed = math.min(1.2, 0.55 + (_score * 0.015));
        StorageService.saveHighScore('piano_tiles', _score);
        _highScore = math.max(_highScore, _score);
      });
    } else {
      // Tap dans le vide : faute !
      _triggerGameOver();
    }
  }

  void _triggerGameOver() {
    setState(() {
      _isGameOver = true;
      _isPlaying = false;
    });
    FeedbackService.triggerImpact();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10172D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'PIANO TILES NÉON ($_score PTS)',
          style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // 4 Couloirs musicaux
          Row(
            children: List.generate(4, (laneIdx) {
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _onLaneTap(laneIdx),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          // Ligne de frappe en bas
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Container(
              height: 4,
              color: const Color(0xFF00FFCC).withValues(alpha: 0.7),
            ),
          ),

          // Rendu des tuiles
          ..._tiles.map((t) {
            final screenH = MediaQuery.of(context).size.height - 100;
            final tileHeight = screenH * 0.22;
            final topPos = t.y * screenH;

            return Positioned(
              left: (MediaQuery.of(context).size.width / 4) * t.lane + 4,
              width: (MediaQuery.of(context).size.width / 4) - 8,
              top: topPos,
              height: tileHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: t.isTapped ? Colors.white24 : const Color(0xFF00F0FF),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !t.isTapped
                      ? [BoxShadow(color: const Color(0xFF00F0FF).withValues(alpha: 0.5), blurRadius: 10)]
                      : [],
                ),
                child: Center(
                  child: Icon(Icons.music_note, color: t.isTapped ? Colors.white30 : Colors.black87),
                ),
              ),
            );
          }),

          // Écran d'accueil / Défaite
          if (!_isPlaying && !_isGameOver)
            Center(
              child: ElevatedButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow, color: Colors.black),
                label: const Text('DÉMARRER LE RYTHME', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFCC), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
            ),

          if (_isGameOver)
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D36),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('NOTE MANQUÉE !', style: TextStyle(color: Colors.redAccent, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text('Score : $_score | Record : $_highScore', style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _startGame,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFCC)),
                      child: const Text('REJOUER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
