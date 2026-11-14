import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/storage_service.dart';

enum Direction { up, down, left, right }

class SnakeScreen extends StatefulWidget {
  const SnakeScreen({super.key});

  @override
  State<SnakeScreen> createState() => _SnakeScreenState();
}

class _SnakeScreenState extends State<SnakeScreen> {
  static const int gridSize = 20;
  final List<math.Point<int>> _snake = [
    const math.Point(10, 10),
    const math.Point(10, 11),
    const math.Point(10, 12),
  ];
  math.Point<int> _food = const math.Point(5, 5);
  Direction _direction = Direction.up;
  Direction _nextDirection = Direction.up;
  Timer? _gameTimer;
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  int _highScore = 0;
  final math.Random _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _highScore = StorageService.getSnakeHighScore();
    _spawnFood();
  }

  void _startGame() {
    setState(() {
      _snake.clear();
      _snake.addAll([
        const math.Point(10, 10),
        const math.Point(10, 11),
        const math.Point(10, 12),
      ]);
      _direction = Direction.up;
      _nextDirection = Direction.up;
      _score = 0;
      _isGameOver = false;
      _isPlaying = true;
      _spawnFood();
    });

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 140), (t) => _tick());
  }

  void _spawnFood() {
    math.Point<int> newFood;
    do {
      newFood = math.Point(_rnd.nextInt(gridSize), _rnd.nextInt(gridSize));
    } while (_snake.contains(newFood));
    _food = newFood;
  }

  void _tick() {
    if (!_isPlaying || _isGameOver) return;

    setState(() {
      _direction = _nextDirection;
      final head = _snake.first;
      math.Point<int> newHead;

      switch (_direction) {
        case Direction.up:
          newHead = math.Point(head.x, head.y - 1);
          break;
        case Direction.down:
          newHead = math.Point(head.x, head.y + 1);
          break;
        case Direction.left:
          newHead = math.Point(head.x - 1, head.y);
          break;
        case Direction.right:
          newHead = math.Point(head.x + 1, head.y);
          break;
      }

      // Collision murs
      if (newHead.x < 0 || newHead.x >= gridSize || newHead.y < 0 || newHead.y >= gridSize) {
        _triggerGameOver();
        return;
      }

      // Collision propre corps
      if (_snake.contains(newHead)) {
        _triggerGameOver();
        return;
      }

      _snake.insert(0, newHead);

      // Manger la pomme
      if (newHead == _food) {
        _score += 50;
        StorageService.saveSnakeHighScore(_score);
        _highScore = math.max(_highScore, _score);
        FeedbackService.triggerSuccess();
        _spawnFood();
      } else {
        _snake.removeLast();
      }
    });
  }

  void _triggerGameOver() {
    _gameTimer?.cancel();
    _isPlaying = false;
    _isGameOver = true;
    FeedbackService.triggerImpact();
  }

  void _changeDirection(Direction newDir) {
    if ((_direction == Direction.up && newDir == Direction.down) ||
        (_direction == Direction.down && newDir == Direction.up) ||
        (_direction == Direction.left && newDir == Direction.right) ||
        (_direction == Direction.right && newDir == Direction.left)) {
      return;
    }
    _nextDirection = newDir;
    FeedbackService.triggerLight();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
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
        title: const Text(
          'SNAKE CYBER NÉON',
          style: TextStyle(
            color: Color(0xFF05FFA1),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) _changeDirection(Direction.up);
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) _changeDirection(Direction.down);
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _changeDirection(Direction.left);
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) _changeDirection(Direction.right);
          }
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          onPanEnd: (details) {
            final vx = details.velocity.pixelsPerSecond.dx;
            final vy = details.velocity.pixelsPerSecond.dy;
            if (vx.abs() > vy.abs()) {
              if (vx > 100) _changeDirection(Direction.right);
              if (vx < -100) _changeDirection(Direction.left);
            } else {
              if (vy > 100) _changeDirection(Direction.down);
              if (vy < -100) _changeDirection(Direction.up);
            }
          },
          child: SafeArea(
            child: Column(
              children: [
                // Score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  color: const Color(0xFF10172D),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('SCORE : $_score PTS', style: const TextStyle(color: Color(0xFF05FFA1), fontSize: 16, fontWeight: FontWeight.w900)),
                      Text('RECORD : $_highScore', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),

                const Spacer(),

                // Grille Snake
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C1326),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF05FFA1).withValues(alpha: 0.5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF05FFA1).withValues(alpha: 0.15),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridSize,
                        ),
                        itemCount: gridSize * gridSize,
                        itemBuilder: (ctx, idx) {
                          final x = idx % gridSize;
                          final y = idx ~/ gridSize;
                          final pt = math.Point(x, y);

                          final isHead = _snake.isNotEmpty && _snake.first == pt;
                          final isBody = _snake.contains(pt);
                          final isFood = _food == pt;

                          if (isFood) {
                            return Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [Color(0xFFFF5E7E), Color(0xFFFF0055), Color(0xFF990033)],
                                  center: Alignment(-0.2, -0.2),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF0055).withValues(alpha: 0.8),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 3,
                                  height: 3,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            );
                          }

                          if (isHead) {
                            return Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00FF87), Color(0xFF60EFFF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00FF87).withValues(alpha: 0.7),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF060914),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF060914),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (isBody) {
                            return Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00E676).withValues(alpha: 0.3),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            );
                          }

                          return Container(
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E1528),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Bouton Start / Rejouer
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: !_isPlaying
                      ? ElevatedButton.icon(
                          onPressed: _startGame,
                          icon: const Icon(Icons.play_arrow, color: Colors.black),
                          label: Text(
                            _isGameOver ? 'REJOUER' : 'COMMENCER LA PARTIE',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF05FFA1),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          ),
                        )
                      : const Text(
                          'Glissez le doigt pour diriger le serpent',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

