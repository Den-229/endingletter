import 'dart:math' as math;
import 'package:flutter/material.dart';

enum PlayerRole { gk, def, mid, fwd }
enum MatchState { ready, playing, goalScored, halfTime, fullTime }
enum MatchTactic { offensive, balanced, defensive }

class FootballPlayer {
  final int id;
  final String name;
  final int number;
  final PlayerRole role;
  Offset pos; // Position relative sur le terrain (0.0 à 1.0)
  Offset homePos; // Position tactique de base
  double speed;
  double shotPower;
  double defense;
  bool isControlled;
  bool isSliding;
  double slideTime;
  double facingAngle;
  double animTime;
  final Color skinTone;
  final Color hairColor;
  final String? avatarAsset;
  final int overallRating;
  final String celebration;

  FootballPlayer({
    required this.id,
    required this.name,
    required this.number,
    required this.role,
    required this.pos,
    required this.homePos,
    this.speed = 1.0,
    this.shotPower = 1.0,
    this.defense = 1.0,
    this.isControlled = false,
    this.isSliding = false,
    this.slideTime = 0.0,
    this.facingAngle = 0.0,
    this.animTime = 0.0,
    this.skinTone = const Color(0xFFC68642),
    this.hairColor = const Color(0xFF1E140A),
    this.avatarAsset,
    this.overallRating = 85,
    this.celebration = 'Glissade sur les genoux',
  });
}

class FootballTeam {
  final String id;
  final String name;
  final String shortName;
  final Color primaryColor;
  final Color secondaryColor;
  final String emblem;
  final int attackRating;
  final int midfieldRating;
  final int defenseRating;
  String formation;
  MatchTactic tactic;
  List<FootballPlayer> players;

  FootballTeam({
    required this.id,
    required this.name,
    required this.shortName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.emblem,
    required this.attackRating,
    required this.midfieldRating,
    required this.defenseRating,
    this.formation = '4-3-3',
    this.tactic = MatchTactic.balanced,
    required this.players,
  });

  static List<FootballTeam> getPresetTeams() {
    return [
      FootballTeam(
        id: 'madrid_royals',
        name: 'Madrid Royals',
        shortName: 'RMA',
        primaryColor: const Color(0xFFFFFFFF),
        secondaryColor: const Color(0xFFC5A059),
        emblem: '👑',
        attackRating: 92,
        midfieldRating: 90,
        defenseRating: 89,
        players: _generateTeamSquad('Madrid Royals', isTeamA: true),
      ),
      FootballTeam(
        id: 'paris_luminaires',
        name: 'Paris Lumière',
        shortName: 'PAR',
        primaryColor: const Color(0xFF0C2340),
        secondaryColor: const Color(0xFFDA291C),
        emblem: '🗼',
        attackRating: 94,
        midfieldRating: 88,
        defenseRating: 87,
        players: _generateTeamSquad('Paris Lumière', isTeamA: false),
      ),
      FootballTeam(
        id: 'london_lions',
        name: 'London Lions',
        shortName: 'LDN',
        primaryColor: const Color(0xFFDC0714),
        secondaryColor: const Color(0xFFFFFFFF),
        emblem: '🦁',
        attackRating: 89,
        midfieldRating: 91,
        defenseRating: 90,
        players: _generateTeamSquad('London Lions', isTeamA: true),
      ),
      FootballTeam(
        id: 'milan_stars',
        name: 'Milan Stars',
        shortName: 'MIL',
        primaryColor: const Color(0xFFB30006),
        secondaryColor: const Color(0xFF111111),
        emblem: '⭐',
        attackRating: 88,
        midfieldRating: 88,
        defenseRating: 93,
        players: _generateTeamSquad('Milan Stars', isTeamA: false),
      ),
      FootballTeam(
        id: 'rio_samba',
        name: 'Rio Samba FC',
        shortName: 'RIO',
        primaryColor: const Color(0xFFFFDF00),
        secondaryColor: const Color(0xFF009C3B),
        emblem: '⚽',
        attackRating: 95,
        midfieldRating: 87,
        defenseRating: 84,
        players: _generateTeamSquad('Rio Samba FC', isTeamA: true),
      ),
      FootballTeam(
        id: 'tokyo_neo',
        name: 'Tokyo Neo FC',
        shortName: 'TKY',
        primaryColor: const Color(0xFF00F0FF),
        secondaryColor: const Color(0xFF1A1A2E),
        emblem: '⚡',
        attackRating: 87,
        midfieldRating: 90,
        defenseRating: 88,
        players: _generateTeamSquad('Tokyo Neo FC', isTeamA: false),
      ),
    ];
  }

