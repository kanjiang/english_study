import 'package:english_app/app.dart';
import 'package:english_app/app/providers.dart';
import 'package:english_app/data/sound_effect_player.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:english_app/data/word_audio_player.dart';
import 'package:english_app/domain/quiz/word.dart';
import 'package:english_app/domain/shanghai_clock.dart';
import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/domain/wallet/wallet.dart';
import 'package:english_app/features/games/firefighter_page.dart';
import 'package:english_app/features/games/monster_page.dart';
import 'package:english_app/features/games/treasure_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../helpers/seed.dart';

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
  });

  testWidgets('treasure matching flushes earned coins and saves score', (
    tester,
  ) async {
    final repository = FakeUserRepository(_zeroCoinSeed());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(repository),
          wordBankProvider.overrideWithValue(_bank10()),
          wordAudioPlayerProvider.overrideWithValue(SilentWordAudioPlayer()),
        ],
        child: const MaterialApp(home: _PushedPage(child: TreasurePage())),
      ),
    );
    await tester.pumpAndSettle();

    final pairs = _treasurePairsByHiddenKeys();
    expect(pairs, hasLength(6));

    for (final indices in pairs.values) {
      await tester.tap(_cardFinder(indices.first));
      await tester.pump();
      await tester.tap(_cardFinder(indices.last));
      await tester.pumpAndSettle();
    }

    final snapshot = await repository.load();
    expect(find.text('返回首页'), findsOneWidget);
    expect(snapshot!.child.wallet.coins, greaterThan(0));
    expect(snapshot.gameStats.treasureLastScore, snapshot.child.wallet.coins);
  });

  testWidgets('treasure cards stay blank until flipped', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(_zeroCoinSeed()),
          ),
          wordBankProvider.overrideWithValue(_bank10()),
          wordAudioPlayerProvider.overrideWithValue(SilentWordAudioPlayer()),
        ],
        child: const MaterialApp(home: _PushedPage(child: TreasurePage())),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 12; i++) {
      expect(
        find.descendant(of: _cardFinder(i), matching: find.byType(Icon)),
        findsNothing,
      );
    }
    for (final word in _bank10()) {
      expect(find.text(word.en), findsNothing);
    }

    final firstPair = _treasurePairsByHiddenKeys().values.first;
    await tester.tap(_cardFinder(firstPair.first));
    await tester.pump();

    final revealedCard = _cardFinder(firstPair.first);
    final labels = tester
        .widgetList<Text>(
          find.descendant(of: revealedCard, matching: find.byType(Text)),
        )
        .map((text) => text.data)
        .whereType<String>()
        .where((text) => text.startsWith('w'));
    final images = tester.widgetList<Image>(
      find.descendant(of: revealedCard, matching: find.byType(Image)),
    );
    expect(labels.isNotEmpty || images.isNotEmpty, isTrue);
  });

  testWidgets('first treasure flip does not show mismatch feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(_zeroCoinSeed()),
          ),
          wordBankProvider.overrideWithValue(_bank10()),
          wordAudioPlayerProvider.overrideWithValue(SilentWordAudioPlayer()),
        ],
        child: const MaterialApp(home: _PushedPage(child: TreasurePage())),
      ),
    );
    await tester.pumpAndSettle();

    final firstCard = _treasurePairsByHiddenKeys().values.first.first;
    await tester.tap(_cardFinder(firstCard));
    await tester.pump();

    expect(find.text('没配对！'), findsNothing);
  });

  testWidgets('treasure mismatch keeps both cards visible before hiding', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(_zeroCoinSeed()),
          ),
          wordBankProvider.overrideWithValue(_bank10()),
          wordAudioPlayerProvider.overrideWithValue(SilentWordAudioPlayer()),
        ],
        child: const MaterialApp(home: _PushedPage(child: TreasurePage())),
      ),
    );
    await tester.pumpAndSettle();

    final pairs = _treasurePairsByHiddenKeys();
    final first = pairs.values.first.first;
    final second = pairs.values.skip(1).first.first;
    final third = pairs.values.skip(2).first.first;

    await tester.tap(_cardFinder(first));
    await tester.pump();
    await tester.tap(_cardFinder(second));
    await tester.pump();

    expect(_cardHasContent(tester, first), isTrue);
    expect(_cardHasContent(tester, second), isTrue);

    await tester.tap(_cardFinder(third));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_cardHasContent(tester, first), isTrue);
    expect(_cardHasContent(tester, second), isTrue);
    expect(_cardHasContent(tester, third), isFalse);

    await tester.pump(const Duration(milliseconds: 500));

    expect(_cardHasContent(tester, first), isFalse);
    expect(_cardHasContent(tester, second), isFalse);
  });

  testWidgets('first treasure flip does not pop when time locks', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(_almostLockedSeed()),
          ),
          wordBankProvider.overrideWithValue(_bank10()),
          wordAudioPlayerProvider.overrideWithValue(SilentWordAudioPlayer()),
        ],
        child: const XiaoCiXingApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('寻宝翻牌'));
    await tester.pumpAndSettle();
    expect(find.byType(TreasurePage), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.tap(_cardFinder(0));
    await tester.pumpAndSettle();

    expect(find.byType(TreasurePage), findsOneWidget);
  });

  testWidgets('firefighter shows a replay control for the prompt audio', (
    tester,
  ) async {
    final audio = _RecordingAudioPlayer();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(_zeroCoinSeed()),
          ),
          wordBankProvider.overrideWithValue(_bank10()),
          wordAudioPlayerProvider.overrideWithValue(audio),
        ],
        child: const MaterialApp(home: FirefighterPage()),
      ),
    );
    await tester.pump();

    expect(audio.played, isNotEmpty);
    expect(audio.played.single, matches(r'^assets/audio/words/w\d\.wav$'));
    expect(find.byKey(const ValueKey('prompt_replay_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('prompt_image')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('prompt_replay_button')));
    await tester.pump();
    expect(audio.played, hasLength(2));
    expect(audio.played.last, audio.played.first);
  });

  testWidgets('monster shows prompt image without Chinese stem', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(_zeroCoinSeed()),
          ),
          wordBankProvider.overrideWithValue(_bank10()),
          wordAudioPlayerProvider.overrideWithValue(SilentWordAudioPlayer()),
        ],
        child: const MaterialApp(home: MonsterPage()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('prompt_image')), findsOneWidget);
    final promptImage = _promptImage(tester);
    expect(
      (promptImage.image as AssetImage).assetName,
      matches(r'^assets/images/words/w\d\.png$'),
    );
    expect(find.byKey(const ValueKey('prompt_replay_button')), findsNothing);
    expect(find.textContaining('词'), findsNothing);
  });

  testWidgets('monster wrong answer shows feedback and advances', (
    tester,
  ) async {
    final soundEffects = _RecordingSoundEffectPlayer();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(_zeroCoinSeed()),
          ),
          wordBankProvider.overrideWithValue(_bank10()),
          wordAudioPlayerProvider.overrideWithValue(SilentWordAudioPlayer()),
          soundEffectPlayerProvider.overrideWithValue(soundEffects),
        ],
        child: const MaterialApp(home: MonsterPage()),
      ),
    );
    await tester.pumpAndSettle();

    final promptBefore = _promptWordIndex(tester);
    final correctKey = ValueKey<String>('choice_w$promptBefore');

    final choices = tester.widgetList<FilledButton>(find.byType(FilledButton));
    final wrongKey = choices
        .map((button) => button.key)
        .whereType<ValueKey<String>>()
        .firstWhere((key) => key != correctKey);

    await tester.tap(find.byKey(wrongKey));
    await tester.pump();

    expect(find.byKey(const ValueKey('game_feedback_effect')), findsOneWidget);
    expect(_feedbackText('落空！'), findsOneWidget);
    expect(soundEffects.played, contains('assets/audio/sfx/wrong.wav'));

    await tester.pumpAndSettle();

    final promptAfter = _promptWordIndex(tester);
    expect(promptAfter, isNot(promptBefore));
  });

  testWidgets(
    'monster correct answer shows animated feedback and plays sound',
    (tester) async {
      final soundEffects = _RecordingSoundEffectPlayer();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(
              FakeUserRepository(_zeroCoinSeed()),
            ),
            wordBankProvider.overrideWithValue(_bank10()),
            wordAudioPlayerProvider.overrideWithValue(SilentWordAudioPlayer()),
            soundEffectPlayerProvider.overrideWithValue(soundEffects),
          ],
          child: const MaterialApp(home: MonsterPage()),
        ),
      );
      await tester.pumpAndSettle();

      final prompt = _promptWordIndex(tester);
      await tester.tap(find.byKey(ValueKey<String>('choice_w$prompt')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('game_feedback_effect')),
        findsOneWidget,
      );
      expect(_feedbackText('击中！'), findsOneWidget);
      expect(soundEffects.played, contains('assets/audio/sfx/correct.wav'));
    },
  );

  testWidgets('locked time after an answer pops game without next prompt', (
    tester,
  ) async {
    final almostLocked = _almostLockedSeed();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(almostLocked),
          ),
          wordBankProvider.overrideWithValue(_bank10()),
          wordAudioPlayerProvider.overrideWithValue(SilentWordAudioPlayer()),
        ],
        child: const XiaoCiXingApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('打怪兽'));
    await tester.pumpAndSettle();
    expect(find.byType(MonsterPage), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));

    final choice = _firstChoiceFinder();
    expect(choice, findsOneWidget);

    await tester.tap(choice);
    await tester.pumpAndSettle();

    expect(find.byType(MonsterPage), findsNothing);
    expect(find.text('今天的学习时间用完了，请爸爸妈妈来帮忙。'), findsOneWidget);
    expect(_allChoicesFinder(), findsNothing);
  });

  testWidgets('home game buttons open the themed pages', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(_zeroCoinSeed()),
          ),
          wordBankProvider.overrideWithValue(_bank10()),
          wordAudioPlayerProvider.overrideWithValue(SilentWordAudioPlayer()),
        ],
        child: const XiaoCiXingApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('寻宝翻牌'));
    await tester.pumpAndSettle();
    expect(find.byType(TreasurePage), findsOneWidget);
    Navigator.of(tester.element(find.byType(TreasurePage))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('消防员灭火'));
    await tester.pumpAndSettle();
    expect(find.byType(FirefighterPage), findsOneWidget);
    Navigator.of(tester.element(find.byType(FirefighterPage))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('打怪兽'));
    await tester.pumpAndSettle();
    expect(find.byType(MonsterPage), findsOneWidget);
  });
}

