import 'package:just_audio/just_audio.dart';

abstract class WordAudioPlayer {
  Future<void> play(String assetPath);

  Future<void> dispose();
}

class SilentWordAudioPlayer implements WordAudioPlayer {
  @override
  Future<void> play(String assetPath) async {}

  @override
  Future<void> dispose() async {}
}

class JustAudioWordPlayer implements WordAudioPlayer {
  JustAudioWordPlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(String assetPath) async {
    await _player.setAsset(assetPath);
    await _player.play();
  }

  @override
  Future<void> dispose() {
    return _player.dispose();
  }
}
