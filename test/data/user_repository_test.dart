import 'package:english_app/data/user_repository.dart';
import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/domain/wallet/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/seed.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('createInitial and save update load and watch', () async {
    final repo = FakeUserRepository();
    final updated = seed().copyWith(
      time: TimeQuota(
        dailyLimitMinutes: 30,
        bonusMinutes: 10,
        usedSeconds: 12,
        usedOnDate: '2026-08-25',
      ),
    );

    expect(await repo.load(), isNull);

    final events = <int>[];
    final subscription = repo.watch().listen((snapshot) {
      if (snapshot != null) {
        events.add(snapshot.time.usedSeconds);
      }
    });

    await repo.createInitial(seed());
    await repo.save(updated);
    await Future<void>.delayed(Duration.zero);

    final loaded = await repo.load();

    expect(loaded, isNotNull);
    expect(loaded!.time.usedSeconds, 12);
    expect(loaded.time.bonusMinutes, 10);
    expect(events, [0, 12]);

    await subscription.cancel();
  });

  test('purchase deducts coins and failed purchase leaves coins', () async {
    final repo = FakeUserRepository(seed());
    final cheapItem = ShopCatalog.items.firstWhere((item) => item.price == 20);
    final expensiveItem = ShopCatalog.items.firstWhere(
      (item) => item.price == 60,
    );

    await repo.purchase(cheapItem);

    expect((await repo.load())!.child.wallet.coins, 20);

    final before = await repo.load();

    await expectLater(
      repo.purchase(expensiveItem),
      throwsA(
        isA<ShopPurchaseException>().having(
          (error) => error.errorKey,
          'errorKey',
          'insufficient_coins',
        ),
      ),
    );

    expect((await repo.load())!.child.wallet.coins, before!.child.wallet.coins);
  });

  test('purchase throws already_owned when item is already owned', () async {
    final item = ShopCatalog.items.first;
    final snapshot = seed().copyWith(
      child: ChildProfile(
        name: seed().child.name,
        avatarId: seed().child.avatarId,
        wallet: Wallet(
          coins: 40,
          ownedItemIds: {item.id},
          equipped: const Equipped(),
        ),
      ),
    );
    final repo = FakeUserRepository(snapshot);

    await expectLater(
      repo.purchase(item),
      throwsA(
        isA<ShopPurchaseException>().having(
          (error) => error.errorKey,
          'errorKey',
          'already_owned',
        ),
      ),
    );
  });

  test('purchase throws offline when fake repository is offline', () async {
    final repo = FakeUserRepository(seed(), false);

    await expectLater(
      repo.purchase(ShopCatalog.items.first),
      throwsA(
        isA<ShopPurchaseException>().having(
          (error) => error.errorKey,
          'errorKey',
          'offline',
        ),
      ),
    );
  });

  test('addPendingCoins then flushPendingCoins adds to cloud coins', () async {
    final repo = FakeUserRepository(seed());

    await repo.addPendingCoins(20);
    expect((await repo.load())!.child.wallet.coins, 60);

    await repo.flushPendingCoins();

    expect((await repo.load())!.child.wallet.coins, 60);
  });

  test('save persists cloud coins without double-counting pending coins', () async {
    final repo = FakeUserRepository(seed());

    await repo.addPendingCoins(20);

    final loaded = await repo.load();
    expect(loaded, isNotNull);
    expect(loaded!.child.wallet.coins, 60);

    await repo.save(
      loaded.copyWith(
        time: TimeQuota(
          dailyLimitMinutes: loaded.time.dailyLimitMinutes,
          bonusMinutes: loaded.time.bonusMinutes,
          usedSeconds: loaded.time.usedSeconds + 5,
          usedOnDate: loaded.time.usedOnDate,
        ),
      ),
    );

    expect((await repo.load())!.child.wallet.coins, 60);

    await repo.flushPendingCoins();

    expect((await repo.load())!.child.wallet.coins, 60);
  });
}
