import 'package:english_app/app.dart';
import 'package:english_app/app/providers.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:english_app/domain/auth/parent_pin.dart';
import 'package:english_app/domain/shanghai_clock.dart';
import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
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

  testWidgets('wrong PIN stays on gate, then correct PIN opens parent zone', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(FakeUserRepository(_pinSeed())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('parent_entry')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('parent_pin_input')), '000000');
    await tester.tap(find.text('进入家长区'));
    await tester.pump();

    expect(find.text('密码不对'), findsOneWidget);
    expect(find.text('加时 10 分钟'), findsNothing);

    await tester.enterText(find.byKey(const Key('parent_pin_input')), '123456');
    await tester.tap(find.text('进入家长区'));
    await tester.pumpAndSettle();

    expect(find.text('加时 10 分钟'), findsOneWidget);
    expect(find.text('已用 0 分钟'), findsOneWidget);
  });

  testWidgets(
    'locked child unlocks immediately after parent grants extra time',
    (tester) async {
      final repository = FakeUserRepository(_lockedSeed());

      await tester.pumpWidget(_buildApp(repository));
      await tester.pumpAndSettle();

      expect(find.text(TimeLockPageCopy.value), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '家长'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('parent_pin_input')),
        '123456',
      );
      await tester.tap(find.text('进入家长区'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('加时 10 分钟'));
      await tester.pumpAndSettle();

      expect(find.text(TimeLockPageCopy.value), findsNothing);
      expect((await repository.load())!.time.isLocked, isFalse);
    },
  );

  testWidgets('five wrong PIN attempts blocks parent gate for one minute', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(FakeUserRepository(_pinSeed())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('parent_entry')));
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < 5; attempt++) {
      await tester.enterText(
        find.byKey(const Key('parent_pin_input')),
        '000000',
      );
      await tester.tap(find.text('进入家长区'));
      await tester.pump();
    }

    expect(find.text('请 1 分钟后再试'), findsOneWidget);
  });
}

Widget _buildApp(UserRepository repository) {
  return ProviderScope(
    overrides: [userRepositoryProvider.overrideWithValue(repository)],
    child: const XiaoCiXingApp(),
  );
}

UserSnapshot _pinSeed() {
  final seeded = seed();
  return seeded.copyWith(
    parentPinHash: hashParentPin(uid: seeded.uid, pin: '123456'),
  );
}

UserSnapshot _lockedSeed() {
  final seeded = _pinSeed();
  return seeded.copyWith(
    time: TimeQuota(
      dailyLimitMinutes: 20,
      bonusMinutes: 0,
      usedSeconds: 20 * 60,
      usedOnDate: const ShanghaiClock().todayYyyyMmDd(),
    ),
  );
}

class TimeLockPageCopy {
  static const value = '今天的学习时间用完了，请爸爸妈妈来帮忙。';
}
