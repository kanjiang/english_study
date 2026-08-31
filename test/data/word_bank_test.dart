import 'package:english_app/data/word_audio_player.dart';
import 'package:english_app/data/word_bank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('word bank has 48 words with 12 per category', () {
    expect(kWordBank, hasLength(48));

    for (final category in ['animals', 'food', 'colors', 'home']) {
      expect(kWordBank.where((word) => word.category == category), hasLength(12));
    }

    expect(kWordBank.map((word) => word.id).toSet(), hasLength(48));
    expect(
      kWordBank.map((word) => word.audioAsset).toSet(),
      {'assets/audio/beep.mp3'},
    );
  });

  test('silent audio player completes without doing anything', () async {
    final player = SilentWordAudioPlayer();

    await player.play('assets/audio/beep.mp3');
    await player.dispose();
  });
}
