import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/confetti_overlay.dart';
import 'solitaire_engine.dart';

class SolitaireScreen extends StatefulWidget {
  const SolitaireScreen({super.key});

  @override
  State<SolitaireScreen> createState() => _SolitaireScreenState();
}

class _SolitaireScreenState extends State<SolitaireScreen> {
  final SolitaireEngine _engine = SolitaireEngine();
  PlayingCard? _selectedCard;
  PlayingCard? _hintedCard;
  int _seconds = 0;
  Timer? _timer;
  bool _isWon = false;
  int _highScore = 0;
  bool _isAutoCompleting = false;

  @override
  void initState() {
    super.initState();
    _highScore = StorageService.getSolitaireHighScore();
    _startNewGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startNewGame() {
    _timer?.cancel();
    _seconds = 0;
    _isWon = false;
    _isAutoCompleting = false;
    _selectedCard = null;
    _hintedCard = null;
    _engine.dealNewGame();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted && !_isWon) {
        setState(() => _seconds++);
      }
    });
    setState(() {});
  }

  void _undo() {
    if (_isWon || !_engine.canUndo) return;
    FeedbackService.triggerLight();
    setState(() {
      _engine.undo();
      _selectedCard = null;
      _hintedCard = null;
    });
  }

  void _triggerHint() {
    if (_isWon) return;
    FeedbackService.triggerSelection();
    final hint = _engine.findHint();
    setState(() {
      _hintedCard = hint;
    });

    if (hint != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF0F1B33),
          content: Text(
            '💡 Astuce : Déplacez ${hint.label}${hint.suit.symbol} !',
            style: const TextStyle(color: Color(0xFFFFD166), fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF0F1B33),
          content: Text(
            '💡 Piochez une nouvelle carte dans le talon !',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
  }

  void _startAutoComplete() {
    if (_isAutoCompleting || _isWon) return;
    _isAutoCompleting = true;
    FeedbackService.triggerSuccess();

    Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted || _isWon) {
        timer.cancel();
        return;
      }
      final moved = _engine.stepAutoComplete();
      setState(() {});
      if (moved) {
        FeedbackService.triggerLight();
        _checkWin();
      } else {
        timer.cancel();
        _isAutoCompleting = false;
      }
    });
  }

  void _onCardTap(PlayingCard card) {
    if (_isWon || _isAutoCompleting) return;

    if (!card.isFaceUp) return;

    setState(() => _hintedCard = null);

    // Si déjà sélectionnée ou tap direct: tentative auto-move
    final moved = _engine.tryAutoMove(card);
    if (moved) {
      FeedbackService.triggerImpact();
      _selectedCard = null;
      _checkWin();
    } else {
      FeedbackService.triggerLight();
      setState(() {
        _selectedCard = (_selectedCard == card) ? null : card;
      });
    }
  }

  void _onTableauColumnTap(int colIndex) {
    if (_selectedCard == null || _isAutoCompleting) return;

    final moved = _engine.canMoveToTableau(_selectedCard!, colIndex);
    if (moved) {
      _engine.tryAutoMove(_selectedCard!);
      FeedbackService.triggerImpact();
      setState(() {
        _selectedCard = null;
        _hintedCard = null;
      });
      _checkWin();
    }
  }

  void _onFoundationTap(int foundationIndex) {
    if (_selectedCard == null || _isAutoCompleting) return;

    final moved = _engine.canMoveToFoundation(_selectedCard!, foundationIndex);
    if (moved) {
      _engine.tryAutoMove(_selectedCard!);
      FeedbackService.triggerImpact();
      setState(() {
        _selectedCard = null;
        _hintedCard = null;
      });
      _checkWin();
    }
  }

  void _checkWin() {
    if (_engine.isGameWon()) {
      _timer?.cancel();
      _isWon = true;
      FeedbackService.triggerSuccess();
      StorageService.saveSolitaireHighScore(_engine.score);
    }
    setState(() {});
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ConfettiOverlay(
      showCelebration: _isWon,
      title: 'SOLITAIRE ACCOMPLI ! 👑',
      subtitle: '+250 XP • Score : ${_engine.score} pts',
      child: Scaffold(
        backgroundColor: const Color(0xFF0A3319), // Tapis de feutre vert casino
        appBar: AppBar(
          backgroundColor: const Color(0xFF062411),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'SOLITAIRE KLONDIKE',
            style: TextStyle(
              color: Color(0xFFFFD166),
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
          actions: [
            // Mode Pioche 1 / 3
            TextButton(
              onPressed: () {
                setState(() => _engine.drawThreeMode = !_engine.drawThreeMode);
                FeedbackService.triggerSelection();
              },
              child: Text(
                _engine.drawThreeMode ? '3 CARTES' : '1 CARTE',
                style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            // Indice
            IconButton(
              icon: const Icon(Icons.lightbulb_outline, color: Color(0xFFFFD166)),
              tooltip: 'Indice',
              onPressed: _triggerHint,
            ),
            // Annuler
            IconButton(
              icon: Icon(Icons.undo, color: _engine.canUndo ? Colors.white : Colors.white24),
              tooltip: 'Annuler le coup',
              onPressed: _engine.canUndo ? _undo : null,
            ),
            // Nouvelle partie
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              tooltip: 'Nouvelle donne',
              onPressed: _startNewGame,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // HUD (Score, Coups, Temps, Record)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF04190B),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('SCORE : ${_engine.score}', style: const TextStyle(color: Color(0xFFFFD166), fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 14),
                      Text('COUPS : ${_engine.moves}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(width: 14),
                      Text('TEMPS : ${_formatTime(_seconds)}', style: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 14),
                      Text('RECORD : $_highScore', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ),

              // Bannière Auto-Complete quand la victoire est assurée
              if (_engine.canAutoComplete() && !_isWon)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: ElevatedButton.icon(
                    onPressed: _startAutoComplete,
                    icon: const Icon(Icons.bolt, color: Colors.black),
                    label: const Text('AUTO-COMPLÉTER LA PARTIE ⚡', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD166),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 6,
                    ),
                  ),
                ),

              // Rangée Supérieure : Pioche, Défausse et 4 Fondations
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    // Talon / Pioche (Stock)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          FeedbackService.triggerLight();
                          setState(() {
                            _engine.drawCard();
                            _selectedCard = null;
                            _hintedCard = null;
                          });
                        },
                        child: _engine.stock.isNotEmpty
                            ? _buildCardBack()
                            : _buildEmptySlot(Icons.refresh, 'RECYCLE'),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Défausse (Waste)
                    Expanded(
                      child: _engine.waste.isNotEmpty
                          ? GestureDetector(
                              onTap: () => _onCardTap(_engine.waste.last),
                              child: _buildCardView(
                                _engine.waste.last,
                                isSelected: _selectedCard == _engine.waste.last,
                                isHinted: _hintedCard == _engine.waste.last,
                              ),
                            )
                          : _buildEmptySlot(Icons.crop_portrait, 'DÉFAUSSE'),
                    ),

                    const SizedBox(width: 14),

                    // 4 Fondations (As -> Rois)
                    ...List.generate(4, (fIdx) {
                      final pile = _engine.foundations[fIdx];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _onFoundationTap(fIdx),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            child: pile.isNotEmpty
                                ? _buildCardView(pile.last)
                                : _buildEmptySlot(Icons.stars, 'A'),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const Divider(color: Colors.white12, thickness: 1, height: 1),

              // Tableau de 7 colonnes
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(7, (colIdx) {
                      final column = _engine.tableau[colIdx];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _onTableauColumnTap(colIdx),
                          child: Container(
                            color: Colors.transparent, // Capture les clics sur colonne vide
                            child: column.isEmpty
                                ? _buildEmptySlot(Icons.crop_portrait, 'K')
                                : Stack(
                                    children: List.generate(column.length, (cardIdx) {
                                      final card = column[cardIdx];
                                      final topOffset = cardIdx * 24.0;
                                      return Positioned(
                                        top: topOffset,
                                        left: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () => _onCardTap(card),
                                          child: card.isFaceUp
                                              ? _buildCardView(
                                                  card,
                                                  isSelected: _selectedCard == card,
                                                  isHinted: _hintedCard == card,
                                                )
                                              : _buildCardBack(),
                                        ),
                                      );
                                    }),
                                  ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // Barre d'outils tactile en bas
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF062411),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TextButton.icon(
                      onPressed: _engine.canUndo ? _undo : null,
                      icon: Icon(Icons.undo, size: 16, color: _engine.canUndo ? const Color(0xFF00FFCC) : Colors.white24),
                      label: Text('Annuler', style: TextStyle(color: _engine.canUndo ? const Color(0xFF00FFCC) : Colors.white24, fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: _triggerHint,
                      icon: const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFFFD166)),
                      label: const Text('Indice', style: TextStyle(color: Color(0xFFFFD166), fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: _startNewGame,
                      icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
                      label: const Text('Rejouer', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySlot(IconData icon, String label) {
    return AspectRatio(
      aspectRatio: 0.72,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white30, size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack() {
    return AspectRatio(
      aspectRatio: 0.72,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white54, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFFD166).withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Icon(Icons.diamond, color: Color(0xFFFFD166), size: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardView(PlayingCard card, {bool isSelected = false, bool isHinted = false}) {
    final isRed = card.suit.isRed;
    final color = isRed ? const Color(0xFFE50914) : const Color(0xFF111726);

    final borderColor = isHinted
        ? const Color(0xFFFFD166)
        : (isSelected ? const Color(0xFF00FFCC) : Colors.black26);

    return AspectRatio(
      aspectRatio: 0.72,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: (isSelected || isHinted) ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isHinted
                  ? const Color(0xFFFFD166).withValues(alpha: 0.7)
                  : (isSelected ? const Color(0xFF00FFCC).withValues(alpha: 0.5) : Colors.black38),
              blurRadius: (isSelected || isHinted) ? 10 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  card.label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                Text(
                  card.suit.symbol,
                  style: TextStyle(color: color, fontSize: 10),
                ),
              ],
            ),
            Center(
              child: Text(
                card.suit.symbol,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                card.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
