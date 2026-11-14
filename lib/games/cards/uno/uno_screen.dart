import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';
import 'uno_engine.dart';

class UnoScreen extends StatefulWidget {
  const UnoScreen({super.key});

  @override
  State<UnoScreen> createState() => _UnoScreenState();
}

class _UnoScreenState extends State<UnoScreen> with SingleTickerProviderStateMixin {
  final UnoGame _game = UnoGame();
  bool _isAiThinking = false;
  String _message = 'À vous de jouer ! Posez une carte ou piochez.';
  bool _unoSaid = false;

  void _onPlayerCardTap(UnoCard card) {
    if (!_game.isPlayerTurn || _isAiThinking) return;

    if (!_game.canPlay(card)) {
      FeedbackService.triggerLight();
      setState(() => _message = '⚠️ Carte incompatible avec la couleur ou le chiffre !');
      return;
    }

    if (card.isWild) {
      _showColorChoiceDialog((selectedColor) {
        _executePlay(card, selectedColor);
      });
    } else {
      _executePlay(card, null);
    }
  }

  void _executePlay(UnoCard card, UnoColor? wildColor) {
    setState(() {
      _game.playCard(card: card, isPlayer: true, chosenColorForWild: wildColor);
      FeedbackService.triggerImpact();

      if (_game.playerHand.isEmpty) {
        _message = '🏆 VICTOIRE ÉCLATANTE ! VOUS AVEZ GAGNÉ LA PARTIE UNO !';
        FeedbackService.triggerSuccess();
        return;
      }

      if (_game.playerHand.length == 1) {
        _unoSaid = false;
        _message = '⚠️ IL NE VOUS RESTE QU\'UNE CARTE ! CRIEZ "UNO !"';
      } else {
        _message = _game.isPlayerTurn ? '⚡ Effet spécial : Vous rejouez !' : 'Tour de l\'IA...';
      }
    });

    if (!_game.isPlayerTurn) {
      _triggerAiTurn();
    }
  }

  void _onDrawTap() {
    if (!_game.isPlayerTurn || _isAiThinking) return;

    final drawn = _game.drawCard(forPlayer: true);
    FeedbackService.triggerLight();
    setState(() {
      if (drawn != null && _game.canPlay(drawn)) {
        _message = 'Vous avez pioché ${drawn.label} ! Vous pouvez la jouer immédiatement.';
      } else {
        _message = 'Carte non jouable. Au tour de l\'adversaire...';
        _game.isPlayerTurn = false;
      }
    });

    if (!_game.isPlayerTurn) {
      _triggerAiTurn();
    }
  }

  void _triggerAiTurn() {
    setState(() => _isAiThinking = true);
    Timer(const Duration(milliseconds: 950), () {
      if (!mounted) return;

      final playable = _game.aiHand.where(_game.canPlay).toList();

      if (playable.isNotEmpty) {
        final chosen = playable.first;
        final standardColors = [UnoColor.red, UnoColor.blue, UnoColor.green, UnoColor.yellow];
        final randomColor = standardColors[math.Random().nextInt(standardColors.length)];

        _game.playCard(card: chosen, isPlayer: false, chosenColorForWild: randomColor);
        FeedbackService.triggerImpact();

        if (_game.aiHand.isEmpty) {
          setState(() {
            _message = 'L\'IA a posé sa dernière carte et remporte la partie !';
            _isAiThinking = false;
          });
          return;
        }

        if (_game.aiHand.length == 1) {
          FeedbackService.triggerLight();
          setState(() => _message = '🤖 L\'IA annonce : "UNO !" (Plus qu\'1 carte !)');
        } else {
          setState(() {
            _message = 'L\'IA a joué ${chosen.label} (${_game.activeColor.name.toUpperCase()})';
          });
        }
      } else {
        final drawn = _game.drawCard(forPlayer: false);
        FeedbackService.triggerLight();
        if (drawn != null && _game.canPlay(drawn)) {
          _game.playCard(card: drawn, isPlayer: false, chosenColorForWild: UnoColor.red);
          setState(() {
            _message = 'L\'IA a pioché et joué ${drawn.label} !';
          });
        } else {
          setState(() {
            _message = 'L\'IA pioche et passe son tour. À vous !';
            _game.isPlayerTurn = true;
          });
        }
      }

      setState(() => _isAiThinking = false);

      if (!_game.isPlayerTurn && _game.aiHand.isNotEmpty) {
        _triggerAiTurn();
      }
    });
  }

