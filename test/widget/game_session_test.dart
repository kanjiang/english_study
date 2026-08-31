import 'package:english_app/app.dart';
import 'package:english_app/app/providers.dart';
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
          userRepositoryProvider.overrideWithValue(FakeUserRepository(_zeroCoinSeed())),
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
    final icons = tester.widgetList<Icon>(
      find.descendant(of: revealedCard, matching: find.byType(Icon)),
    );
    expect(labels.isNotEmpty || icons.isNotEmpty, isTrue);
  });

  testWidgets('first treasure flip does not show mismatch feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(FakeUserRepository(_zeroCoinSeed())),
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
    expect(audio.played.single, 'assets/audio/w');
    expect(find.byKey(const ValueKey('prompt_replay_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('prompt_image')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('prompt_replay_button')));
    await tester.pump();
    expect(audio.played, hasLength(2));
  });

  testWidgets('monster still shows the prompt image', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(FakeUserRepository(_zeroCoinSeed())),
          wordBankProvider.overrideWithValue(_bank10()),
          wordAudioPlayerProvider.overrideWithValue(SilentWordAudioPlayer()),
        ],
        child: const MaterialApp(home: MonsterPage()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('prompt_image')), findsOneWidget);
    expect(find.byKey(const ValueKey('prompt_replay_button')), findsNothing);
  });

  testWidgets('monster wrong answer shows feedback and advances', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(FakeUserRepository(_zeroCoinSeed())),
          wordBankProvider.overrideWithValue(_bank10()),
          wordAudioPlayerProvider.overrideWithValue(SilentWordAudioPlayer()),
        ],
        child: const MaterialApp(home: MonsterPage()),
      ),
    );
    await tester.pumpAndSettle();

    final promptFinder = find.textContaining('词');
    expect(promptFinder, findsOneWidget);
    final promptBefore = tester.widget<Text>(promptFinder).data!;
    final promptIndex = int.parse(promptBefore.replaceFirst('词', ''));
    final correctKey = ValueKey<String>('choice_w$promptIndex');

    final choices = tester.widgetList<FilledButton>(find.byType(FilledButton));
    final wrongKey = choices
        .map((button) => button.key)
        .whereType<ValueKey<String>>()
        .firstWhere((key) => key != correctKey);

    await tester.tap(find.byKey(wrongKey));
    await tester.pump();

    expect(find.text('落空！'), findsOneWidget);

    await tester.pumpAndSettle();

    final promptAfter = tester.widget<Text>(find.textContaining('词')).data!;
    expect(promptAfter, isNot(promptBefore));
  });

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

const _iconBase = 0xe000;

List<Word> _bank10() {
  return List.generate(
    10,
    (index) => Word(
      id: 'w$index',
      en: 'w$index',
      zh: '词$index',
      category: 'test',
      iconCodePoint: _iconBase + index,
      audioAsset: 'assets/audio/w',
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
