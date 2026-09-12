import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Petit service de sons. Best-effort : si l'asset manque, on ne crash pas
/// (utile en tests et avant que l'APK final ne soit packagé).
///
/// Tous les effets sont volontairement courts (< 500 ms) pour rester
/// réactifs même sur des appareils modestes.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _player = AudioPlayer(playerId: 'endingletter_sfx');
  bool muted = false;

  Future<void> _play(String asset) async {
    if (muted) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ sound $asset failed: $e');
    }
  }

  Future<void> playSubmit() => _play('sounds/submit.wav');
  Future<void> playError() => _play('sounds/error.wav');
  Future<void> playWin() => _play('sounds/win.wav');
}