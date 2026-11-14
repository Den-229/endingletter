import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';

class PlayingCard {
  final String suit; // ♠, ♥, ♦, ♣
  final String rank; // 2..10, J, Q, K, A
  final int value;

  PlayingCard({required this.suit, required this.rank, required this.value});

  bool get isRed => suit == '♥' || suit == '♦';

  String get royalSymbol {
    switch (rank) {
      case 'K': return '♔';
      case 'Q': return '♕';
      case 'J': return '♖';
      case 'A': return '★';
      default: return suit;
    }
  }
}

class BlackjackScreen extends StatefulWidget {
  const BlackjackScreen({super.key});

  @override
  State<BlackjackScreen> createState() => _BlackjackScreenState();
}

class _BlackjackScreenState extends State<BlackjackScreen> {
  final List<PlayingCard> _deck = [];
  final List<PlayingCard> _playerHand = [];
  final List<PlayingCard> _dealerHand = [];

  int _chips = 1000;
  int _currentBet = 50;
  bool _inGame = false;
  bool _dealerTurn = false;
  String _statusMessage = 'Placez votre mise et lancez la donne !';
  final math.Random _rnd = math.Random();

  void _initDeck() {
    _deck.clear();
    const suits = ['♠', '♥', '♦', '♣'];
    const ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];

