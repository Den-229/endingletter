import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';

enum LudoColor { red, green, yellow, blue }

class LudoPawn {
  final int id;
  final LudoColor color;
  int stepIndex = -1; // -1 = Écurie, 0..51 = Circuit commun, 52..57 = Ligne d'arrivée
  bool isHome = false;

  LudoPawn({required this.id, required this.color});
}

class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _diceAnim;
  final math.Random _rnd = math.Random();

  final List<LudoColor> _players = [LudoColor.red, LudoColor.blue];
  int _currentPlayerIdx = 0;
  int _diceValue = 6;
  bool _hasRolled = false;
  bool _isRolling = false;
  bool _vsAi = true;

  late Map<LudoColor, List<LudoPawn>> _pawns;

  @override
  void initState() {
    super.initState();
    _diceAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _resetGame();
  }

  void _resetGame() {
    _pawns = {
      for (final c in LudoColor.values)
        c: List.generate(4, (i) => LudoPawn(id: i, color: c)),
    };
    _currentPlayerIdx = 0;
    _diceValue = 6;
    _hasRolled = false;
    _isRolling = false;
  }

  @override
  void dispose() {
    _diceAnim.dispose();
    super.dispose();
  }

  void _rollDice() {
    if (_hasRolled || _isRolling) return;

    setState(() => _isRolling = true);
    FeedbackService.triggerLight();
    _diceAnim.forward(from: 0.0).then((_) {
      setState(() {
        _diceValue = _rnd.nextInt(6) + 1;
        _isRolling = false;
        _hasRolled = true;
      });

      final currentColor = _players[_currentPlayerIdx];
      final currentPawns = _pawns[currentColor]!;
      final movable = currentPawns.where((p) => _canMovePawn(p, _diceValue)).toList();

      if (movable.isEmpty) {
        Timer(const Duration(milliseconds: 650), _nextTurn);
      } else if (_vsAi && currentColor == LudoColor.blue) {
        Timer(const Duration(milliseconds: 550), () {
          _movePawn(movable.first);
        });
      }
    });
  }

  bool _canMovePawn(LudoPawn p, int dice) {
    if (p.isHome) return false;
    if (p.stepIndex == -1) {
      return dice == 6; // Sortie sur un 6
    }
    return (p.stepIndex + dice) <= 56;
  }

  void _movePawn(LudoPawn p) {
    if (!_hasRolled) return;
    if (!_canMovePawn(p, _diceValue)) return;

    setState(() {
      if (p.stepIndex == -1) {
        p.stepIndex = 0;
      } else {
        p.stepIndex += _diceValue;
        if (p.stepIndex >= 56) {
          p.isHome = true;
          FeedbackService.triggerSuccess();
        }
      }

      _checkPawnCaptures(p);

      FeedbackService.triggerImpact();
      _hasRolled = false;

      if (_diceValue == 6) {
        if (_vsAi && _players[_currentPlayerIdx] == LudoColor.blue) {
          Timer(const Duration(milliseconds: 600), _rollDice);
        }
      } else {
        _nextTurn();
      }
    });
  }

  void _checkPawnCaptures(LudoPawn mover) {
    if (mover.stepIndex == -1 || mover.stepIndex > 50) return;
    for (final otherColor in _players) {
      if (otherColor == mover.color) continue;
      for (final op in _pawns[otherColor]!) {
        if (op.stepIndex == mover.stepIndex) {
          op.stepIndex = -1;
          FeedbackService.triggerImpact();
        }
      }
    }
  }

  void _nextTurn() {
    setState(() {
      _hasRolled = false;
      _currentPlayerIdx = (_currentPlayerIdx + 1) % _players.length;
    });

    if (_vsAi && _players[_currentPlayerIdx] == LudoColor.blue) {
      Timer(const Duration(milliseconds: 650), _rollDice);
    }
  }

  Color _getColor(LudoColor c) {
    switch (c) {
      case LudoColor.red: return const Color(0xFFFF2A6D);
      case LudoColor.blue: return const Color(0xFF00F0FF);
      case LudoColor.green: return const Color(0xFF05FFA1);
      case LudoColor.yellow: return const Color(0xFFFFD166);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _players[_currentPlayerIdx];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101730),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.casino, color: Color(0xFF05FFA1)),
            SizedBox(width: 8),
            Text(
              'LUDO ROYAL CHEVAUX',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => setState(_resetGame),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Bandeau de tour et mode
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF101730),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getColor(currentColor),
                          boxShadow: [BoxShadow(color: _getColor(currentColor).withValues(alpha: 0.8), blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentColor == LudoColor.red ? 'Joueur Rouge' : (_vsAi ? 'IA Bleue' : 'Joueur Bleu'),
                        style: TextStyle(color: _getColor(currentColor), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('vs IA', style: TextStyle(fontSize: 11)),
                        selected: _vsAi,
                        selectedColor: const Color(0xFF05FFA1),
                        labelStyle: TextStyle(color: _vsAi ? Colors.black : Colors.white70, fontWeight: FontWeight.bold),
                        onSelected: (val) => setState(() => _vsAi = true),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('2 Joueurs', style: TextStyle(fontSize: 11)),
                        selected: !_vsAi,
                        selectedColor: const Color(0xFF05FFA1),
                        labelStyle: TextStyle(color: !_vsAi ? Colors.black : Colors.white70, fontWeight: FontWeight.bold),
                        onSelected: (val) => setState(() => _vsAi = false),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // PLATEAU OFFICIEL AUTHENTIQUE LUDO 15x15
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: _getColor(currentColor).withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 6)),
                  ],
                ),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        // Rendu du plateau de Ludo
                        CustomPaint(
                          size: const Size(double.infinity, double.infinity),
                          painter: _LudoBoardPainter(),
                        ),

                        // Superposition des pions interactifs
                        ..._buildPawnWidgets(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // DÉ 3D VIBRANT
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _rollDice,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.white, Color(0xFFE2E8F0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _getColor(currentColor).withValues(alpha: 0.6),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                          const BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
                        ],
                        border: Border.all(color: Colors.black12, width: 2),
                      ),
                      child: Center(
                        child: CustomPaint(
                          size: const Size(54, 54),
                          painter: _DicePipPainter(pipCount: _diceValue, dotColor: _getColor(currentColor)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _hasRolled
                        ? (_diceValue == 6 ? '🎉 UN 6 ! Vous pouvez sortir un pion ou avancer !' : 'Touchez un pion pour avancer de $_diceValue cases')
                        : 'Touchez le dé pour lancer !',
                    style: TextStyle(
                      color: _hasRolled ? const Color(0xFF00FFCC) : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPawnWidgets() {
    List<Widget> widgets = [];

    // Positions d'écurie fixes sur grille 15x15
    final yardBases = {
      LudoColor.red: [const Offset(1.5, 1.5), const Offset(3.5, 1.5), const Offset(1.5, 3.5), const Offset(3.5, 3.5)],
      LudoColor.green: [const Offset(10.5, 1.5), const Offset(12.5, 1.5), const Offset(10.5, 3.5), const Offset(12.5, 3.5)],
      LudoColor.yellow: [const Offset(1.5, 10.5), const Offset(3.5, 10.5), const Offset(1.5, 12.5), const Offset(3.5, 12.5)],
      LudoColor.blue: [const Offset(10.5, 10.5), const Offset(12.5, 10.5), const Offset(10.5, 12.5), const Offset(12.5, 12.5)],
    };

    for (final color in _players) {
      final pawns = _pawns[color]!;
      for (int i = 0; i < pawns.length; i++) {
        final p = pawns[i];
        Offset gridCoord;

        if (p.isHome) {
          gridCoord = const Offset(7.0, 7.0); // Centre
        } else if (p.stepIndex == -1) {
          gridCoord = yardBases[color]![i];
        } else {
          gridCoord = _getTrackCoord(color, p.stepIndex);
        }

        final canMove = _hasRolled && _canMovePawn(p, _diceValue) && _players[_currentPlayerIdx] == color;

        widgets.add(
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cellSize = constraints.maxWidth / 15.0;
              final left = gridCoord.dx * cellSize;
              final top = gridCoord.dy * cellSize;

              return Positioned(
                left: left,
                top: top,
                width: cellSize,
                height: cellSize,
                child: GestureDetector(
                  onTap: canMove ? () => _movePawn(p) : null,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: canMove ? cellSize * 0.95 : cellSize * 0.75,
                      height: canMove ? cellSize * 0.95 : cellSize * 0.75,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getColor(color),
                        border: Border.all(
                          color: canMove ? Colors.white : Colors.black87,
                          width: canMove ? 3.0 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: canMove ? Colors.white : Colors.black45,
                            blurRadius: canMove ? 10 : 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          p.isHome ? Icons.star : Icons.shield,
                          color: Colors.white,
                          size: cellSize * 0.45,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    return widgets;
  }

  Offset _getTrackCoord(LudoColor color, int step) {
    // Coordonnées simplifiées du circuit en croix 15x15
    const redTrack = [
      Offset(1, 6), Offset(2, 6), Offset(3, 6), Offset(4, 6), Offset(5, 6),
      Offset(6, 5), Offset(6, 4), Offset(6, 3), Offset(6, 2), Offset(6, 1), Offset(6, 0),
      Offset(7, 0), Offset(8, 0),
      Offset(8, 1), Offset(8, 2), Offset(8, 3), Offset(8, 4), Offset(8, 5),
      Offset(9, 6), Offset(10, 6), Offset(11, 6), Offset(12, 6), Offset(13, 6), Offset(14, 6),
      Offset(14, 7), Offset(14, 8),
      Offset(13, 8), Offset(12, 8), Offset(11, 8), Offset(10, 8), Offset(9, 8),
      Offset(8, 9), Offset(8, 10), Offset(8, 11), Offset(8, 12), Offset(8, 13), Offset(8, 14),
      Offset(7, 14), Offset(6, 14),
      Offset(6, 13), Offset(6, 12), Offset(6, 11), Offset(6, 10), Offset(6, 9),
      Offset(5, 8), Offset(4, 8), Offset(3, 8), Offset(2, 8), Offset(1, 8), Offset(0, 8),
      Offset(0, 7), Offset(1, 7),
      // Ligne d'arrivée rouge
      Offset(2, 7), Offset(3, 7), Offset(4, 7), Offset(5, 7), Offset(6, 7), Offset(7, 7)
    ];

    if (color == LudoColor.red) {
      return redTrack[step % redTrack.length];
    } else {
      // Décalage pour le bleu (commence à l'opposé)
      final offsetStep = (step + 26) % 52;
      return redTrack[offsetStep];
    }
  }
}

// Dessin complet du vrai plateau de jeu de Ludo
class _LudoBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 15.0;

    // 1. Écuries (Coins 6x6)
    // Rouge (Haut-Gauche)
    canvas.drawRect(Rect.fromLTWH(0, 0, cellSize * 6, cellSize * 6), Paint()..color = const Color(0xFFFF2A6D));
    _drawInnerYard(canvas, cellSize, 0, 0, const Color(0xFFFF2A6D));

    // Vert (Haut-Droite)
    canvas.drawRect(Rect.fromLTWH(cellSize * 9, 0, cellSize * 6, cellSize * 6), Paint()..color = const Color(0xFF05FFA1));
    _drawInnerYard(canvas, cellSize, 9, 0, const Color(0xFF05FFA1));

    // Jaune (Bas-Gauche)
    canvas.drawRect(Rect.fromLTWH(0, cellSize * 9, cellSize * 6, cellSize * 6), Paint()..color = const Color(0xFFFFD166));
    _drawInnerYard(canvas, cellSize, 0, 9, const Color(0xFFFFD166));

    // Bleu (Bas-Droite)
    canvas.drawRect(Rect.fromLTWH(cellSize * 9, cellSize * 9, cellSize * 6, cellSize * 6), Paint()..color = const Color(0xFF00F0FF));
    _drawInnerYard(canvas, cellSize, 9, 9, const Color(0xFF00F0FF));

    // 2. Grille de cases du circuit en croix
    final gridLinePaint = Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 1.0;
    for (int r = 0; r < 15; r++) {
      for (int c = 0; c < 15; c++) {
        // Dessiner uniquement les cases de la croix (colonnes 6,7,8 ou lignes 6,7,8)
        if ((r >= 6 && r <= 8) || (c >= 6 && c <= 8)) {
          final rect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);

          // Ligne d'arrivée rouge
          if (r == 7 && c >= 1 && c <= 6) {
            canvas.drawRect(rect, Paint()..color = const Color(0xFFFF2A6D));
          } else if (c == 7 && r >= 1 && r <= 6) {
            // Arrivée verte
            canvas.drawRect(rect, Paint()..color = const Color(0xFF05FFA1));
          } else if (r == 7 && c >= 8 && c <= 13) {
            // Arrivée bleue
            canvas.drawRect(rect, Paint()..color = const Color(0xFF00F0FF));
          } else if (c == 7 && r >= 8 && r <= 13) {
            // Arrivée jaune
            canvas.drawRect(rect, Paint()..color = const Color(0xFFFFD166));
          }

          canvas.drawRect(rect, gridLinePaint);
        }
      }
    }

    // 3. Centre triangulaire de victoire (3x3 au milieu)
    final cx = cellSize * 7.5;
    final cy = cellSize * 7.5;
    // Triangle gauche (Rouge)
    final pathRed = Path()..moveTo(cellSize * 6, cellSize * 6)..lineTo(cellSize * 6, cellSize * 9)..lineTo(cx, cy)..close();
    canvas.drawPath(pathRed, Paint()..color = const Color(0xFFFF2A6D));
    // Triangle bas (Jaune)
    final pathYellow = Path()..moveTo(cellSize * 6, cellSize * 9)..lineTo(cellSize * 9, cellSize * 9)..lineTo(cx, cy)..close();
    canvas.drawPath(pathYellow, Paint()..color = const Color(0xFFFFD166));
    // Triangle droite (Bleu)
    final pathBlue = Path()..moveTo(cellSize * 9, cellSize * 9)..lineTo(cellSize * 9, cellSize * 6)..lineTo(cx, cy)..close();
    canvas.drawPath(pathBlue, Paint()..color = const Color(0xFF00F0FF));
    // Triangle haut (Vert)
    final pathGreen = Path()..moveTo(cellSize * 9, cellSize * 6)..lineTo(cellSize * 6, cellSize * 6)..lineTo(cx, cy)..close();
    canvas.drawPath(pathGreen, Paint()..color = const Color(0xFF05FFA1));
  }

  void _drawInnerYard(Canvas canvas, double cellSize, int c, int r, Color color) {
    final yardRect = Rect.fromLTWH((c + 1) * cellSize, (r + 1) * cellSize, cellSize * 4, cellSize * 4);
    canvas.drawRRect(RRect.fromRectAndRadius(yardRect, const Radius.circular(12)), Paint()..color = Colors.white);

    // 4 ronds pour les pions
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(Offset((c + 2.0) * cellSize, (r + 2.0) * cellSize), cellSize * 0.6, dotPaint);
    canvas.drawCircle(Offset((c + 4.0) * cellSize, (r + 2.0) * cellSize), cellSize * 0.6, dotPaint);
    canvas.drawCircle(Offset((c + 2.0) * cellSize, (r + 4.0) * cellSize), cellSize * 0.6, dotPaint);
    canvas.drawCircle(Offset((c + 4.0) * cellSize, (r + 4.0) * cellSize), cellSize * 0.6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Dessin des vrais points du dé (pip dots)
class _DicePipPainter extends CustomPainter {
  final int pipCount;
  final Color dotColor;

  _DicePipPainter({required this.pipCount, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    final r = size.width * 0.11;
    final c1 = size.width * 0.25;
    final c2 = size.width * 0.50;
    final c3 = size.width * 0.75;

    switch (pipCount) {
      case 1:
        canvas.drawCircle(Offset(c2, c2), r, paint);
        break;
      case 2:
        canvas.drawCircle(Offset(c1, c1), r, paint);
        canvas.drawCircle(Offset(c3, c3), r, paint);
        break;
      case 3:
        canvas.drawCircle(Offset(c1, c1), r, paint);
        canvas.drawCircle(Offset(c2, c2), r, paint);
        canvas.drawCircle(Offset(c3, c3), r, paint);
        break;
      case 4:
        canvas.drawCircle(Offset(c1, c1), r, paint);
        canvas.drawCircle(Offset(c3, c1), r, paint);
        canvas.drawCircle(Offset(c1, c3), r, paint);
        canvas.drawCircle(Offset(c3, c3), r, paint);
        break;
      case 5:
        canvas.drawCircle(Offset(c1, c1), r, paint);
        canvas.drawCircle(Offset(c3, c1), r, paint);
        canvas.drawCircle(Offset(c2, c2), r, paint);
        canvas.drawCircle(Offset(c1, c3), r, paint);
        canvas.drawCircle(Offset(c3, c3), r, paint);
        break;
      case 6:
        canvas.drawCircle(Offset(c1, c1), r, paint);
        canvas.drawCircle(Offset(c1, c2), r, paint);
        canvas.drawCircle(Offset(c1, c3), r, paint);
        canvas.drawCircle(Offset(c3, c1), r, paint);
        canvas.drawCircle(Offset(c3, c2), r, paint);
        canvas.drawCircle(Offset(c3, c3), r, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DicePipPainter oldDelegate) => oldDelegate.pipCount != pipCount;
}
