import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'football_models.dart';
import '../../../services/storage_service.dart';

class FootballEngine {
  final FootballTeam teamA;
  final FootballTeam teamB;

  Offset ballPos = const Offset(0.50, 0.50);
  Offset ballVelocity = Offset.zero;
  double ballHeight = 0.0;
  double ballVerticalVelocity = 0.0;

  FootballPlayer? ballCarrier;
  FootballPlayer activePlayerA;
  FootballPlayer activePlayerB;

  int scoreA = 0;
  int scoreB = 0;
  int matchMinutes = 0;
  double matchSecondsAcc = 0.0;
  bool isMatchPaused = false;
  MatchState state = MatchState.ready;

  // Statistiques du match (façon PES)
  int shotsA = 0;
  int shotsB = 0;
  int shotsOnTargetA = 0;
  int shotsOnTargetB = 0;
  double possessionSecondsA = 1.0;
  double possessionSecondsB = 1.0;

  bool isSprintingA = false;
  Offset joystickA = Offset.zero;

  // Callback événements
  VoidCallback? onGoal;
  VoidCallback? onHalfTime;
  VoidCallback? onFullTime;

  FootballEngine({
    required this.teamA,
    required this.teamB,
  })  : activePlayerA = teamA.players.firstWhere((p) => p.role == PlayerRole.mid),
        activePlayerB = teamB.players.firstWhere((p) => p.role == PlayerRole.mid) {
    resetKickoff(teamAServing: true);
  }

  void resetKickoff({required bool teamAServing}) {
    ballPos = const Offset(0.50, 0.50);
    ballVelocity = Offset.zero;
    ballHeight = 0.0;
    ballVerticalVelocity = 0.0;
    ballCarrier = null;

    for (final p in teamA.players) {
      p.pos = p.homePos;
      p.isControlled = false;
      p.isSliding = false;
    }
    for (final p in teamB.players) {
      p.pos = p.homePos;
      p.isControlled = false;
      p.isSliding = false;
    }

    if (teamAServing) {
      final fwd = teamA.players.firstWhere((p) => p.role == PlayerRole.fwd);
      fwd.pos = const Offset(0.49, 0.50);
      activePlayerA = fwd;
      ballCarrier = fwd;
    } else {
      final fwd = teamB.players.firstWhere((p) => p.role == PlayerRole.fwd);
      fwd.pos = const Offset(0.51, 0.50);
      activePlayerB = fwd;
      ballCarrier = fwd;
    }

    activePlayerA.isControlled = true;
    activePlayerB.isControlled = true;
    state = MatchState.playing;
  }