  void _showColorChoiceDialog(Function(UnoColor) onSelected) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131D36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white24)),
          title: const Text('CHOISISSEZ LA COULEUR UNO', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _colorPickerCircle(UnoColor.red, const Color(0xFFFF2A6D), onSelected, ctx),
              _colorPickerCircle(UnoColor.blue, const Color(0xFF00F0FF), onSelected, ctx),
              _colorPickerCircle(UnoColor.green, const Color(0xFF05FFA1), onSelected, ctx),
              _colorPickerCircle(UnoColor.yellow, const Color(0xFFFFD166), onSelected, ctx),
            ],
          ),
        );
      },
    );
  }

  Widget _colorPickerCircle(UnoColor color, Color display, Function(UnoColor) callback, BuildContext ctx) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        callback(color);
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: display,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: display.withValues(alpha: 0.8), blurRadius: 14)],
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = _game.topCard;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101733),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.style, color: Color(0xFFFF0055)),
            SizedBox(width: 8),
            Text(
              'UNO ROYALE',
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
            onPressed: () => setState(() {
              _game.reset();
              _message = 'Nouvelle partie ! Posez une carte pour démarrer.';
            }),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Tapis de jeu avec lueur centrale de la couleur active
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 1.2,
                  colors: [
                    _getColorDisplay(_game.activeColor).withValues(alpha: 0.18),
                    const Color(0xFF0B1126),
                    const Color(0xFF060914),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Zone Adversaire IA avec éventail de cartes au dos
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  color: Colors.black26,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFFFF0055),
                              child: Icon(Icons.smart_toy, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Adversaire IA (${_game.aiHand.length} cartes)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Éventail miniature
                      SizedBox(
                        height: 34,
                        width: math.min(180, _game.aiHand.length * 16.0 + 30),
                        child: Stack(
                          children: List.generate(_game.aiHand.length, (idx) {
                            return Positioned(
                              left: idx * 14.0,
                              child: Container(
                                width: 24,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFFF0055), width: 1.5),
                                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                                ),
                                child: const Center(
                                  child: Text('U', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bannière de statut dynamique
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getColorDisplay(_game.activeColor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getColorDisplay(_game.activeColor).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),

                const Spacer(),

                // Table centrale (Pioche UNO + Carte active de la défausse)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // PIOCHE UNO
                    GestureDetector(
                      onTap: _onDrawTap,
                      child: Container(
                        width: 95,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white30, width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 16, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ovale rouge UNO au dos
                            Transform.rotate(
                              angle: -0.32,
                              child: Container(
                                width: 75,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF0055),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: Colors.amberAccent, width: 2),
                                ),
                                child: const Center(
                                  child: Text(
                                    'UNO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      letterSpacing: 2.0,
                                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Positioned(
                              bottom: 8,
                              child: Text('PIOCHER', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 32),

                    // CARTE ACTIVE SUR LA DÉFAUSSE
                    _buildAuthenticUnoCard(top, isLarge: true),
                  ],
                ),

                const SizedBox(height: 16),

                // Indicateur de couleur active
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Couleur en jeu : ', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getColorDisplay(_game.activeColor),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: _getColorDisplay(_game.activeColor).withValues(alpha: 0.8), blurRadius: 10),
                        ],
                      ),
                      child: Text(
                        _game.activeColor.name.toUpperCase(),
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Bouton CRIER UNO si 1 carte restante
                if (_game.playerHand.length <= 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton.icon(
                      onPressed: _unoSaid
                          ? null
                          : () {
                              FeedbackService.triggerSuccess();
                              setState(() {
                                _unoSaid = true;
                                _message = '🔥 VOUS AVEZ CRIÉ "UNO !" Plus qu\'une carte pour la victoire !';
                              });
                            },
                      icon: Icon(_unoSaid ? Icons.check_circle : Icons.flash_on, color: Colors.white),
                      label: Text(
                        _unoSaid ? 'UNO VALIDÉ ! 🎴' : 'CRIER "UNO !" 🎴',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _unoSaid ? const Color(0xFF00FF66) : const Color(0xFFFF0055),
                        elevation: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),

                // Main du joueur (Éventail glissant fluide)
                Container(
                  height: 175,
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F152E),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 20)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Votre main (${_game.playerHand.length} cartes)',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (_game.isPlayerTurn)
                              const Text('⚡ Votre tour', style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _game.playerHand.length,
                          itemBuilder: (ctx, idx) {
                            final card = _game.playerHand[idx];
                            final canPlay = _game.isPlayerTurn && _game.canPlay(card);

                            return GestureDetector(
                              onTap: () => _onPlayerCardTap(card),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                transform: Matrix4.translationValues(0, canPlay ? -8 : 0, 0),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildAuthenticUnoCard(card, isPlayable: canPlay),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorDisplay(UnoColor c) {
    switch (c) {
      case UnoColor.red: return const Color(0xFFFF2A6D);
      case UnoColor.blue: return const Color(0xFF00F0FF);
      case UnoColor.green: return const Color(0xFF05FFA1);
      case UnoColor.yellow: return const Color(0xFFFFD166);
      case UnoColor.wild: return const Color(0xFFE056FD);
    }
  }

  Widget _buildAuthenticUnoCard(UnoCard card, {bool isPlayable = false, bool isLarge = false}) {
    final cardW = isLarge ? 100.0 : 76.0;
    final cardH = isLarge ? 146.0 : 115.0;
    final baseColor = card.isWild ? const Color(0xFF1E1038) : card.displayColor;

    return Container(
      width: cardW,
      height: cardH,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPlayable ? Colors.white : (isLarge ? Colors.white70 : Colors.white24),
          width: isPlayable ? 3.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isPlayable ? Colors.white.withValues(alpha: 0.5) : baseColor.withValues(alpha: 0.35),
            blurRadius: isPlayable ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ovale central incliné
          Center(
            child: Transform.rotate(
              angle: -0.32,
              child: Container(
                width: cardW * 0.78,
                height: cardH * 0.55,
                decoration: BoxDecoration(
                  color: card.isWild ? Colors.black87 : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Center(
                  child: Text(
                    card.label,
                    style: TextStyle(
                      color: card.isWild ? const Color(0xFF00FFCC) : baseColor,
                      fontSize: isLarge ? 38 : 28,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Chiffre en haut à gauche
          Positioned(
            top: 6,
            left: 8,
            child: Text(
              card.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: isLarge ? 16 : 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          // Chiffre en bas à droite inversé
          Positioned(
            bottom: 6,
            right: 8,
            child: Text(
              card.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: isLarge ? 16 : 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