    for (final s in suits) {
      for (final r in ranks) {
        int val = int.tryParse(r) ?? 10;
        if (r == 'A') val = 11;
        _deck.add(PlayingCard(suit: s, rank: r, value: val));
      }
    }
    _deck.shuffle(_rnd);
  }

  PlayingCard _drawCard() {
    if (_deck.isEmpty) _initDeck();
    return _deck.removeLast();
  }

  int _calculateScore(List<PlayingCard> hand) {
    int score = 0;
    int aces = 0;
    for (final c in hand) {
      score += c.value;
      if (c.rank == 'A') aces++;
    }
    while (score > 21 && aces > 0) {
      score -= 10;
      aces--;
    }
    return score;
  }

  void _startRound() {
    if (_chips < _currentBet) {
      setState(() => _statusMessage = '⚠️ Jetons insuffisants pour cette mise !');
      return;
    }

    _initDeck();
    _playerHand.clear();
    _dealerHand.clear();
    _dealerTurn = false;
    _chips -= _currentBet;

    _playerHand.add(_drawCard());
    _dealerHand.add(_drawCard());
    _playerHand.add(_drawCard());
    _dealerHand.add(_drawCard());

    _inGame = true;
    FeedbackService.triggerLight();

    final playerScore = _calculateScore(_playerHand);
    if (playerScore == 21) {
      _stand();
    } else {
      _statusMessage = 'Votre tour : CARTE (+1) ou RESTER ?';
    }
    setState(() {});
  }

  void _hit() {
    if (!_inGame || _dealerTurn) return;

    _playerHand.add(_drawCard());
    FeedbackService.triggerLight();

    final score = _calculateScore(_playerHand);
    if (score > 21) {
      _statusMessage = '💥 BUST ! Vous avez dépassé 21.';
      _inGame = false;
      FeedbackService.triggerImpact();
    } else if (score == 21) {
      _stand();
    }
    setState(() {});
  }

  void _stand() {
    if (!_inGame) return;

    setState(() {
      _dealerTurn = true;
      _statusMessage = 'Le croupier tire ses cartes...';
    });

    Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      _dealerPlay();
    });
  }

  void _dealerPlay() {
    while (_calculateScore(_dealerHand) < 17) {
      _dealerHand.add(_drawCard());
    }

    final pScore = _calculateScore(_playerHand);
    final dScore = _calculateScore(_dealerHand);

    setState(() {
      _inGame = false;
      if (dScore > 21) {
        _chips += _currentBet * 2;
        _statusMessage = '🎉 Le croupier dépasse 21 ! Vous gagnez !';
        FeedbackService.triggerSuccess();
      } else if (pScore > dScore) {
        final isNaturalBlackjack = pScore == 21 && _playerHand.length == 2;
        final winnings = isNaturalBlackjack ? (_currentBet * 2.5).toInt() : _currentBet * 2;
        _chips += winnings;
        _statusMessage = isNaturalBlackjack
            ? '🔥 BLACKJACK NATUREL 21 ! Gain x2.5 !'
            : '🎉 Victoire ! Vous battez le croupier ($pScore vs $dScore)';
        FeedbackService.triggerSuccess();
      } else if (pScore < dScore) {
        _statusMessage = 'Le croupier l\'emporte ($dScore vs $pScore).';
        FeedbackService.triggerImpact();
      } else {
        _chips += _currentBet;
        _statusMessage = 'Égalité (Push) ! Votre mise est restituée.';
        FeedbackService.triggerLight();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerScore = _calculateScore(_playerHand);
    final dealerScore = _calculateScore(_dealerHand);

    return Scaffold(
      backgroundColor: const Color(0xFF071912),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2D21),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.monetization_on, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text(
              'BLACKJACK 21 MONACO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Tapis vert casino avec dégradé et bord doré
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  center: Alignment(0, -0.1),
                  radius: 1.1,
                  colors: [Color(0xFF14532D), Color(0xFF0B331C), Color(0xFF051B0F)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFFFD166), width: 3),
                boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 20)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 18),

                // Banque de Jetons & Mise actuelle
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.stars, color: Colors.amberAccent, size: 22),
                          const SizedBox(width: 8),
                          Text('$_chips JETONS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.amberAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                        child: Text('MISE : $_currentBet', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

                // Message du croupier
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),

                const Spacer(),

                // Zone Croupier
                Column(
                  children: [
                    Text(
                      _dealerTurn || !_inGame ? 'MAIN DU CROUPIER : $dealerScore' : 'MAIN DU CROUPIER',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_dealerHand.length, (idx) {
                        if (idx == 1 && !_dealerTurn && _inGame) {
                          return _buildCardBack();
                        }
                        return _buildCasinoCard(_dealerHand[idx]);
                      }),
                    ),
                  ],
                ),

                const Spacer(),

                // Zone Joueur
                Column(
                  children: [
                    Text(
                      _inGame ? 'VOTRE SCORE : $playerScore' : 'VOTRE JEU',
                      style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _playerHand.map(_buildCasinoCard).toList(),
                    ),
                  ],
                ),

                const Spacer(),

                // Actions du Joueur
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: _inGame
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _hit,
                              icon: const Icon(Icons.add_circle, color: Colors.black),
                              label: const Text('CARTE (+1)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00FFCC),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                elevation: 8,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _stand,
                              icon: const Icon(Icons.pan_tool, color: Colors.white),
                              label: const Text('RESTER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF2A6D),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                elevation: 8,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            // Sélecteur de Jetons Authentiques
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [10, 25, 50, 100, 250].map((bet) {
                                final isSelected = _currentBet == bet;
                                return GestureDetector(
                                  onTap: () => setState(() => _currentBet = bet),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 5),
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _getChipColor(bet),
                                      border: Border.all(color: isSelected ? Colors.white : Colors.white54, width: isSelected ? 3.0 : 1.5),
                                      boxShadow: isSelected
                                          ? [BoxShadow(color: _getChipColor(bet).withValues(alpha: 0.8), blurRadius: 12)]
                                          : const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$bet',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _startRound,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFD166),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 10,
                                ),
                                child: const Text(
                                  'DISTRIBUER LA DONNE 🃏',
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5),
                                ),
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

  Color _getChipColor(int amount) {
    switch (amount) {
      case 10: return const Color(0xFF0077B6);
      case 25: return const Color(0xFF2D6A4F);
      case 50: return const Color(0xFFD90429);
      case 100: return const Color(0xFF1B1B1E);
      case 250: return const Color(0xFF7209B7);
      default: return Colors.black;
    }
  }

  Widget _buildCasinoCard(PlayingCard card) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: 65,
      height: 98,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black26),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Stack(
        children: [
          // Index coin haut-gauche
          Positioned(
            top: 4,
            left: 6,
            child: Column(
              children: [
                Text(card.rank, style: TextStyle(color: card.isRed ? Colors.red : Colors.black, fontSize: 13, fontWeight: FontWeight.w900)),
                Text(card.suit, style: TextStyle(color: card.isRed ? Colors.red : Colors.black, fontSize: 12)),
              ],
            ),
          ),

          // Symbole royal central
          Center(
            child: Text(
              card.royalSymbol,
              style: TextStyle(
                color: card.isRed ? const Color(0xFFD90429) : Colors.black87,
                fontSize: 34,
              ),
            ),
          ),

          // Index coin bas-droite
          Positioned(
            bottom: 4,
            right: 6,
            child: Column(
              children: [
                Text(card.suit, style: TextStyle(color: card.isRed ? Colors.red : Colors.black, fontSize: 12)),
                Text(card.rank, style: TextStyle(color: card.isRed ? Colors.red : Colors.black, fontSize: 13, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: 65,
      height: 98,
      decoration: BoxDecoration(
        color: const Color(0xFF8B0000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Center(
        child: Container(
          width: 45,
          height: 75,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amberAccent, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Center(
            child: Icon(Icons.shield, color: Colors.amberAccent, size: 24),
          ),
        ),
      ),
    );
  }
}
