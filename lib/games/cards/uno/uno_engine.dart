import 'dart:math' as math;
import 'package:flutter/material.dart';

enum UnoColor { red, blue, green, yellow, wild }

enum UnoType {
  num0, num1, num2, num3, num4, num5, num6, num7, num8, num9,
  skip, reverse, draw2, wild, wildDraw4
}

class UnoCard {
  final UnoColor color;
  final UnoType type;

  UnoCard({required this.color, required this.type});

  bool get isWild => color == UnoColor.wild || type == UnoType.wild || type == UnoType.wildDraw4;

  String get label {
    switch (type) {
      case UnoType.num0: return '0';
      case UnoType.num1: return '1';
      case UnoType.num2: return '2';
      case UnoType.num3: return '3';
      case UnoType.num4: return '4';
      case UnoType.num5: return '5';
      case UnoType.num6: return '6';
      case UnoType.num7: return '7';
      case UnoType.num8: return '8';
      case UnoType.num9: return '9';
      case UnoType.skip: return '⊘';
      case UnoType.reverse: return '⇄';
      case UnoType.draw2: return '+2';
      case UnoType.wild: return '★';
      case UnoType.wildDraw4: return '+4';
    }
  }

  Color get displayColor {
    switch (color) {
      case UnoColor.red: return const Color(0xFFFF2A6D);
      case UnoColor.blue: return const Color(0xFF00F0FF);
      case UnoColor.green: return const Color(0xFF05FFA1);
      case UnoColor.yellow: return const Color(0xFFFFD166);
      case UnoColor.wild: return const Color(0xFFE056FD);
    }
  }
}

class UnoGame {
  final List<UnoCard> deck = [];
  final List<UnoCard> discardPile = [];
  final List<UnoCard> playerHand = [];
  final List<UnoCard> aiHand = [];

  UnoColor activeColor = UnoColor.red;
  bool isPlayerTurn = true;
  final math.Random _rnd = math.Random();

  UnoGame() {
    reset();
  }

  void reset() {
    deck.clear();
    discardPile.clear();
    playerHand.clear();
    aiHand.clear();
    isPlayerTurn = true;

    // Génération du paquet UNO
    final standardColors = [UnoColor.red, UnoColor.blue, UnoColor.green, UnoColor.yellow];

    for (final col in standardColors) {
      deck.add(UnoCard(color: col, type: UnoType.num0));
      for (final t in [
        UnoType.num1, UnoType.num2, UnoType.num3, UnoType.num4,
        UnoType.num5, UnoType.num6, UnoType.num7, UnoType.num8, UnoType.num9,
        UnoType.skip, UnoType.reverse, UnoType.draw2,
      ]) {
        deck.add(UnoCard(color: col, type: t));
        deck.add(UnoCard(color: col, type: t));
      }
    }

    // Jokers
    for (int i = 0; i < 4; i++) {
      deck.add(UnoCard(color: UnoColor.wild, type: UnoType.wild));
      deck.add(UnoCard(color: UnoColor.wild, type: UnoType.wildDraw4));
    }

    deck.shuffle(_rnd);

    // Distribution : 7 cartes chacun
    for (int i = 0; i < 7; i++) {
      playerHand.add(deck.removeLast());
      aiHand.add(deck.removeLast());
    }

    // Première carte de la défausse (non-joker pour commencer proprement)
    UnoCard firstCard = deck.removeLast();
    while (firstCard.isWild) {
      deck.insert(0, firstCard);
      firstCard = deck.removeLast();
    }
    discardPile.add(firstCard);
    activeColor = firstCard.color;
  }

  UnoCard get topCard => discardPile.last;

  bool canPlay(UnoCard card) {
    if (card.isWild) return true;
    if (card.color == activeColor) return true;
    if (card.type == topCard.type) return true;
    return false;
  }

  UnoCard? drawCard({required bool forPlayer}) {
    if (deck.isEmpty) {
      if (discardPile.length <= 1) return null;
      final top = discardPile.removeLast();
      deck.addAll(discardPile);
      deck.shuffle(_rnd);
      discardPile.clear();
      discardPile.add(top);
    }

    final card = deck.removeLast();
    if (forPlayer) {
      playerHand.add(card);
    } else {
      aiHand.add(card);
    }
    return card;
  }

  bool playCard({
    required UnoCard card,
    required bool isPlayer,
    UnoColor? chosenColorForWild,
  }) {
    if (!canPlay(card)) return false;

    final hand = isPlayer ? playerHand : aiHand;
    hand.remove(card);
    discardPile.add(card);

    if (card.isWild) {
      activeColor = chosenColorForWild ?? UnoColor.red;
    } else {
      activeColor = card.color;
    }

    // Gestion des effets spéciaux
    switch (card.type) {
      case UnoType.draw2:
        for (int i = 0; i < 2; i++) {
          drawCard(forPlayer: !isPlayer);
        }
        break; // Saute le tour de la victime
      case UnoType.wildDraw4:
        for (int i = 0; i < 4; i++) {
          drawCard(forPlayer: !isPlayer);
        }
        break; // Saute le tour de la victime
      case UnoType.skip:
        break; // Saute le tour de la victime
      case UnoType.reverse:
        break; // En 1v1, reverse agit comme un Skip
      default:
        isPlayerTurn = !isPlayerTurn;
        return true;
    }

    // Si la carte saute le tour adverse, le joueur rejoue !
    return true;
  }
}

