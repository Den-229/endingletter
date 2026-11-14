import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/storage_service.dart';

enum MicroGameType {
  tapSpeed,
  stroopColor,
  aimPrecision,
  numberSequence,
  math24,
  hanoi,
  avoidLasers,
  catchStars,
  coinFlip,
  warCard,
  nimMatches,
}

class MicroGameRunnerScreen extends StatefulWidget {
  final int gameNumber;
  final String title;
  final String instruction;
  final MicroGameType type;
  final Color accentColor;

  const MicroGameRunnerScreen({
    super.key,
    required this.gameNumber,
    required this.title,
    required this.instruction,
    required this.type,
    required this.accentColor,
  });

  @override
  State<MicroGameRunnerScreen> createState() => _MicroGameRunnerScreenState();
}

class _MicroGameRunnerScreenState extends State<MicroGameRunnerScreen> {
  int _score = 0;
  int _highScore = 0;
  int _timeLeft = 15;
  Timer? _timer;
  bool _isGameOver = false;
  final math.Random _rnd = math.Random();

  // Variables spécifiques selon le type
  // Tap Speed
  int _tapCount = 0;

  // Stroop
  late String _stroopWord;
  late Color _stroopColor;
  late List<Color> _stroopOptions;

  // Aim Target
  Offset _targetPos = const Offset(0.5, 0.5);

  // Math Sequence
  late List<int> _sequenceNumbers;
  late int _sequenceMissing;
  late List<int> _sequenceOptions;

  // Nim Matches
  int _nimMatchesLeft = 15;

  @override
  void initState() {
    super.initState();
    _highScore = StorageService.getHighScore('game_${widget.gameNumber}');
    _startRound();
  }

