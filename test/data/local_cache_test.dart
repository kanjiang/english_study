import 'package:english_app/data/local_cache.dart';
import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/domain/wallet/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

UserSnapshot seed() => UserSnapshot(
  uid: 'u1',
  parentPinHash: 'abc',
  child: ChildProfile(
    name: '豆豆',
    avatarId: 'avatar_1',
    wallet: Wallet(coins: 40, ownedItemIds: {}, equipped: const Equipped()),
  ),
  time: TimeQuota(
    dailyLimitMinutes: 30,
    bonusMinutes: 0,
    usedSeconds: 0,
    usedOnDate: '2026-08-25',
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveSnapshot and loadSnapshot round-trip seed user', () async {
    final cache = LocalCache();

    await cache.saveSnapshot(seed());
    await cache.savePendingReward(20);

    final loaded = await cache.loadSnapshot();

    expect(loaded, isNotNull);
    expect(loaded!.child.name, '豆豆');
    expect(await cache.loadPendingReward(), 20);
  });

  test('saveUsedSeconds persists foreground seconds', () async {
    final cache = LocalCache();

    await cache.saveUsedSeconds(123);

    expect(await cache.loadUsedSeconds(), 123);
  });
}