  static List<FootballPlayer> _generateTeamSquad(String teamName, {required bool isTeamA}) {
    // 7 Joueurs par équipe sur terrain mobile optimisé (1 GK, 2 DEF, 2 MIL, 2 ATT)
    // Coordonnées X (0.0 gauche = but Équipe A, 1.0 droite = but Équipe B), Y (0.0 haut, 1.0 bas)
    if (isTeamA) {
      return [
        FootballPlayer(id: 1, name: 'Courtois', number: 1, role: PlayerRole.gk, pos: const Offset(0.06, 0.50), homePos: const Offset(0.06, 0.50), speed: 0.9, defense: 1.2, skinTone: const Color(0xFFF5D6B8), hairColor: const Color(0xFF3A2312)),
        FootballPlayer(id: 2, name: 'Militao', number: 3, role: PlayerRole.def, pos: const Offset(0.20, 0.30), homePos: const Offset(0.20, 0.30), defense: 1.1, skinTone: const Color(0xFF8D5524), hairColor: const Color(0xFF111111)),
        FootballPlayer(id: 3, name: 'Alaba', number: 4, role: PlayerRole.def, pos: const Offset(0.20, 0.70), homePos: const Offset(0.20, 0.70), defense: 1.1, skinTone: const Color(0xFF6A3B1B), hairColor: const Color(0xFF111111)),
        FootballPlayer(id: 4, name: 'Modric', number: 10, role: PlayerRole.mid, pos: const Offset(0.35, 0.35), homePos: const Offset(0.35, 0.35), speed: 1.05, shotPower: 1.05, skinTone: const Color(0xFFF8D7B0), hairColor: const Color(0xFF9E7835)),
        FootballPlayer(id: 5, name: 'Kroos', number: 8, role: PlayerRole.mid, pos: const Offset(0.35, 0.65), homePos: const Offset(0.35, 0.65), speed: 1.0, shotPower: 1.1, skinTone: const Color(0xFFFDE0C5), hairColor: const Color(0xFFCBB168)),
        FootballPlayer(id: 6, name: 'Vinicius', number: 7, role: PlayerRole.fwd, pos: const Offset(0.48, 0.35), homePos: const Offset(0.48, 0.35), speed: 1.25, shotPower: 1.15, skinTone: const Color(0xFF5A3010), hairColor: const Color(0xFF111111), avatarAsset: 'assets/images/players/madrid_star_3d.jpg', overallRating: 92, celebration: 'Samba Dance aux Poteaux'),
        FootballPlayer(id: 7, name: 'Benzema', number: 9, role: PlayerRole.fwd, pos: const Offset(0.48, 0.65), homePos: const Offset(0.48, 0.65), speed: 1.1, shotPower: 1.3, skinTone: const Color(0xFFD29F74), hairColor: const Color(0xFF2A1C14), overallRating: 90, celebration: 'Doigt vers le Ciel'),
      ];
    } else {
      return [
        FootballPlayer(id: 1, name: 'Donnarumma', number: 1, role: PlayerRole.gk, pos: const Offset(0.94, 0.50), homePos: const Offset(0.94, 0.50), speed: 0.9, defense: 1.2, skinTone: const Color(0xFFF3CFB0), hairColor: const Color(0xFF2E1C12), facingAngle: math.pi, overallRating: 89),
        FootballPlayer(id: 2, name: 'Marquinhos', number: 5, role: PlayerRole.def, pos: const Offset(0.80, 0.30), homePos: const Offset(0.80, 0.30), defense: 1.1, skinTone: const Color(0xFF7D4E24), hairColor: const Color(0xFF111111), facingAngle: math.pi, overallRating: 88),
        FootballPlayer(id: 3, name: 'Hakimi', number: 2, role: PlayerRole.def, pos: const Offset(0.80, 0.70), homePos: const Offset(0.80, 0.70), defense: 1.1, skinTone: const Color(0xFFB67B46), hairColor: const Color(0xFF111111), facingAngle: math.pi, overallRating: 87),
        FootballPlayer(id: 4, name: 'Verratti', number: 6, role: PlayerRole.mid, pos: const Offset(0.65, 0.35), homePos: const Offset(0.65, 0.35), speed: 1.0, shotPower: 1.0, skinTone: const Color(0xFFF5CFB0), hairColor: const Color(0xFF332015), facingAngle: math.pi, overallRating: 88),
        FootballPlayer(id: 5, name: 'Vitinha', number: 17, role: PlayerRole.mid, pos: const Offset(0.65, 0.65), homePos: const Offset(0.65, 0.65), speed: 1.05, shotPower: 1.05, skinTone: const Color(0xFFEAC49D), hairColor: const Color(0xFF462E1C), facingAngle: math.pi, overallRating: 86),
        FootballPlayer(id: 6, name: 'Mbappé', number: 10, role: PlayerRole.fwd, pos: const Offset(0.52, 0.35), homePos: const Offset(0.52, 0.35), speed: 1.3, shotPower: 1.25, skinTone: const Color(0xFF6F4320), hairColor: const Color(0xFF111111), facingAngle: math.pi, avatarAsset: 'assets/images/players/striker_mbappe_3d.jpg', overallRating: 94, celebration: 'Glissade Bras Croisés'),
        FootballPlayer(id: 7, name: 'Neymar', number: 11, role: PlayerRole.fwd, pos: const Offset(0.52, 0.65), homePos: const Offset(0.52, 0.65), speed: 1.15, shotPower: 1.2, skinTone: const Color(0xFF966336), hairColor: const Color(0xFF22160E), facingAngle: math.pi, overallRating: 91, celebration: 'Grimace & Danse'),
      ];
    }
  }
}