Finder _firstChoiceFinder() {
  return _allChoicesFinder().first;
}

Finder _allChoicesFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('choice_'),
  );
}

Finder _feedbackText(String text) {
  return find.descendant(
    of: find.byKey(const ValueKey('game_feedback_effect')),
    matching: find.text(text),
  );
}

class _PushedPage extends StatefulWidget {
  const _PushedPage({required this.child});

  final Widget child;

  @override
  State<_PushedPage> createState() => _PushedPageState();
}

class _PushedPageState extends State<_PushedPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => widget.child));
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('返回首页')));
  }
}

Finder _cardFinder(int index) => find.byKey(ValueKey('card_$index'));

bool _cardHasContent(WidgetTester tester, int index) {
  final card = _cardFinder(index);
  final images = tester.widgetList<Image>(
    find.descendant(of: card, matching: find.byType(Image)),
  );
  final labels = tester
      .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
      .map((text) => text.data)
      .whereType<String>()
      .where((text) => text.startsWith('w'));
  return images.isNotEmpty || labels.isNotEmpty;
}

int _promptWordIndex(WidgetTester tester) {
  final image = _promptImage(tester);
  final assetName = (image.image as AssetImage).assetName;
  final match = RegExp(r'w(\d+)\.png$').firstMatch(assetName);
  return int.parse(match!.group(1)!);
}

