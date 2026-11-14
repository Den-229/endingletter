import 'dart:math' as math;

enum CardSuit { hearts, diamonds, clubs, spades }

extension CardSuitExtension on CardSuit {
  bool get isRed => this == CardSuit.hearts || this == CardSuit.diamonds;
  String get symbol {
    switch (this) {
      case CardSuit.hearts: return '♥️';
      case CardSuit.diamonds: return '♦️';
      case CardSuit.clubs: return '♣️';
      case CardSuit.spades: return '♠️';
    }
  }
}

class PlayingCard {
  final CardSuit suit;
  final int value; // 1 (Ace) à 13 (King)
  bool isFaceUp;

  PlayingCard({
    required this.suit,
    required this.value,
    this.isFaceUp = false,
  });

  PlayingCard copy() => PlayingCard(suit: suit, value: value, isFaceUp: isFaceUp);

  String get label {
    switch (value) {
      case 1: return 'A';
      case 11: return 'J';
      case 12: return 'Q';
      case 13: return 'K';
      default: return '$value';
    }
  }
}

class SolitaireSnapshot {
  final List<PlayingCard> stock;
  final List<PlayingCard> waste;
  final List<List<PlayingCard>> foundations;
  final List<List<PlayingCard>> tableau;
  final int moves;
  final int score;

  SolitaireSnapshot({
    required this.stock,
    required this.waste,
    required this.foundations,
    required this.tableau,
    required this.moves,
    required this.score,
  });

  static SolitaireSnapshot from(SolitaireEngine engine) {
    return SolitaireSnapshot(
      stock: engine.stock.map((c) => c.copy()).toList(),
      waste: engine.waste.map((c) => c.copy()).toList(),
      foundations: engine.foundations.map((pile) => pile.map((c) => c.copy()).toList()).toList(),
      tableau: engine.tableau.map((col) => col.map((c) => c.copy()).toList()).toList(),
      moves: engine.moves,
      score: engine.score,
    );
  }
}

class SolitaireEngine {
  final List<PlayingCard> stock = [];
  final List<PlayingCard> waste = [];
  final List<List<PlayingCard>> foundations = List.generate(4, (_) => []);
  final List<List<PlayingCard>> tableau = List.generate(7, (_) => []);
  final List<SolitaireSnapshot> _undoStack = [];

  bool drawThreeMode = false;
  int moves = 0;
  int score = 0;

  bool get canUndo => _undoStack.isNotEmpty;

  void saveStateForUndo() {
    _undoStack.add(SolitaireSnapshot.from(this));
    if (_undoStack.length > 30) {
      _undoStack.removeAt(0);
    }
  }

  bool undo() {
    if (!canUndo) return false;
    final snap = _undoStack.removeLast();
    stock.clear();
    stock.addAll(snap.stock);
    waste.clear();
    waste.addAll(snap.waste);

    for (int i = 0; i < 4; i++) {
      foundations[i].clear();
      foundations[i].addAll(snap.foundations[i]);
    }

    for (int i = 0; i < 7; i++) {
      tableau[i].clear();
      tableau[i].addAll(snap.tableau[i]);
    }

    moves = snap.moves;
    score = snap.score;
    return true;
  }

  void dealNewGame() {
    _undoStack.clear();
    stock.clear();
    waste.clear();
    for (var f in foundations) {
      f.clear();
    }
    for (var t in tableau) {
      t.clear();
    }
    moves = 0;
    score = 0;

    // Créer les 52 cartes
    final deck = <PlayingCard>[];
    for (final suit in CardSuit.values) {
      for (int v = 1; v <= 13; v++) {
        deck.add(PlayingCard(suit: suit, value: v, isFaceUp: false));
      }
    }
    deck.shuffle(math.Random());

    // Distribuer le tableau (colonnes 0 à 6)
    for (int col = 0; col < 7; col++) {
      for (int count = 0; count <= col; count++) {
        final card = deck.removeLast();
        if (count == col) {
          card.isFaceUp = true;
        }
        tableau[col].add(card);
      }
    }

    // Le reste va dans la pioche (stock)
    stock.addAll(deck);
  }

  void drawCard() {
    saveStateForUndo();
    moves++;
    if (stock.isEmpty) {
      // Recycler le talon
      while (waste.isNotEmpty) {
        final c = waste.removeLast();
        c.isFaceUp = false;
        stock.add(c);
      }
    } else {
      final countToDraw = drawThreeMode ? math.min(3, stock.length) : 1;
      for (int i = 0; i < countToDraw; i++) {
        final c = stock.removeLast();
        c.isFaceUp = true;
        waste.add(c);
      }
    }
  }

