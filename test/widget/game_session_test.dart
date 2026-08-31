import 'dart:async';

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

    final pairs = _visibleTreasurePairs(tester);
    expect(pairs, hasLength(6));

    for (final pair in pairs.values) {
      await tester.tap(find.byKey(ValueKey('card_${pair.imageIndex}')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('card_${pair.textIndex}')));
      await tester.pumpAndSettle();
    }

    final snapshot = await repository.load();
    expect(find.text('返回首页'), findsOneWidget);
    expect(snapshot!.child.wallet.coins, greaterThan(0));
    expect(snapshot.gameStats.treasureLastScore, snapshot.child.wallet.coins);
  });

  testWidgets('firefighter plays prompt audio on each question', (
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

class _TreasurePair {
  const _TreasurePair({required this.imageIndex, required this.textIndex});

  final int imageIndex;
  final int textIndex;
}

Map<String, _TreasurePair> _visibleTreasurePairs(WidgetTester tester) {
  final imageByWord = <String, int>{};
  final textByWord = <String, int>{};

  for (var i = 0; i < 12; i++) {
    final card = find.byKey(ValueKey('card_$i'));
    final texts = tester
        .widgetList<Text>(
          find.descendant(of: card, matching: find.byType(Text)),
        )
        .map((text) => text.data)
        .whereType<String>();
    final labels = texts.where((text) => text.startsWith('w')).toList();
    if (labels.isNotEmpty) {
      textByWord[labels.single] = i;
      continue;
    }

    final icons = tester.widgetList<Icon>(
      find.descendant(of: card, matching: find.byType(Icon)),
    );
    final icon = icons.single;
    imageByWord['w${icon.icon!.codePoint - _iconBase}'] = i;
  }

  return {
    for (final word in imageByWord.keys)
      word: _TreasurePair(
        imageIndex: imageByWord[word]!,
        textIndex: textByWord[word]!,
      ),
  };
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