  void update(double dt) {
    if (isMatchPaused || state == MatchState.goalScored || state == MatchState.fullTime) {
      return;
    }

    // 1. Horloge de match (90 minutes en ~3 minutes)
    matchSecondsAcc += dt * 30.0;
    if (matchSecondsAcc >= 60.0) {
      matchMinutes += 1;
      matchSecondsAcc -= 60.0;

      if (matchMinutes == 45 && state != MatchState.halfTime) {
        state = MatchState.halfTime;
        onHalfTime?.call();
      } else if (matchMinutes >= 90) {
        state = MatchState.fullTime;
        onFullTime?.call();
      }
    }

    // 2. Gestion de la possession pour les stats
    if (ballCarrier != null) {
      if (teamA.players.contains(ballCarrier)) {
        possessionSecondsA += dt;
      } else {
        possessionSecondsB += dt;
      }
    }

    // 3. Physique du ballon en l'air et au sol
    if (ballHeight > 0.0 || ballVerticalVelocity > 0.0) {
      ballVerticalVelocity -= 9.8 * dt * 0.3;
      ballHeight += ballVerticalVelocity * dt;
      if (ballHeight <= 0.0) {
        ballHeight = 0.0;
        ballVerticalVelocity = -ballVerticalVelocity * 0.4;
        if (ballVerticalVelocity.abs() < 0.2) ballVerticalVelocity = 0.0;
      }
    }

    // 4. Mouvement du joueur contrôlé par l'utilisateur (Team A)
    double speedMultiplier = isSprintingA ? 0.28 : 0.18;
    if (joystickA != Offset.zero) {
      final moveDelta = joystickA * (speedMultiplier * dt);
      activePlayerA.pos = Offset(
        (activePlayerA.pos.dx + moveDelta.dx).clamp(0.04, 0.96),
        (activePlayerA.pos.dy + moveDelta.dy).clamp(0.05, 0.95),
      );
      activePlayerA.facingAngle = math.atan2(joystickA.dy, joystickA.dx);
      activePlayerA.animTime += dt * (isSprintingA ? 16.0 : 10.0);
    } else {
      final toBall = ballPos - activePlayerA.pos;
      if (toBall.distance > 0.01) {
        activePlayerA.facingAngle = math.atan2(toBall.dy, toBall.dx);
      }
    }

    // 5. Mise à jour de la balle avec le porteur ou libre
    if (ballCarrier != null) {
      // La balle colle aux pieds du joueur
      Offset dribbleOffset = const Offset(0.02, 0.0);
      if (ballCarrier == activePlayerA && joystickA != Offset.zero) {
        dribbleOffset = joystickA * 0.025;
      } else if (teamB.players.contains(ballCarrier)) {
        dribbleOffset = const Offset(-0.02, 0.0);
      }
      ballPos = ballCarrier!.pos + dribbleOffset;
      ballVelocity = Offset.zero;
      ballHeight = 0.0;
    } else {
      // Balle libre en déplacement cinématique
      ballPos += ballVelocity * dt;
      ballVelocity *= math.max(0.0, 1.0 - 1.2 * dt); // Friction de la pelouse

      // Limites du terrain et rebonds
      if (ballPos.dy <= 0.05) {
        ballPos = Offset(ballPos.dx, 0.05);
        ballVelocity = Offset(ballVelocity.dx, -ballVelocity.dy * 0.6);
      } else if (ballPos.dy >= 0.95) {
        ballPos = Offset(ballPos.dx, 0.95);
        ballVelocity = Offset(ballVelocity.dx, -ballVelocity.dy * 0.6);
      }

      // But adverse (Team A marque chez Team B à droite : x >= 0.97)
      if (ballPos.dx >= 0.97 && ballPos.dy >= 0.40 && ballPos.dy <= 0.60) {
        scoreA++;
        state = MatchState.goalScored;
        FeedbackService.triggerSuccess();
        onGoal?.call();
        return;
      }
      // But adverse (Team B marque chez Team A à gauche : x <= 0.03)
      if (ballPos.dx <= 0.03 && ballPos.dy >= 0.40 && ballPos.dy <= 0.60) {
        scoreB++;
        state = MatchState.goalScored;
        FeedbackService.triggerImpact();
        onGoal?.call();
        return;
      }

      // Rebond ligne de but hors cadre
      if (ballPos.dx < 0.03) {
        ballPos = Offset(0.03, ballPos.dy);
        ballVelocity = Offset(-ballVelocity.dx * 0.6, ballVelocity.dy);
      } else if (ballPos.dx > 0.97) {
        ballPos = Offset(0.97, ballPos.dy);
        ballVelocity = Offset(-ballVelocity.dx * 0.6, ballVelocity.dy);
      }
    }

    // 6. IA des coéquipiers Team A (Repli tactique & soutien)
    _updateTeamAITeammates(teamA, isTeamA: true, dt: dt);

    // 7. IA complète de l'adversaire Team B (Attaque, Défense, Tirs, Passes, Gardien)
    _updateTeamBFullAI(dt);

    // 8. Détection automatique de prise de balle si libre
    if (ballCarrier == null && ballHeight < 0.2) {
      _checkBallInterception();
    }
  }

  void _updateTeamAITeammates(FootballTeam team, {required bool isTeamA, required double dt}) {
    for (final player in team.players) {
      if (player == activePlayerA) continue; // Joueur contrôlé manuellement

      // Gardien de but IA
      if (player.role == PlayerRole.gk) {
        // Suit la trajectoire Y du ballon dans sa surface
        final targetY = ballPos.dy.clamp(0.42, 0.58);
        final dy = targetY - player.pos.dy;
        player.pos = Offset(player.homePos.dx, player.pos.dy + dy * (1.8 * dt));
        continue;
      }

      // Comportement tactique selon la position du ballon
      Offset desiredPos = player.homePos;
      if (ballPos.dx > 0.5) {
        // En attaque, monter d'un cran
        desiredPos = Offset(player.homePos.dx + 0.12, player.homePos.dy);
      } else {
        // En défense, reculer d'un cran
        desiredPos = Offset(player.homePos.dx - 0.08, player.homePos.dy);
      }

      final diff = desiredPos - player.pos;
      if (diff.distance > 0.02) {
        final dir = diff / diff.distance;
        player.pos += dir * (0.12 * dt);
        player.facingAngle = math.atan2(dir.dy, dir.dx);
        player.animTime += dt * 10.0;
      } else {
        final toBall = ballPos - player.pos;
        if (toBall.distance > 0.01) {
          player.facingAngle = math.atan2(toBall.dy, toBall.dx);
        }
      }
    }
  }

