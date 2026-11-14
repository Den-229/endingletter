import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../games/multiverse/game_catalog_100.dart';

class GameDetailSheet extends StatefulWidget {
  final CatalogGame game;
  final VoidCallback onPlay;

  const GameDetailSheet({
    super.key,
    required this.game,
    required this.onPlay,
  });

  static void show(BuildContext context, CatalogGame game, VoidCallback onPlay) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GameDetailSheet(game: game, onPlay: onPlay),
    );
  }

  @override
  State<GameDetailSheet> createState() => _GameDetailSheetState();
}

class _GameDetailSheetState extends State<GameDetailSheet> {
  late bool _isFavorite;
  String _difficulty = 'Normal';

  @override
  void initState() {
    super.initState();
    _isFavorite = StorageService.isFavorite(widget.game.id);
  }

  void _toggleFavorite() async {
    final newStatus = await StorageService.toggleFavorite(widget.game.id);
    FeedbackService.triggerSelection();
    setState(() {
      _isFavorite = newStatus;
    });
  }

  String _getCategoryName(CatalogCategory cat) {
    switch (cat) {
      case CatalogCategory.cards: return 'Cartes & Hasard';
      case CatalogCategory.board: return 'Jeux de Plateau';
      case CatalogCategory.logic: return 'Logique & Réflexion';
      case CatalogCategory.math: return 'Calcul & Mathématiques';
      case CatalogCategory.arcade: return 'Arcade & Action 3D';
      case CatalogCategory.reflex: return 'Vitesse & Réflexes';
      case CatalogCategory.sports: return 'Sports & Simulation';
      case CatalogCategory.all: return 'Multiverse';
    }
  }

  String _getDetailedRules(int gameId) {
    switch (gameId) {
      case 1:
        return 'Posez une carte de même couleur ou même chiffre. Utilisez les cartes d\'action (+2, Inversion, Passer, Joker +4) pour piéger vos rivaux et criez UNO avant de poser votre dernière carte !';
      case 2:
        return 'Atteignez 21 sans jamais dépasser ! Les têtes valent 10, l\'As vaut 1 ou 11. Battez la main du croupier pour doubler votre mise.';
      case 3:
        return 'Mattez le roi adverse ! Déplacez pions, cavaliers, fous, tours et dame avec précision. Le système calcule votre avantage matériel en direct.';
      case 4:
        return 'Déplacez vos pions en diagonale sur les cases sombres. Sautez par-dessus les pions adverses pour les capturer et atteignez la dernière rangée pour devenir Dame !';
      case 5:
        return 'Alignez 4 jetons de votre couleur à l\'horizontale, verticale ou diagonale avant votre adversaire. Anticipez les blocages !';
      case 6:
        return 'Faites le tour complet du plateau 15x15 avec vos 4 pions et amenez-les au centre. Faites un 6 sur le dé pour sortir de votre nid de départ !';
      case 8:
        return 'Glissez les tuiles pour fusionner les nombres identiques (2+2=4, 4+4=8...) et tentez de créer la légendaire tuile 2048 !';
      case 9:
        return 'Explorez le champ de mines sans faire exploser les charges. Les chiffres vous indiquent le nombre exact de bombes dans les 8 cases adjacentes.';
      case 27:
        return 'Reconstituez les 4 familles de l\'As au Roi sur les fondations. Dans les 7 colonnes, alternez les couleurs rouge et noir en ordre décroissant.';
      case 28:
        return 'Maîtrisez la conduite réaliste : tournez le volant, passez les vitesses PRND, dosez l\'accélérateur et garez-vous au millimètre sans toucher les obstacles. En mode Nitro, esquivez le trafic à 200 km/h !';
      case 29:
        return 'Enchaînez les mots anglais : chaque mot proposé doit impérativement commencer par la dernière lettre du mot précédent avant la fin du chrono de 15 secondes !';
      case 30:
        return 'PES Football : Dirigez votre joueur avec le joystick virtuel, réalisez des passes millimétrées, chargez vos tirs au but, taclez les attaquants adverses et remportez le championnat !';
      default:
        return 'Relevez le défi du Multiverse ! Suivez les consignes tactiles, réagissez le plus vite possible et battez votre record personnel pour accumuler de l\'XP.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1529),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black87, blurRadius: 30, spreadRadius: 10),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Poignée du Modal
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // En-tête : Badge, Numéro, Favori
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: game.accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: game.accentColor),
                    ),
                    child: Text(
                      'JEU #${game.id}',
                      style: TextStyle(
                        color: game.accentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getCategoryName(game.category),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.star : Icons.star_border,
                  color: _isFavorite ? const Color(0xFFFFD166) : Colors.white38,
                  size: 28,
                ),
                tooltip: _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                onPressed: _toggleFavorite,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Titre & Sous-titre
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [game.accentColor, game.accentColor.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: game.accentColor.withValues(alpha: 0.4), blurRadius: 14),
                  ],
                ),
                child: Icon(game.icon, color: Colors.black, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      game.subtitle,
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Fiche Règles & Stratégie
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF16203D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.menu_book, color: Color(0xFF00FFCC), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'RÈGLES ET OBJECTIF',
                      style: TextStyle(
                        color: Color(0xFF00FFCC),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getDetailedRules(game.id),
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Sélecteur de difficulté
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Difficulté :',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Row(
                children: ['Débutant', 'Normal', 'Maître'].map((d) {
                  final isSelected = _difficulty == d;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(d, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      selectedColor: game.accentColor,
                      backgroundColor: const Color(0xFF16203D),
                      onSelected: (_) => setState(() => _difficulty = d),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Bouton Grand Lancement
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              StorageService.addRecentGame(game.id);
              widget.onPlay();
            },
            icon: const Icon(Icons.play_circle_fill, color: Colors.black, size: 26),
            label: const Text(
              'LANCER LA PARTIE',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: game.accentColor,
              elevation: 8,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
