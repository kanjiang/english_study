import 'package:english_app/app.dart';
import 'package:english_app/app/providers.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/domain/wallet/wallet.dart';
import 'package:english_app/features/avatar/kid_avatar.dart';
import 'package:english_app/features/shop/shop_page.dart';
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

  testWidgets('buying red hat spends coins and equips it immediately', (
    tester,
  ) async {
    final repository = FakeUserRepository(seed());

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(KidAvatar).first);
    await tester.pumpAndSettle();
    expect(find.text('商店'), findsOneWidget);

    await tester.tap(find.byKey(const Key('buy_hat_20')));
    await tester.pumpAndSettle();

    expect(find.text('金币 20'), findsOneWidget);
    expect(find.byIcon(Icons.forest), findsOneWidget);
    expect(find.text('脱下'), findsOneWidget);
    expect((await repository.load())!.child.wallet.coins, 20);
    expect((await repository.load())!.child.wallet.equipped.hat, 'hat_20');
  });

  testWidgets('offline purchase keeps coins and shows retry snackbar', (
    tester,
  ) async {
    final repository = FakeUserRepository(seed(), false);

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(KidAvatar).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buy_hat_20')));
    await tester.pump();

    expect(find.text('现在买不了，稍后再试'), findsOneWidget);
    expect(find.text('金币 40'), findsOneWidget);
    expect((await repository.load())!.child.wallet.coins, 40);
  });

  testWidgets('owned items show wear and remove actions', (tester) async {
    final repository = FakeUserRepository(_ownedHatSeed());

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(KidAvatar).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('buy_hat_20')), findsNothing);
    expect(find.text('穿上'), findsOneWidget);

    await tester.tap(find.text('穿上'));
    await tester.pumpAndSettle();

    expect(find.text('脱下'), findsOneWidget);
    expect((await repository.load())!.child.wallet.equipped.hat, 'hat_20');

    await tester.tap(find.text('脱下'));
    await tester.pumpAndSettle();

    expect(find.text('穿上'), findsOneWidget);
    expect((await repository.load())!.child.wallet.equipped.hat, isNull);
  });

  testWidgets('already owned purchase refreshes the shop state', (
    tester,
  ) async {
    final repository = _AlreadyOwnedRefreshRepository(
      seed(),
      _ownedHatSeed(),
    );

    await tester.pumpWidget(_buildShop(repository, seed()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('buy_hat_20')), findsOneWidget);

    await tester.tap(find.byKey(const Key('buy_hat_20')));
    await tester.pumpAndSettle();

    expect(find.text('已经买过了'), findsOneWidget);
    expect(find.byKey(const Key('buy_hat_20')), findsNothing);
    expect(find.text('穿上'), findsOneWidget);
  });
}

Widget _buildApp(UserRepository repository) {
  return ProviderScope(
    overrides: [userRepositoryProvider.overrideWithValue(repository)],
    child: const XiaoCiXingApp(),
  );
}

Widget _buildShop(UserRepository repository, UserSnapshot initialSnapshot) {
  return ProviderScope(
    overrides: [userRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      home: ShopPage(initialSnapshot: initialSnapshot),
    ),
  );
}

UserSnapshot _ownedHatSeed() {
  final seeded = seed();
  return seeded.copyWith(
    child: ChildProfile(
      name: seeded.child.name,
      avatarId: seeded.child.avatarId,
      wallet: Wallet(
        coins: seeded.child.wallet.coins,
        ownedItemIds: const {'hat_20'},
        equipped: const Equipped(),
      ),
    ),
  );
}

UserSnapshot _ownedAndEquippedHatSeed() {
  final seeded = seed();
  return seeded.copyWith(
    child: ChildProfile(
      name: seeded.child.name,
      avatarId: seeded.child.avatarId,
      wallet: Wallet(
        coins: seeded.child.wallet.coins,
        ownedItemIds: const {'hat_20'},
        equipped: const Equipped(hat: 'hat_20'),
      ),
    ),
  );
}

class _AlreadyOwnedRefreshRepository extends FakeUserRepository {
  _AlreadyOwnedRefreshRepository(UserSnapshot initialSnapshot, this._latestSnapshot)
    : super(initialSnapshot);

  final UserSnapshot _latestSnapshot;
  bool _refreshAfterPurchase = false;

  @override
  Future<UserSnapshot?> load() async {
    return _refreshAfterPurchase ? _latestSnapshot : super.load();
  }

  @override
  Future<void> purchase(ShopItem item) async {
    _refreshAfterPurchase = true;
    throw const ShopPurchaseException('already_owned');
  }
}
