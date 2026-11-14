import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'football_models.dart';
import 'football_match_screen.dart';
import '../../../services/storage_service.dart';

class LeagueClubStats {
  final FootballTeam team;
  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  int points = 0;

  LeagueClubStats({required this.team});

  int get goalDiff => goalsFor - goalsAgainst;
}

class FootballLeagueScreen extends StatefulWidget {
  const FootballLeagueScreen({super.key});

  @override
  State<FootballLeagueScreen> createState() => _FootballLeagueScreenState();
}

class _FootballLeagueScreenState extends State<FootballLeagueScreen> {
  final List<FootballTeam> _allTeams = FootballTeam.getPresetTeams();
  late List<LeagueClubStats> _standings;
  int _currentMatchday = 1;
  final int _totalMatchdays = 10;
  late FootballTeam _userTeam;

  @override
  void initState() {
    super.initState();
    _userTeam = _allTeams.first; // Madrid Royals par défaut
    _initStandings();
  }

  void _initStandings() {
    _standings = _allTeams.map((t) => LeagueClubStats(team: t)).toList();

    // Initialisation d'un historique simulé réaliste pour donner de la vie au championnat
    final rnd = math.Random(42);
    for (int i = 0; i < _standings.length; i++) {
      final s = _standings[i];
      s.played = 4;
      if (i == 0) {
        s.won = 3;
        s.drawn = 1;
        s.lost = 0;
        s.goalsFor = 9;
        s.goalsAgainst = 2;
        s.points = 10;
      } else if (i == 1) {
        s.won = 3;
        s.drawn = 0;
        s.lost = 1;
        s.goalsFor = 8;
        s.goalsAgainst = 4;
        s.points = 9;
      } else {
        s.won = rnd.nextInt(3);
        s.drawn = rnd.nextInt(2);
        s.lost = s.played - (s.won + s.drawn);
        s.goalsFor = s.won * 2 + s.drawn;
        s.goalsAgainst = s.lost * 2 + 1;
        s.points = s.won * 3 + s.drawn;
      }
    }
    _sortStandings();
    _currentMatchday = 5;
  }

  void _sortStandings() {
    _standings.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      if (b.goalDiff != a.goalDiff) return b.goalDiff.compareTo(a.goalDiff);
      return b.goalsFor.compareTo(a.goalsFor);
    });
  }

  void _playNextMatch() {
    FeedbackService.triggerImpact();
    // Trouve l'adversaire de la journée
    final opponents = _allTeams.where((t) => t.id != _userTeam.id).toList();
    final opponent = opponents[(_currentMatchday - 1) % opponents.length];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FootballMatchScreen(
          teamA: _userTeam,
          teamB: opponent,
        ),
      ),
    ).then((_) {
      // Met à jour la journée après le match
      setState(() {
        if (_currentMatchday < _totalMatchdays) {
          _currentMatchday++;
          // Simule un résultat positif pour le joueur
          final userStats = _standings.firstWhere((s) => s.team.id == _userTeam.id);
          userStats.played++;
          userStats.won++;
          userStats.goalsFor += 2;
          userStats.goalsAgainst += 1;
          userStats.points += 3;
          _sortStandings();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final userRank = _standings.indexWhere((s) => s.team.id == _userTeam.id) + 1;

    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'LIGUE DES CHAMPIONS PRO',
          style: TextStyle(
            color: Color(0xFF00FFCC),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bannière de votre club dans la ligue
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1B36), Color(0xFF142B54), Color(0xFF070D1E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00FFCC).withValues(alpha: 0.15), blurRadius: 16),
                ],
              ),
              child: Row(
                children: [
                  Text(_userTeam.emblem, style: const TextStyle(fontSize: 44)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_userTeam.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          'Classement actuel : ${userRank}e place • Journée $_currentMatchday / $_totalMatchdays',
                          style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const Text('Objectif de saison : Décrocher le titre de Champion', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tableau de Classement (Standings Table)
            const Text(
              'CLASSEMENT GÉNÉRAL DE LA LIGUE',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF101626),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  // En-tête du tableau
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const SizedBox(width: 24, child: Text('#', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                        const Expanded(child: Text('CLUB', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                        _buildTableHeaderCell('MJ'),
                        _buildTableHeaderCell('V'),
                        _buildTableHeaderCell('N'),
                        _buildTableHeaderCell('D'),
                        _buildTableHeaderCell('DIFF'),
                        _buildTableHeaderCell('PTS', isHighlight: true),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  // Lignes du tableau
                  ...List.generate(_standings.length, (idx) {
                    final s = _standings[idx];
                    final isUser = s.team.id == _userTeam.id;
                    final isLeader = idx == 0;

                    return Container(
                      color: isUser ? const Color(0xFF00FFCC).withValues(alpha: 0.1) : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                color: isLeader ? const Color(0xFFFFD166) : (isUser ? const Color(0xFF00FFCC) : Colors.white70),
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Text(s.team.emblem, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    s.team.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isUser ? const Color(0xFF00FFCC) : Colors.white,
                                      fontWeight: isUser ? FontWeight.w900 : FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildTableCell('${s.played}'),
                          _buildTableCell('${s.won}'),
                          _buildTableCell('${s.drawn}'),
                          _buildTableCell('${s.lost}'),
                          _buildTableCell('${s.goalDiff > 0 ? '+${s.goalDiff}' : s.goalDiff}'),
                          _buildTableCell('${s.points}', isHighlight: true),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bouton Jouer le Match de Championnat
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFCC),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 6,
              ),
              onPressed: _playNextMatch,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_soccer, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'DISPUTER LA JOURNÉE $_currentMatchday',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, {bool isHighlight = false}) {
    return SizedBox(
      width: 28,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isHighlight ? const Color(0xFF00FFCC) : Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHighlight = false}) {
    return SizedBox(
      width: 28,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isHighlight ? const Color(0xFF00FFCC) : Colors.white70,
          fontSize: 11,
          fontWeight: isHighlight ? FontWeight.w900 : FontWeight.normal,
        ),
      ),
    );
  }
}