  void _updateTeamBFullAI(double dt) {
    // 1. Sélection du joueur Team B actif le plus proche du ballon
    FootballPlayer? closestB;
    double minB = 999.0;
    for (final p in teamB.players) {
      if (p.role == PlayerRole.gk) continue;
      final dist = (p.pos - ballPos).distance;
      if (dist < minB) {
        minB = dist;
        closestB = p;
      }
    }
    if (closestB != null) {
      activePlayerB.isControlled = false;
      activePlayerB = closestB;
      activePlayerB.isControlled = true;
    }

    // 2. Logique du joueur Team B contrôlé
    if (ballCarrier != null && teamB.players.contains(ballCarrier)) {
      // Team B A LA BALLE -> Attaque vers la gauche (but Team A à x=0.03)
      final carrier = ballCarrier!;
      final dirToGoal = (const Offset(0.05, 0.50) - carrier.pos);
      final distToGoal = dirToGoal.distance;

      // Si à portée de tir (< 0.38 de distance) -> TIR ADVERSE
      if (carrier.pos.dx < 0.38 && carrier.pos.dy > 0.25 && carrier.pos.dy < 0.75) {
        shootBallAI(isTeamA: false);
      } else {
        // Dribble vers le but adverse
        final step = (dirToGoal / distToGoal) * (0.16 * dt);
        carrier.pos = Offset(
          (carrier.pos.dx + step.dx).clamp(0.04, 0.96),
          (carrier.pos.dy + step.dy).clamp(0.05, 0.95),
        );
        carrier.facingAngle = math.atan2(dirToGoal.dy, dirToGoal.dx);
        carrier.animTime += dt * 11.0;

        // Opportunité de passe à un coéquipier démarqué
        if (math.Random().nextDouble() < 0.008) {
          passBallAI(isTeamA: false);
        }
      }
    } else {
      // Team B N'A PAS LA BALLE -> Pressing vers le ballon
      final diff = ballPos - activePlayerB.pos;
      if (diff.distance > 0.02) {
        final dir = diff / diff.distance;
        activePlayerB.pos += dir * (0.18 * dt);
        activePlayerB.facingAngle = math.atan2(dir.dy, dir.dx);
        activePlayerB.animTime += dt * 12.0;
      }
    }

    // 3. Gardien Team B
    final gkB = teamB.players.firstWhere((p) => p.role == PlayerRole.gk);
    final targetGkY = ballPos.dy.clamp(0.42, 0.58);
    final dyGk = targetGkY - gkB.pos.dy;
    gkB.pos = Offset(gkB.homePos.dx, gkB.pos.dy + dyGk * (1.8 * dt));

    // 4. Repli tactique des autres joueurs Team B
    for (final p in teamB.players) {
      if (p == activePlayerB || p.role == PlayerRole.gk) continue;
      final diff = p.homePos - p.pos;
      if (diff.distance > 0.03) {
        final dir = diff / diff.distance;
        p.pos += dir * (0.10 * dt);
      }
    }
  }

  void _checkBallInterception() {
    // Vérifie si un joueur de l'une ou l'autre équipe intercepte le ballon
    for (final p in [...teamA.players, ...teamB.players]) {
      if ((p.pos - ballPos).distance < 0.045) {
        ballCarrier = p;
        if (teamA.players.contains(p)) {
          activePlayerA.isControlled = false;
          activePlayerA = p;
          activePlayerA.isControlled = true;
        }
        FeedbackService.triggerSelection();
        break;
      }
    }
  }

  // --- ACTIONS DU JOUEUR PRINCIPAL (TEAM A) ---