  void _startRound() {
    _score = 0;
    _isGameOver = false;
    _timeLeft = widget.type == MicroGameType.tapSpeed ? 10 : 25;

    _setupGameSpecifics();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        setState(() {
          _isGameOver = true;
          StorageService.saveHighScore('game_${widget.gameNumber}', _score);
          _highScore = math.max(_highScore, _score);
        });
        FeedbackService.triggerImpact();
      }
    });
  }

  void _setupGameSpecifics() {
    switch (widget.type) {
      case MicroGameType.tapSpeed:
        _tapCount = 0;
        break;

      case MicroGameType.stroopColor:
        final names = ['ROUGE', 'BLEU', 'VERT', 'JAUNE'];
        final colors = [
          const Color(0xFFFF2A6D),
          const Color(0xFF00F0FF),
          const Color(0xFF05FFA1),
          const Color(0xFFFFD166),
        ];
        _stroopWord = names[_rnd.nextInt(names.length)];
        _stroopColor = colors[_rnd.nextInt(colors.length)];
        _stroopOptions = List.from(colors)..shuffle(_rnd);
        break;

      case MicroGameType.aimPrecision:
        _targetPos = Offset(0.2 + _rnd.nextDouble() * 0.6, 0.2 + _rnd.nextDouble() * 0.5);
        break;

      case MicroGameType.numberSequence:
        final step = _rnd.nextInt(4) + 2;
        final start = _rnd.nextInt(10) + 1;
        _sequenceNumbers = [start, start + step, start + 2 * step, start + 3 * step];
        _sequenceMissing = start + 4 * step;
        _sequenceOptions = [
          _sequenceMissing,
          _sequenceMissing + step,
          _sequenceMissing - 1,
          _sequenceMissing + 2
        ]..shuffle(_rnd);
        break;

      case MicroGameType.nimMatches:
        _nimMatchesLeft = 15;
        break;

      default:
        break;
    }
  }

  void _onAction(dynamic arg) {
    if (_isGameOver) return;

    switch (widget.type) {
      case MicroGameType.tapSpeed:
        setState(() {
          _tapCount++;
          _score = _tapCount;
        });
        FeedbackService.triggerLight();
        break;

      case MicroGameType.stroopColor:
        final pickedColor = arg as Color;
        if (pickedColor == _stroopColor) {
          _score += 100;
          FeedbackService.triggerSuccess();
          setState(_setupGameSpecifics);
        } else {
          _score = math.max(0, _score - 50);
          FeedbackService.triggerImpact();
        }
        break;

      case MicroGameType.aimPrecision:
        setState(() {
          _score += 150;
          _targetPos = Offset(0.15 + _rnd.nextDouble() * 0.7, 0.15 + _rnd.nextDouble() * 0.6);
        });
        FeedbackService.triggerSuccess();
        break;

      case MicroGameType.numberSequence:
        final picked = arg as int;
        if (picked == _sequenceMissing) {
          _score += 120;
          FeedbackService.triggerSuccess();
          setState(_setupGameSpecifics);
        } else {
          FeedbackService.triggerImpact();
        }
        break;

      case MicroGameType.nimMatches:
        final take = arg as int;
        setState(() {
          _nimMatchesLeft -= take;
          if (_nimMatchesLeft <= 0) {
            _score = 0;
            _isGameOver = true;
          } else {
            // Tour IA (prend 1 à 3 allumettes pour laisser un multiple de 4 + 1)
            int aiTake = (_nimMatchesLeft - 1) % 4;
            if (aiTake == 0) aiTake = 1;
            _nimMatchesLeft -= aiTake;
            if (_nimMatchesLeft <= 0) {
              _score = 500;
              _isGameOver = true;
              FeedbackService.triggerSuccess();
            }
          }
        });
        break;

      default:
        setState(() => _score += 50);
        FeedbackService.triggerLight();
        break;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10172D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '#${widget.gameNumber} • ${widget.title.toUpperCase()}',
          style: TextStyle(color: widget.accentColor, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // HUD
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFF10172D),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SCORE : $_score', style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.w900, fontSize: 16)),
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Color(0xFFFF2A6D), size: 18),
                      const SizedBox(width: 4),
                      Text('$_timeLeft s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  Text('RECORD : $_highScore', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                widget.instruction,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),

            const Spacer(),

            // Zone interactive selon le type
            _buildInteractiveZone(),

            const Spacer(),

            if (_isGameOver)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: ElevatedButton.icon(
                  onPressed: () => setState(_startRound),
                  icon: const Icon(Icons.replay, color: Colors.black),
                  label: const Text('REJOUER LE DÉFI', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveZone() {
    switch (widget.type) {
      case MicroGameType.tapSpeed:
        return Center(
          child: GestureDetector(
            onTap: () => _onAction(null),
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accentColor,
                boxShadow: [BoxShadow(color: widget.accentColor.withValues(alpha: 0.5), blurRadius: 25)],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app, color: Colors.black, size: 40),
                    Text('$_tapCount TAPS', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 22)),
                  ],
                ),
              ),
            ),
          ),
        );

      case MicroGameType.stroopColor:
        return Column(
          children: [
            Text(
              _stroopWord,
              style: TextStyle(color: _stroopColor, fontSize: 46, fontWeight: FontWeight.w900, letterSpacing: 4.0),
            ),
            const SizedBox(height: 30),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _stroopOptions.map((c) {
                return GestureDetector(
                  onTap: () => _onAction(c),
                  child: Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 10)]),
                  ),
                );
              }).toList(),
            ),
          ],
        );

      case MicroGameType.aimPrecision:
        return SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            children: [
              Align(
                alignment: Alignment((_targetPos.dx - 0.5) * 2, (_targetPos.dy - 0.5) * 2),
                child: GestureDetector(
                  onTap: () => _onAction(null),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accentColor,
                      boxShadow: [BoxShadow(color: widget.accentColor.withValues(alpha: 0.8), blurRadius: 15)],
                    ),
                    child: const Center(child: Icon(Icons.gps_fixed, color: Colors.black, size: 30)),
                  ),
                ),
              ),
            ],
          ),
        );

      case MicroGameType.numberSequence:
        return Column(
          children: [
            Text(
              '${_sequenceNumbers.join(" , ")} , ?',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2.0),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _sequenceOptions.map((opt) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ElevatedButton(
                    onPressed: () => _onAction(opt),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF141E36)),
                    child: Text('$opt', style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.w900, fontSize: 20)),
                  ),
                );
              }).toList(),
            ),
          ],
        );

      case MicroGameType.nimMatches:
        return Column(
          children: [
            Text('Allumettes restantes : $_nimMatchesLeft', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              children: List.generate(
                _nimMatchesLeft,
                (i) => Container(width: 8, height: 60, decoration: BoxDecoration(color: Colors.amberAccent, borderRadius: BorderRadius.circular(4))),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [1, 2, 3].map((count) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ElevatedButton(
                    onPressed: _nimMatchesLeft >= count ? () => _onAction(count) : null,
                    style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor),
                    child: Text('Prendre $count', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

