/// Un mot joué dans une partie.
class PlayedWord {
  const PlayedWord({
    required this.word,
    required this.player,
    required this.playedAt,
  });

  final String word;
  final int player;
  final DateTime playedAt;

  Map<String, dynamic> toJson() => {
        'word': word,
        'player': player,
        'playedAt': playedAt.toUtc().toIso8601String(),
      };

  factory PlayedWord.fromJson(Map<String, dynamic> j) => PlayedWord(
        word: j['word'] as String,
        player: (j['player'] as num).toInt(),
        playedAt: DateTime.parse(j['playedAt'] as String),
      );

  @override
  String toString() => 'PlayedWord($word, P$player)';
}