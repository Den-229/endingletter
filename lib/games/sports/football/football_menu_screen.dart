import 'package:flutter/material.dart';
import 'football_models.dart';
import 'football_match_screen.dart';
import 'football_league_screen.dart';
import 'football_training_screen.dart';

class FootballMenuScreen extends StatefulWidget {
  const FootballMenuScreen({super.key});

  @override
  State<FootballMenuScreen> createState() => _FootballMenuScreenState();
}

class _FootballMenuScreenState extends State<FootballMenuScreen> {
  final List<FootballTeam> _allTeams = FootballTeam.getPresetTeams();
  late FootballTeam _selectedTeamA;
  late FootballTeam _selectedTeamB;

  String _formation = '4-3-3';
  MatchTactic _tactic = MatchTactic.balanced;

  @override
  void initState() {
    super.initState();
    _selectedTeamA = _allTeams[0]; // Madrid Royals
    _selectedTeamB = _allTeams[1]; // Paris Lumière
  }

  void _startMatch() {
    _selectedTeamA.formation = _formation;
    _selectedTeamA.tactic = _tactic;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FootballMatchScreen(
          teamA: _selectedTeamA,
          teamB: _selectedTeamB,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'PES PRO STRIKER 2026',
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Banner PES Style
            Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E1A33), Color(0xFF1B4D3E), Color(0xFF052B1E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00FFCC).withValues(alpha: 0.2), blurRadius: 18),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0055),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('PRO EDITION', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'COUP D\'ENVOI',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const Text(
                          'Simulateur tactique & physique réaliste',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Text('⚽', style: TextStyle(fontSize: 54)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Duel d'Équipes
            const Text('SÉLECTION DU DUEL', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildTeamCard(
                    title: 'ÉQUIPE DOMICILE (1P)',
                    team: _selectedTeamA,
                    onTap: () => _openTeamPicker(isTeamA: true),
                    borderColor: const Color(0xFF00FFCC),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('VS', style: TextStyle(color: Colors.white30, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                Expanded(
                  child: _buildTeamCard(
                    title: 'ÉQUIPE VISITEUR (IA)',
                    team: _selectedTeamB,
                    onTap: () => _openTeamPicker(isTeamA: false),
                    borderColor: const Color(0xFFFF0055),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Plan de Jeu & Stratégie Tactique
            const Text('TACTIQUE & FORMATION', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF101626),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Formation de base :', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      DropdownButton<String>(
                        value: _formation,
                        dropdownColor: const Color(0xFF161E34),
                        style: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold),
                        underline: const SizedBox(),
                        items: ['4-3-3', '4-4-2', '3-5-2', '4-2-3-1'].map((f) {
                          return DropdownMenuItem(value: f, child: Text(f));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _formation = val);
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mentalité du bloc :', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      SegmentedButton<MatchTactic>(
                        segments: const [
                          ButtonSegment(value: MatchTactic.defensive, label: Text('Déf', style: TextStyle(fontSize: 10))),
                          ButtonSegment(value: MatchTactic.balanced, label: Text('Équi', style: TextStyle(fontSize: 10))),
                          ButtonSegment(value: MatchTactic.offensive, label: Text('Att', style: TextStyle(fontSize: 10))),
                        ],
                        selected: {_tactic},
                        onSelectionChanged: (val) {
                          setState(() => _tactic = val.first);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bouton Coup d'Envoi
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFCC),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 6,
              ),
              onPressed: _startMatch,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_soccer, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'LANCER LE MATCH',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00FFCC),
                      side: const BorderSide(color: Color(0xFF00FFCC), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FootballLeagueScreen()));
                    },
                    icon: const Icon(Icons.emoji_events, size: 18),
                    label: const Text('CHAMPIONNAT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFD166),
                      side: const BorderSide(color: Color(0xFFFFD166), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FootballTrainingScreen()));
                    },
                    icon: const Icon(Icons.gps_fixed, size: 18),
                    label: const Text('TIRS AU BUT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard({
    required String title,
    required FootballTeam team,
    required VoidCallback onTap,
    required Color borderColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF101626),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(team.emblem, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 6),
            Text(team.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatPill('ATT', team.attackRating),
                const SizedBox(width: 4),
                _buildStatPill('MIL', team.midfieldRating),
                const SizedBox(width: 4),
                _buildStatPill('DEF', team.defenseRating),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, int val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$label $val', style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  void _openTeamPicker({required bool isTeamA}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1524),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allTeams.length,
        itemBuilder: (_, idx) {
          final t = _allTeams[idx];
          return ListTile(
            leading: Text(t.emblem, style: const TextStyle(fontSize: 28)),
            title: Text(t.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('ATT: ${t.attackRating} | MIL: ${t.midfieldRating} | DEF: ${t.defenseRating}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            onTap: () {
              setState(() {
                if (isTeamA) {
                  _selectedTeamA = t;
                } else {
                  _selectedTeamB = t;
                }
              });
              Navigator.pop(ctx);
            },
          );
        },
      ),
    );
  }
}
