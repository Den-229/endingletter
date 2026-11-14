import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';

class MemoryCard {
  final int id;
  final IconData icon;
  final Color color;
  bool isFlipped;
  bool isMatched;

  MemoryCard({
    required this.id,
    required this.icon,
    required this.color,
    this.isFlipped = false,
    this.isMatched = false,
  });
}

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  late List<MemoryCard> _cards;
  int? _firstFlippedIndex;
  bool _isProcessing = false;
  int _moves = 0;
  int _pairsFound = 0;
  Timer? _timer;
  int _seconds = 0;
  bool _isWon = false;

  final List<Map<String, dynamic>> _iconData = [
    {'icon': Icons.rocket_launch, 'color': const Color(0xFF00FFCC)},
    {'icon': Icons.flash_on, 'color': const Color(0xFFFFD166)},
    {'icon': Icons.favorite, 'color': const Color(0xFFFF2A6D)},
    {'icon': Icons.diamond, 'color': const Color(0xFF00F0FF)},
    {'icon': Icons.sports_esports, 'color': const Color(0xFFE056FD)},
    {'icon': Icons.local_fire_department, 'color': const Color(0xFFFF5500)},
    {'icon': Icons.public, 'color': const Color(0xFF05FFA1)},
    {'icon': Icons.emoji_events, 'color': const Color(0xFFFFBC00)},
  ];

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    _timer?.cancel();
    _seconds = 0;
    _moves = 0;
    _pairsFound = 0;
    _firstFlippedIndex = null;
    _isProcessing = false;
    _isWon = false;

    List<MemoryCard> deck = [];
    int idCounter = 0;
    for (final item in _iconData) {
      deck.add(MemoryCard(id: idCounter++, icon: item['icon'], color: item['color']));
      deck.add(MemoryCard(id: idCounter++, icon: item['icon'], color: item['color']));
    }
    deck.shuffle();
    _cards = deck;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isWon && mounted) {
        setState(() => _seconds++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onCardTap(int index) {
    if (_isProcessing || _cards[index].isFlipped || _cards[index].isMatched) return;

    setState(() {
      _cards[index].isFlipped = true;
    });
    FeedbackService.triggerLight();

    if (_firstFlippedIndex == null) {
      _firstFlippedIndex = index;
    } else {
      _moves++;
      final first = _cards[_firstFlippedIndex!];
      final second = _cards[index];

      if (first.icon == second.icon) {
        // Paire trouvée !
        first.isMatched = true;
        second.isMatched = true;
        _pairsFound++;
        _firstFlippedIndex = null;
        FeedbackService.triggerSuccess();

        if (_pairsFound == 8) {
          _isWon = true;
        }
      } else {
        // Erreur, retourner les deux cartes après 700ms
        _isProcessing = true;
        Timer(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          setState(() {
            first.isFlipped = false;
            second.isFlipped = false;
            _firstFlippedIndex = null;
            _isProcessing = false;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF11192E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'MÉMOIRE QUANTIQUE',
          style: TextStyle(
            color: Color(0xFFE056FD),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
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
            // Bandeau Score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFF11192E),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.touch_app, color: Color(0xFF00FFCC), size: 18),
                      const SizedBox(width: 6),
                      Text('$_moves Coups', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Color(0xFFFFD166), size: 18),
                      const SizedBox(width: 6),
                      Text('$_seconds s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFFE056FD), size: 18),
                      const SizedBox(width: 6),
                      Text('$_pairsFound / 8', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Grille 4x4
            Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(8),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 16,
                    itemBuilder: (ctx, idx) {
                      final card = _cards[idx];
                      return GestureDetector(
                        onTap: () => _onCardTap(idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: card.isFlipped || card.isMatched
                                ? const Color(0xFF18233D)
                                : const Color(0xFF101627),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: card.isMatched
                                  ? card.color
                                  : (card.isFlipped ? card.color.withValues(alpha: 0.6) : Colors.white12),
                              width: 2,
                            ),
                            boxShadow: card.isFlipped || card.isMatched
                                ? [
                                    BoxShadow(
                                      color: card.color.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: card.isFlipped || card.isMatched
                                ? Icon(card.icon, color: card.color, size: 36)
                                : const Icon(Icons.question_mark, color: Colors.white24, size: 24),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            const Spacer(),

            if (_isWon)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: ElevatedButton.icon(
                  onPressed: () => setState(_resetGame),
                  icon: const Icon(Icons.replay, color: Colors.black),
                  label: const Text('REJOUER UNE PARTIE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFCC)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
