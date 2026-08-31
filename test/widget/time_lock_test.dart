import 'dart:async';

import 'package:english_app/app.dart';
import 'package:english_app/app/foreground_ticker.dart';
import 'package:english_app/app/providers.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:english_app/domain/shanghai_clock.dart';
import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/domain/wallet/wallet.dart';
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

  testWidgets('locked snapshot shows lock copy and hides games', (
    tester,
  ) async {
    final locked = seed().copyWith(
      time: TimeQuota(
        dailyLimitMinutes: 20,
        bonusMinutes: 0,
        usedSeconds: 20 * 60,
        usedOnDate: const ShanghaiClock().todayYyyyMmDd(),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(FakeUserRepository(locked)),
        ],
        child: const XiaoCiXingApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天的学习时间用完了，请爸爸妈妈来帮忙。'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '家长'), findsOneWidget);
    expect(find.text('寻宝翻牌'), findsNothing);
  });

  testWidgets('unlocked home shows three games and remaining minutes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(FakeUserRepository(seed())),
        ],
        child: const XiaoCiXingApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还剩 30 分钟'), findsOneWidget);
    expect(find.text('寻宝翻牌'), findsOneWidget);
    expect(find.text('消防员灭火'), findsOneWidget);
    expect(find.text('打怪兽'), findsOneWidget);
  });

  testWidgets('foreground tick locks immediately before repository emits', (
    tester,
  ) async {
    final almostLocked = seed().copyWith(
      time: TimeQuota(
        dailyLimitMinutes: 20,
        bonusMinutes: 0,
        usedSeconds: (20 * 60) - 1,
        usedOnDate: const ShanghaiClock().todayYyyyMmDd(),
      ),
    );
    final repository = _LaggingSaveUserRepository(almostLocked);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [userRepositoryProvider.overrideWithValue(repository)],
        child: const XiaoCiXingApp(),
      ),
    );
    await tester.pump();

    expect(find.text('还剩 1 分钟'), findsOneWidget);
    expect(find.text('今天的学习时间用完了，请爸爸妈妈来帮忙。'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('今天的学习时间用完了，请爸爸妈妈来帮忙。'), findsOneWidget);
    expect(find.text('寻宝翻牌'), findsNothing);
    expect(repository.savedSnapshots, isNotEmpty);
  });

  testWidgets('foreground ticker starts when profile appears after null', (
    tester,
  ) async {
    final repository = FakeUserRepository.empty();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [userRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: ForegroundTicker(
            child: Consumer(
              builder: (context, ref, child) {
                final snapshot = ref.watch(foregroundUserSnapshotProvider);
                return Text('used ${snapshot?.time.usedSeconds ?? -1}');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('used -1'), findsOneWidget);

    await repository.createInitial(seed());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('used 2'), findsOneWidget);
  });
}

class _LaggingSaveUserRepository implements UserRepository {
  _LaggingSaveUserRepository(this._snapshot);

  final StreamController<UserSnapshot?> _controller =
      StreamController<UserSnapshot?>.broadcast(sync: true);
  final List<UserSnapshot> savedSnapshots = [];

  UserSnapshot? _snapshot;

  @override
  Stream<UserSnapshot?> watch() {
    return Stream<UserSnapshot?>.multi((controller) {
      controller.add(_snapshot);
      final subscription = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<UserSnapshot?> load() async => _snapshot;

  @override
  Future<void> createInitial(UserSnapshot snapshot) async {
    _snapshot = snapshot;
    _controller.add(_snapshot);
  }

  @override
  Future<void> save(UserSnapshot snapshot) async {
    savedSnapshots.add(snapshot);
  }

  @override
  Future<void> saveTimeQuota(TimeQuota time) async {
    final snapshot = _snapshot;
    if (snapshot != null) {
      savedSnapshots.add(snapshot.copyWith(time: time));
    }
  }

  @override
  Future<void> purchase(ShopItem item) async {}

  @override
  Future<void> addPendingCoins(int coins) async {}

  @override
  Future<void> flushPendingCoins() async {}

  void dispose() {
    _controller.close();
  }
}
