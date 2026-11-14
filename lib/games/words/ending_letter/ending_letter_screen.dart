import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/confetti_overlay.dart';
import 'ending_letter_dictionary.dart';

class PlayedWordEntry {
  final String word;
  final bool isPlayer;
  final int points;

  PlayedWordEntry({required this.word, required this.isPlayer, required this.points});
}

class EndingLetterScreen extends StatefulWidget {
  const EndingLetterScreen({super.key});

  @override
  State<EndingLetterScreen> createState() => _EndingLetterScreenState();
}

class _EndingLetterScreenState extends State<EndingLetterScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _chainScrollController = ScrollController();

  final List<PlayedWordEntry> _history = [];
  final Set<String> _usedWords = {};

  String _currentRequiredLetter = 'S';
  int _score = 0;
  int _combo = 0;
  int _turnTimeLeft = 15;
  Timer? _turnTimer;

  bool _isPlayerTurn = true;
  bool _isAiThinking = false;
  bool _isGameOver = false;
  bool _isWon = false;
  bool _vsAi = true;
  int _difficulty = 1; // 0: Rookie, 1: Scholar, 2: Master

  String _feedbackMessage = 'Entrez un mot anglais commençant par la lettre requise !';
  Color _feedbackColor = const Color(0xFF00FFCC);

  @override
  void initState() {
    super.initState();
    _startNewMatch();
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    _inputController.dispose();
    _focusNode.dispose();
    _chainScrollController.dispose();
    super.dispose();
  }

  void _startNewMatch() {
    _turnTimer?.cancel();
    _history.clear();
    _usedWords.clear();
    _score = 0;
    _combo = 0;
    _isGameOver = false;
    _isWon = false;
    _isPlayerTurn = true;
    _isAiThinking = false;

    // Lettre de départ aléatoire parmi des lettres courantes (S, T, C, B, P, R, M, D)
    const starterLetters = ['S', 'T', 'C', 'B', 'P', 'R', 'M', 'D', 'L', 'F', 'A', 'G'];
    _currentRequiredLetter = starterLetters[math.Random().nextInt(starterLetters.length)];

    _feedbackMessage = 'Le match commence ! Premier mot avec "$_currentRequiredLetter"';
    _feedbackColor = const Color(0xFF00FFCC);

    _resetTurnTimer();
    setState(() {});
  }

  void _resetTurnTimer() {
    _turnTimer?.cancel();
    _turnTimeLeft = 15;
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isGameOver) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_turnTimeLeft > 0) {
          _turnTimeLeft--;
        } else {
          // Temps écoulé !
          timer.cancel();
          _handleTimeOut();
        }
      });
    });
  }

  void _handleTimeOut() {
    FeedbackService.triggerImpact();
    setState(() {
      _isGameOver = true;
      if (_isPlayerTurn) {
        _isWon = false;
        _feedbackMessage = '⏰ Temps écoulé ! Vous avez perdu la manche.';
        _feedbackColor = const Color(0xFFFF0055);
      } else {
        _isWon = true;
        _feedbackMessage = '🏆 L\'adversaire n\'a pas trouvé à temps ! Vous gagnez !';
        _feedbackColor = const Color(0xFFFFD166);
        FeedbackService.triggerSuccess();
        StorageService.saveHighScore('ending_letter', _score);
      }
    });
  }

  void _submitWord() {
    if (_isGameOver || !_isPlayerTurn || _isAiThinking) return;

    final rawWord = _inputController.text.trim().toLowerCase();
    _inputController.clear();

    if (rawWord.isEmpty) return;

    // 1. Vérification première lettre
    if (!rawWord.startsWith(_currentRequiredLetter.toLowerCase())) {
      FeedbackService.triggerLight();
      setState(() {
        _feedbackMessage = '❌ Le mot doit commencer par la lettre "${_currentRequiredLetter.toUpperCase()}" !';
        _feedbackColor = const Color(0xFFFF0055);
      });
      return;
    }

    // 2. Vérification mot déjà utilisé
    if (_usedWords.contains(rawWord)) {
      FeedbackService.triggerLight();
      setState(() {
        _feedbackMessage = '⚠️ "$rawWord" a déjà été joué dans cette manche !';
        _feedbackColor = const Color(0xFFFF9F1C);
      });
      return;
    }

    // 3. Vérification dans le dictionnaire anglais
    if (!EndingLetterDictionary.isValidWord(rawWord)) {
      FeedbackService.triggerLight();
      setState(() {
        _feedbackMessage = '❌ "$rawWord" n\'est pas un mot anglais reconnu !';
        _feedbackColor = const Color(0xFFFF0055);
      });
      return;
    }

    // Mot valide accepté !
    FeedbackService.triggerImpact();
    final pointsEarned = rawWord.length * 10 + (_combo * 5) + _turnTimeLeft * 2;
    _usedWords.add(rawWord);
    _history.add(PlayedWordEntry(word: rawWord, isPlayer: true, points: pointsEarned));
    _score += pointsEarned;
    _combo++;

    // La nouvelle lettre requise est la dernière lettre du mot
    _currentRequiredLetter = rawWord.substring(rawWord.length - 1).toUpperCase();

    setState(() {
      _feedbackMessage = '✔ Excellent ! "$rawWord" (+${pointsEarned}pts). Prochaine lettre : "$_currentRequiredLetter"';
      _feedbackColor = const Color(0xFF00FFCC);
      _isPlayerTurn = false;
    });

    _scrollChainToEnd();

    if (_vsAi) {
      _triggerAiTurn();
    } else {
      _isPlayerTurn = true;
      _resetTurnTimer();
    }
  }

  void _triggerAiTurn() {
    _turnTimer?.cancel();
    setState(() => _isAiThinking = true);

    final thinkDuration = Duration(milliseconds: 900 + math.Random().nextInt(1400));
    Timer(thinkDuration, () {
      if (!mounted || _isGameOver) return;

      final aiWord = EndingLetterDictionary.findAiWord(
        _currentRequiredLetter.toLowerCase(),
        _usedWords,
        _difficulty,
      );

      if (aiWord == null) {
        // L'IA est coincée et ne trouve aucun mot !
        FeedbackService.triggerSuccess();
        setState(() {
          _isAiThinking = false;
          _isGameOver = true;
          _isWon = true;
          _feedbackMessage = '👑 Victoire ! L\'IA n\'a trouvé aucun mot avec "$_currentRequiredLetter" !';
          _feedbackColor = const Color(0xFFFFD166);
        });
        StorageService.saveHighScore('ending_letter', _score);
        return;
      }

      // L'IA joue son mot
      FeedbackService.triggerLight();
      _usedWords.add(aiWord);
      final points = aiWord.length * 8;
      _history.add(PlayedWordEntry(word: aiWord, isPlayer: false, points: points));
      _currentRequiredLetter = aiWord.substring(aiWord.length - 1).toUpperCase();

      setState(() {
        _isAiThinking = false;
        _isPlayerTurn = true;
        _feedbackMessage = 'L\'IA a répondu "$aiWord". À vous avec "$_currentRequiredLetter" !';
        _feedbackColor = Colors.white;
      });

      _scrollChainToEnd();
      _resetTurnTimer();
      _focusNode.requestFocus();
    });
  }

  void _scrollChainToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chainScrollController.hasClients) {
        _chainScrollController.animateTo(
          _chainScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConfettiOverlay(
      showCelebration: _isWon,
      title: 'VICTOIRE ENDING LETTER ! 🏆',
      subtitle: 'Score final : $_score pts • Maîtrise linguistique validée',
      child: Scaffold(
        backgroundColor: const Color(0xFF070B18),
        appBar: AppBar(
          backgroundColor: const Color(0xFF10172D),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Row(
            children: [
              Icon(Icons.spellcheck, color: Color(0xFF00FFCC), size: 22),
              SizedBox(width: 8),
              Text(
                'ENDING LETTER CHAIN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              tooltip: 'Recommencer',
              onPressed: _startNewMatch,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Bandeau Score, Chrono & Combo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF10172D),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars, color: Color(0xFFFFD166), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'SCORE : $_score',
                          style: const TextStyle(color: Color(0xFFFFD166), fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ],
                    ),
                    // Chronomètre bombe
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _turnTimeLeft <= 5 ? const Color(0xFFFF0055).withValues(alpha: 0.25) : Colors.black26,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _turnTimeLeft <= 5 ? const Color(0xFFFF0055) : const Color(0xFF00FFCC),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer,
                            size: 14,
                            color: _turnTimeLeft <= 5 ? const Color(0xFFFF0055) : const Color(0xFF00FFCC),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_turnTimeLeft s',
                            style: TextStyle(
                              color: _turnTimeLeft <= 5 ? const Color(0xFFFF0055) : const Color(0xFF00FFCC),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_combo > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9F1C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'COMBO x$_combo 🔥',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),

              // Sélecteur Mode & Difficulté
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: const Color(0xFF0C1326),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('vs IA', style: TextStyle(fontSize: 11)),
                          selected: _vsAi,
                          selectedColor: const Color(0xFF00FFCC),
                          labelStyle: TextStyle(color: _vsAi ? Colors.black : Colors.white70, fontWeight: FontWeight.bold),
                          onSelected: (val) => setState(() => _vsAi = true),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('2 Joueurs', style: TextStyle(fontSize: 11)),
                          selected: !_vsAi,
                          selectedColor: const Color(0xFF00FFCC),
                          labelStyle: TextStyle(color: !_vsAi ? Colors.black : Colors.white70, fontWeight: FontWeight.bold),
                          onSelected: (val) => setState(() => _vsAi = false),
                        ),
                      ],
                    ),
                    if (_vsAi)
                      DropdownButton<int>(
                        value: _difficulty,
                        dropdownColor: const Color(0xFF10172D),
                        underline: const SizedBox(),
                        style: const TextStyle(color: Color(0xFFFFD166), fontSize: 11, fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Niveau : Débutant')),
                          DropdownMenuItem(value: 1, child: Text('Niveau : Erudit')),
                          DropdownMenuItem(value: 2, child: Text('Niveau : Maître')),
                        ],
                        onChanged: (val) => setState(() => _difficulty = val ?? 1),
                      ),
                  ],
                ),
              ),

              // Cœur du jeu : Grande Lettre Cible Requis
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00FFCC).withValues(alpha: 0.15),
                      const Color(0xFF10172D),
                      const Color(0xFF0A0F21),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF00FFCC).withValues(alpha: 0.2), blurRadius: 20),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'PROCHAINE LETTRE OBLIGATOIRE',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00FFCC), Color(0xFF0099FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF00FFCC).withValues(alpha: 0.6), blurRadius: 16),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _currentRequiredLetter,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isAiThinking ? '🤖 L\'adversaire réfléchit à son mot...' : (_isPlayerTurn ? 'À vous de jouer un mot commençant par "$_currentRequiredLetter" !' : 'En attente...'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Chaîne visuelle des mots précédents (Word Chain)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C1326),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: _history.isEmpty
                      ? const Center(
                          child: Text(
                            'La chaîne de mots apparaîtra ici au fil des tours.',
                            style: TextStyle(color: Colors.white30, fontSize: 12),
                          ),
                        )
                      : ListView.separated(
                          controller: _chainScrollController,
                          itemCount: _history.length,
                          separatorBuilder: (context, index) => const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Icon(Icons.arrow_downward, color: Color(0xFF00FFCC), size: 16),
                            ),
                          ),
                          itemBuilder: (ctx, idx) {
                            final entry = _history[idx];
                            final firstLetter = entry.word.substring(0, 1).toUpperCase();
                            final middle = entry.word.substring(1, entry.word.length - 1);
                            final lastLetter = entry.word.substring(entry.word.length - 1).toUpperCase();

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: entry.isPlayer
                                    ? const Color(0xFF00FFCC).withValues(alpha: 0.12)
                                    : const Color(0xFFFF0055).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: entry.isPlayer ? const Color(0xFF00FFCC).withValues(alpha: 0.4) : const Color(0xFFFF0055).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        entry.isPlayer ? Icons.person : Icons.smart_toy,
                                        size: 16,
                                        color: entry.isPlayer ? const Color(0xFF00FFCC) : const Color(0xFFFF0055),
                                      ),
                                      const SizedBox(width: 8),
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: firstLetter,
                                              style: TextStyle(
                                                color: entry.isPlayer ? const Color(0xFF00FFCC) : const Color(0xFFFF0055),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                              ),
                                            ),
                                            TextSpan(
                                              text: middle,
                                              style: const TextStyle(color: Colors.white, fontSize: 15),
                                            ),
                                            TextSpan(
                                              text: lastLetter,
                                              style: const TextStyle(
                                                color: Color(0xFFFFD166),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '+${entry.points} pts',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),

              // Message d'alerte / Feedback
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  _feedbackMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _feedbackColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),

              // Champ de saisie et bouton Envoyer
              if (!_isGameOver)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF10172D),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.6), width: 1.5),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: TextField(
                            controller: _inputController,
                            focusNode: _focusNode,
                            enabled: _isPlayerTurn && !_isAiThinking,
                            textCapitalization: TextCapitalization.none,
                            autocorrect: false,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'Mot en "$_currentRequiredLetter"... (ex: ${_currentRequiredLetter.toLowerCase()}...)',
                              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _submitWord(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: (_isPlayerTurn && !_isAiThinking) ? _submitWord : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FFCC),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Icon(Icons.send, size: 20),
                      ),
                    ],
                  ),
                ),

              if (_isGameOver)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  child: ElevatedButton.icon(
                    onPressed: _startNewMatch,
                    icon: const Icon(Icons.replay, color: Colors.black),
                    label: const Text('NOUVELLE MANCHE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFCC),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
