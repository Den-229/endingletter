import 'package:flutter/material.dart';

class InnovationLabScreen extends StatelessWidget {
  const InnovationLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'LABORATOIRE D’INNOVATION MOBILE',
          style: TextStyle(
            color: Color(0xFF00FFCC),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 24),
          _buildSectionTitle('1. LES LEVIERS D’INNOVATION MOBILE EN 2026'),
          const SizedBox(height: 12),
          _buildPillarCard(
            icon: Icons.touch_app,
            color: const Color(0xFF00F0FF),
            title: 'Contrôles "Gesture-First" & Spatiaux',
            desc:
                'Oubliez les manettes virtuelles rigides. Les jeux innovants tirent parti du swipe directionnel, de l’inertie tactile fluide et de l’accéléromètre pour fusionner le joueur avec l’action.',
          ),
          _buildPillarCard(
            icon: Icons.vibration,
            color: const Color(0xFFFF007F),
            title: 'Feedback Haptique Synesthésique',
            desc:
                'Chaque explosion, changement de gravité ou frôlement de laser renvoie une vibration texturée. Le joueur "ressent" la physique du jeu au bout des doigts.',
          ),
          _buildPillarCard(
            icon: Icons.hourglass_top,
            color: const Color(0xFFE056FD),
            title: 'Mécanique de Dilatation Temporelle',
            desc:
                'Intégrer le "Bullet-Time" permet de concilier la vitesse intense sur petit écran et la précision tactique sans frustrer le joueur.',
          ),
          _buildPillarCard(
            icon: Icons.auto_awesome,
            color: const Color(0xFFFFD166),
            title: 'Micro-Sessions Intenses & Rejouabilité',
            desc:
                'Des sessions de 45 secondes à 3 minutes avec génération procédurale d’obstacles, assurant une rétention élevée sans dépendre de mécaniques pay-to-win.',
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('2. POURQUOI FLUTTER POUR LES JEUX MOBILES ?'),
          const SizedBox(height: 12),
          _buildComparisonTable(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1147), Color(0xFF0C2461)],
        ),
        border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFCC).withValues(alpha: 0.2),
            blurRadius: 20,
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rocket_launch, color: Color(0xFF00FFCC), size: 28),
              SizedBox(width: 12),
              Text(
                'VISION DU GAME DESIGN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Innover dans le jeu mobile ne consiste pas à copier les consoles, mais à inventer des mécaniques qui exploitent les super-pouvoirs du smartphone : fluidité 120 FPS, écran tactile réactif, physique immédiate et immersion sensorielle.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF00FFCC),
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildPillarCard({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11172E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11172E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: const Column(
        children: [
          _CompareRow(feature: 'Poids du binaire', flutterVal: '15-25 Mo (Instantané)', unityVal: '80-150 Mo'),
          Divider(color: Colors.white10),
          _CompareRow(feature: 'Temps de lancement', flutterVal: '< 0.8 seconde', unityVal: '3-8 secondes'),
          Divider(color: Colors.white10),
          _CompareRow(feature: 'UI & Menus', flutterVal: 'Natif réactif ultra-net', unityVal: 'Complexe à styliser'),
          Divider(color: Colors.white10),
          _CompareRow(feature: 'Hot Reload Code', flutterVal: 'Instantané (< 500ms)', unityVal: 'Compilation lente'),
          Divider(color: Colors.white10),
          _CompareRow(feature: 'Rendu CustomPainter', flutterVal: '120 FPS pur GPU Skia/Impeller', unityVal: 'Overhead moteur'),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String feature;
  final String flutterVal;
  final String unityVal;

  const _CompareRow({
    required this.feature,
    required this.flutterVal,
    required this.unityVal,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(feature, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(flutterVal, style: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 12)),
              Text('vs Unity: $unityVal', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