Image _promptImage(WidgetTester tester) {
  return tester.widget<Image>(
    find.descendant(
      of: find.byKey(const ValueKey('prompt_image')),
      matching: find.byType(Image),
    ),
  );
}

Map<String, List<int>> _treasurePairsByHiddenKeys() {
  final pairs = <String, List<int>>{};

  for (var cardIndex = 0; cardIndex < 12; cardIndex++) {
    for (var wordIndex = 0; wordIndex < 10; wordIndex++) {
      final wordId = 'w$wordIndex';
      final hiddenKey = ValueKey('card_${cardIndex}_$wordId');
      if (find.byKey(hiddenKey).evaluate().isEmpty) {
        continue;
      }
      pairs.putIfAbsent(wordId, () => <int>[]).add(cardIndex);
      break;
    }
  }

  return pairs;
}

UserSnapshot _zeroCoinSeed() {
  final seeded = seed();
  return seeded.copyWith(
    child: ChildProfile(
      name: seeded.child.name,
      avatarId: seeded.child.avatarId,
      wallet: Wallet(coins: 0, ownedItemIds: {}, equipped: const Equipped()),
    ),
  );
}

UserSnapshot _almostLockedSeed() {
  final seeded = _zeroCoinSeed();
  return seeded.copyWith(
    time: TimeQuota(
      dailyLimitMinutes: 20,
      bonusMinutes: 0,
      usedSeconds: (20 * 60) - 1,
      usedOnDate: const ShanghaiClock().todayYyyyMmDd(),
    ),
  );
}

List<Word> _bank10() {
  return List.generate(
    10,
    (index) => Word(
      id: 'w$index',
      en: 'w$index',
      zh: '词$index',
      category: 'test',
      imageAsset: 'assets/images/words/w$index.png',
      audioAsset: 'assets/audio/words/w$index.wav',
    ),
  );
}

class _RecordingAudioPlayer implements WordAudioPlayer {
  final played = <String>[];

  @override
  Future<void> play(String assetPath) async {
    played.add(assetPath);
  }

  @override
  Future<void> dispose() async {}
}

class _RecordingSoundEffectPlayer implements SoundEffectPlayer {
  final played = <String>[];

  @override
  Future<void> play(String assetPath) async {
    played.add(assetPath);
  }

  @override
  Future<void> dispose() async {}
}
