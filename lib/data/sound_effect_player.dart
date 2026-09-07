import 'package:just_audio/just_audio.dart';

abstract class SoundEffectPlayer {
  Future<void> play(String assetPath);

  Future<void> dispose();
}

class SilentSoundEffectPlayer implements SoundEffectPlayer {
  @override
  Future<void> play(String assetPath) async {}

  @override
  Future<void> dispose() async {}
}

class JustAudioSoundEffectPlayer implements SoundEffectPlayer {
  JustAudioSoundEffectPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(String assetPath) async {
    await _player.setAsset(assetPath);
    await _player.play();
  }

  @override
  Future<void> dispose() => _player.dispose();
}