  bool isGameWon() {
    for (final f in foundations) {
      if (f.length < 13) return false;
    }
    return true;
  }

  bool canAutoComplete() {
    // Toutes les cartes du tableau sont-elles visibles ?
    for (final col in tableau) {
      if (col.any((c) => !c.isFaceUp)) return false;
    }
    return stock.isEmpty && waste.isEmpty;
  }

  bool stepAutoComplete() {
    for (final col in tableau) {
      if (col.isNotEmpty) {
        final card = col.last;
        for (int i = 0; i < 4; i++) {
          if (canMoveToFoundation(card, i)) {
            col.removeLast();
            foundations[i].add(card);
            score += 15;
            moves++;
            return true;
          }
        }
      }
    }
    return false;
  }

  bool canMoveToFoundation(PlayingCard card, int foundationIndex) {
    final pile = foundations[foundationIndex];
    if (pile.isEmpty) {
      return card.value == 1; // Uniquement As
    }
    final top = pile.last;
    return top.suit == card.suit && card.value == top.value + 1;
  }

  bool canMoveToTableau(PlayingCard card, int tableauIndex) {
    final pile = tableau[tableauIndex];
    if (pile.isEmpty) {
      return card.value == 13; // Uniquement Roi
    }
    final top = pile.last;
    if (!top.isFaceUp) return false;
    return top.suit.isRed != card.suit.isRed && top.value == card.value + 1;
  }

  PlayingCard? findHint() {
    // 1. Chercher un mouvement vers fondation depuis waste
    if (waste.isNotEmpty) {
      for (int i = 0; i < 4; i++) {
        if (canMoveToFoundation(waste.last, i)) return waste.last;
      }
    }
    // 2. Chercher mouvement vers fondation depuis tableau
    for (final col in tableau) {
      if (col.isNotEmpty) {
        for (int i = 0; i < 4; i++) {
          if (canMoveToFoundation(col.last, i)) return col.last;
        }
      }
    }
    // 3. Chercher mouvement tableau vers tableau
    for (final sourceCol in tableau) {
      for (final card in sourceCol.where((c) => c.isFaceUp)) {
        for (int targetIdx = 0; targetIdx < 7; targetIdx++) {
          if (canMoveToTableau(card, targetIdx)) {
            // Vérifier que ce n'est pas déjà posé sur un slot inutile
            final srcIdx = sourceCol.indexOf(card);
            if (srcIdx > 0 && !sourceCol[srcIdx - 1].isFaceUp) {
              return card;
            }
          }
        }
      }
    }
    return null;
  }

  bool tryAutoMove(PlayingCard card) {
    saveStateForUndo();

    // 1. Essayer vers les fondations
    for (int i = 0; i < 4; i++) {
      if (canMoveToFoundation(card, i)) {
        if (_removeCardFromSources(card)) {
          foundations[i].add(card);
          score += 15;
          moves++;
          _flipTopTableauCards();
          return true;
        }
      }
    }

    // 2. Essayer vers le tableau
    for (int i = 0; i < 7; i++) {
      if (canMoveToTableau(card, i)) {
        final cardsToMove = _extractCardsFromSources(card);
        if (cardsToMove.isNotEmpty) {
          tableau[i].addAll(cardsToMove);
          score += 5;
          moves++;
          _flipTopTableauCards();
          return true;
        }
      }
    }

    // Si aucun mouvement, supprimer le snapshot créé
    _undoStack.removeLast();
    return false;
  }

  bool _removeCardFromSources(PlayingCard card) {
    if (waste.isNotEmpty && waste.last == card) {
      waste.removeLast();
      return true;
    }
    for (var col in tableau) {
      if (col.isNotEmpty && col.last == card) {
        col.removeLast();
        return true;
      }
    }
    return false;
  }

  List<PlayingCard> _extractCardsFromSources(PlayingCard card) {
    if (waste.isNotEmpty && waste.last == card) {
      waste.removeLast();
      return [card];
    }
    for (var col in tableau) {
      final idx = col.indexOf(card);
      if (idx != -1 && card.isFaceUp) {
        final moving = col.sublist(idx);
        col.removeRange(idx, col.length);
        return moving;
      }
    }
    return [];
  }

  void _flipTopTableauCards() {
    for (var col in tableau) {
      if (col.isNotEmpty && !col.last.isFaceUp) {
        col.last.isFaceUp = true;
        score += 5;
      }
    }
  }
}