  void passBall() {
    if (ballCarrier == null || !teamA.players.contains(ballCarrier)) return;

    // Cherche le meilleur coéquipier libre dans la direction du joystick ou vers l'avant
    FootballPlayer? targetTeammate;
    double bestScore = -999.0;

    final lookDir = joystickA != Offset.zero ? joystickA : const Offset(1.0, 0.0);

    for (final mate in teamA.players) {
      if (mate == ballCarrier || mate.role == PlayerRole.gk) continue;

      final toMate = mate.pos - ballCarrier!.pos;
      final dist = toMate.distance;
      if (dist < 0.05) continue;

      final normalizedToMate = toMate / dist;
      final alignment = normalizedToMate.dx * lookDir.dx + normalizedToMate.dy * lookDir.dy;

      // Score combinant proximité et bon angle de passe
      final score = alignment * 2.0 - (dist * 1.5);
      if (score > bestScore) {
        bestScore = score;
        targetTeammate = mate;
      }
    }

    Offset passDir = const Offset(1.0, 0.0);
    if (targetTeammate != null) {
      passDir = (targetTeammate.pos - ballCarrier!.pos);
      passDir = passDir / passDir.distance;
      activePlayerA.isControlled = false;
      activePlayerA = targetTeammate;
      activePlayerA.isControlled = true;
    } else if (joystickA != Offset.zero) {
      passDir = joystickA;
    }

    ballCarrier = null;
    ballVelocity = passDir * 0.70;
    FeedbackService.triggerImpact();
  }

  void shootBall(double powerFraction) {
    if (ballCarrier == null || !teamA.players.contains(ballCarrier)) return;

    shotsA++;
    final clampedPower = powerFraction.clamp(0.4, 1.0);
    final goalTarget = Offset(1.0, 0.45 + (math.Random().nextDouble() * 0.10));
    var shootDir = (goalTarget - ballCarrier!.pos);
    shootDir = shootDir / shootDir.distance;

    // Si le tir est cadré
    if (shootDir.dx > 0) {
      shotsOnTargetA++;
    }

    ballCarrier = null;
    ballVelocity = shootDir * (0.95 * clampedPower);
    ballVerticalVelocity = 2.0 * clampedPower;
    ballHeight = 0.05;

    FeedbackService.triggerImpact();
  }

  void tackleBall() {
    if (activePlayerA.isSliding) return;

    activePlayerA.isSliding = true;
    final tackleDir = joystickA != Offset.zero ? joystickA : const Offset(1.0, 0.0);
    activePlayerA.pos += tackleDir * 0.06;

    // Si l'adversaire a la balle et est proche, tacle réussi !
    if (ballCarrier != null && teamB.players.contains(ballCarrier)) {
      if ((ballCarrier!.pos - activePlayerA.pos).distance < 0.07) {
        ballCarrier = activePlayerA;
        FeedbackService.triggerSuccess();
      }
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      activePlayerA.isSliding = false;
    });
  }

  void switchActivePlayer() {
    // Passe au joueur Team A le plus proche du ballon (hors gardien)
    FootballPlayer? best;
    double minDist = 999.0;
    for (final p in teamA.players) {
      if (p.role == PlayerRole.gk || p == activePlayerA) continue;
      final dist = (p.pos - ballPos).distance;
      if (dist < minDist) {
        minDist = dist;
        best = p;
      }
    }
    if (best != null) {
      activePlayerA.isControlled = false;
      activePlayerA = best;
      activePlayerA.isControlled = true;
      FeedbackService.triggerSelection();
    }
  }

  // --- ACTIONS IA TEAM B ---

  void passBallAI({required bool isTeamA}) {
    if (ballCarrier == null) return;
    final team = isTeamA ? teamA : teamB;
    final mates = team.players.where((p) => p != ballCarrier && p.role != PlayerRole.gk).toList();
    if (mates.isEmpty) return;

    final mate = mates[math.Random().nextInt(mates.length)];
    var passDir = (mate.pos - ballCarrier!.pos);
    if (passDir.distance > 0.01) {
      passDir = passDir / passDir.distance;
      ballCarrier = null;
      ballVelocity = passDir * 0.65;
    }
  }

  void shootBallAI({required bool isTeamA}) {
    if (ballCarrier == null) return;
    shotsB++;
    final goalPos = isTeamA ? const Offset(1.0, 0.50) : const Offset(0.0, 0.50);
    var shootDir = (goalPos - ballCarrier!.pos);
    shootDir = shootDir / shootDir.distance;

    shotsOnTargetB++;
    ballCarrier = null;
    ballVelocity = shootDir * 0.85;
    ballVerticalVelocity = 1.8;
    ballHeight = 0.05;
  }
}
