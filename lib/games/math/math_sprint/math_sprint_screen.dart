import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';

class MathQuestion {
  final String questionText;
  final int correctAnswer;
  final List<int> options;

  MathQuestion({
    required this.questionText,
    required this.correctAnswer,
    required this.options,
  });

  static MathQuestion generate(int level) {
    final rnd = math.Random();
    int opType = rnd.nextInt(3); // 0: +, 1: -, 2: *
    if (level > 4) opType = rnd.nextInt(4); // inclut /

    int a = 0;
    int b = 0;
    int answer = 0;
    String qText = '';

    switch (opType) {
      case 0: // +
        a = rnd.nextInt(15 + level * 5) + 2;
        b = rnd.nextInt(15 + level * 5) + 2;
        answer = a + b;
        qText = '$a + $b = ?';
        break;
      case 1: // -
        a = rnd.nextInt(25 + level * 5) + 10;
        b = rnd.nextInt(a - 1) + 1;
        answer = a - b;
        qText = '$a - $b = ?';
        break;
      case 2: // *
        a = rnd.nextInt(9 + level) + 2;
        b = rnd.nextInt(9 + level) + 2;
        answer = a * b;
        qText = '$a × $b = ?';
        break;
      case 3: // /
      default:
        b = rnd.nextInt(9) + 2;
        answer = rnd.nextInt(12) + 2;
        a = b * answer;
        qText = '$a ÷ $b = ?';
        break;
    }

    Set<int> opts = {answer};
    while (opts.length < 4) {
      int delta = (rnd.nextInt(5) + 1) * (rnd.nextBool() ? 1 : -1);
      int fake = answer + delta;
      if (fake >= 0 && fake != answer) opts.add(fake);
    }
    List<int> optList = opts.toList()..shuffle();

    return MathQuestion(
      questionText: qText,
      correctAnswer: answer,
      options: optList,
    );
  }
}

class MathSprintScreen extends StatefulWidget {
  const MathSprintScreen({super.key});

  @override
  State<MathSprintScreen> createState() => _MathSprintScreenState();
}

class _MathSprintScreenState extends State<MathSprintScreen> {
  int _score = 0;
  int _streak = 0;
  int _level = 1;
  int _timeLeft = 40;
  Timer? _timer;
  late MathQuestion _currentQuestion;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    _score = 0;
    _streak = 0;
    _level = 1;
    _timeLeft = 40;
    _isGameOver = false;
    _currentQuestion = MathQuestion.generate(_level);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        setState(() => _isGameOver = true);
        FeedbackService.triggerImpact();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onAnswerSelected(int ans) {
    if (_isGameOver) return;

    if (ans == _currentQuestion.correctAnswer) {
      _streak++;
      _score += (100 * (1 + _streak ~/ 3));
      StorageService.saveMathHighScore(_score);
      if (_streak % 5 == 0) _level++;
      _timeLeft = math.min(50, _timeLeft + 2); // Bonus de 2 secondes
      FeedbackService.triggerSuccess();
    } else {
      _streak = 0;
      _timeLeft = math.max(0, _timeLeft - 3); // Pénalité de 3 secondes
      FeedbackService.triggerImpact();
    }

    setState(() {
      _currentQuestion = MathQuestion.generate(_level);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF11182B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'MATH SPRINT ⚡',
          style: TextStyle(
            color: Color(0xFF00FFCC),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Bandeau Score, Streak, Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFF11182B),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_score PTS', style: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.w900, fontSize: 18)),
                      Text('Série : x$_streak', style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Color(0xFFFF2A6D), size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '$_timeLeft s',
                        style: TextStyle(
                          color: _timeLeft < 10 ? Colors.redAccent : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Carte de la question mathématique
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D36),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FFCC).withValues(alpha: 0.2),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Text(
                  _currentQuestion.questionText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                  ),
                ),
              ),
            ),

            const Spacer(),

            // 4 Choix de réponses
            Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: _currentQuestion.options.map((opt) {
                  return ElevatedButton(
                    onPressed: () => _onAnswerSelected(opt),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2744),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.white12),
                      ),
                    ),
                    child: Text(
                      '$opt',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF00FFCC),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Modal Fin de partie
            if (_isGameOver)
              Container(
                color: Colors.black.withValues(alpha: 0.85),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D36),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF00FFCC), width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, color: Color(0xFF00FFCC), size: 50),
                        const SizedBox(height: 12),
                        const Text('TEMPS ÉCOULÉ !', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text('Score Final : $_score PTS', style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => setState(_startNewGame),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFCC)),
                          child: const Text('REJOUER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

