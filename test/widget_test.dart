import 'package:english_app/app.dart';
import 'package:english_app/app/providers.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/domain/wallet/wallet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows Chinese app shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(FakeUserRepository(_seed())),
        ],
        child: const XiaoCiXingApp(),
      ),
    );
    await tester.pump();

    expect(find.text('小词星'), findsWidgets);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('Flutter Demo'), findsNothing);
    expect(
      find.text('You have pushed the button this many times:'),
      findsNothing,
    );
  });
}

UserSnapshot _seed() => UserSnapshot(
  uid: 'u1',
  parentPinHash: 'abc',
  child: ChildProfile(
    name: '豆豆',
    avatarId: 'avatar_1',
    wallet: Wallet(
      coins: 40,
      ownedItemIds: const {},
      equipped: const Equipped(),
    ),
  ),
  time: TimeQuota(
    dailyLimitMinutes: TimeQuota.defaultDailyLimitMinutes,
    bonusMinutes: 0,
    usedSeconds: 0,
    usedOnDate: '2026-08-25',
  ),
);
