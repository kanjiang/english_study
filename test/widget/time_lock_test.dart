import 'package:english_app/app.dart';
import 'package:english_app/app/providers.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:english_app/domain/shanghai_clock.dart';
import 'package:english_app/domain/time/time_quota.dart';
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
}
