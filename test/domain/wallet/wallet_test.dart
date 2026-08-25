import 'package:english_app/domain/wallet/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog has 9 items with 20/40/60 per slot', () {
    expect(ShopCatalog.items, hasLength(9));
    for (final slot in ShopSlot.values) {
      final prices = ShopCatalog.items
          .where((item) => item.slot == slot)
          .map((item) => item.price)
          .toList()
        ..sort();
      expect(prices, [20, 40, 60]);
    }
  });

  test('wallet copies owned item ids from the constructor', () {
    final ownedItemIds = <String>{};
    final hat = ShopCatalog.items.firstWhere((item) => item.slot == ShopSlot.hat);
    final wallet = Wallet(
      coins: 0,
      ownedItemIds: ownedItemIds,
      equipped: const Equipped(),
    );

    ownedItemIds.add(hat.id);

    expect(wallet.ownedItemIds, isNot(contains(hat.id)));
  });

  test('wallet owned item ids are isolated across copies', () {
    final ownedItemIds = <String>{};
    final hat = ShopCatalog.items.firstWhere((item) => item.slot == ShopSlot.hat);
    final wallet = Wallet(
      coins: 0,
      ownedItemIds: ownedItemIds,
      equipped: const Equipped(),
    );
    final sibling = wallet.addCoins(10);

    expect(() => wallet.ownedItemIds.add(hat.id), throwsUnsupportedError);

    ownedItemIds.add(hat.id);

    expect(wallet.ownedItemIds, isNot(contains(hat.id)));
    expect(sibling.ownedItemIds, isNot(contains(hat.id)));
  });

  test('buy succeeds online when coins are enough', () {
    final hat = ShopCatalog.items.firstWhere((item) => item.price == 20);
    final wallet = Wallet(
      coins: 20,
      ownedItemIds: {},
      equipped: const Equipped(),
    );
    final result = wallet.buy(hat, online: true);
    expect(result.ok, isTrue);
    expect(result.wallet.coins, 0);
    expect(result.wallet.ownedItemIds, contains(hat.id));
  });

  test('buy fails offline without changing coins', () {
    final hat = ShopCatalog.items.first;
    final wallet = Wallet(
      coins: 100,
      ownedItemIds: {},
      equipped: const Equipped(),
    );
    final result = wallet.buy(hat, online: false);
    expect(result.ok, isFalse);
    expect(result.errorKey, 'offline');
    expect(result.wallet.coins, 100);
  });

  test('buy fails if already owned', () {
    final hat = ShopCatalog.items.first;
    final wallet = Wallet(
      coins: 100,
      ownedItemIds: {hat.id},
      equipped: const Equipped(),
    );
    final result = wallet.buy(hat, online: true);
    expect(result.errorKey, 'already_owned');
    expect(result.wallet.coins, 100);
  });

  test('buy fails if not enough coins', () {
    final hat = ShopCatalog.items.firstWhere((item) => item.price == 60);
    final wallet = Wallet(
      coins: 20,
      ownedItemIds: {},
      equipped: const Equipped(),
    );
    expect(wallet.buy(hat, online: true).errorKey, 'insufficient_coins');
  });

  test('cannot equip item not owned', () {
    final wallet = Wallet(
      coins: 0,
      ownedItemIds: {},
      equipped: const Equipped(),
    );
    expect(() => wallet.equip(ShopCatalog.items.first.id), throwsStateError);
  });

  test('equip and unequip hat', () {
    final hat = ShopCatalog.items.firstWhere((item) => item.slot == ShopSlot.hat);
    final wallet = Wallet(
      coins: 0,
      ownedItemIds: {hat.id},
      equipped: const Equipped(),
    ).equip(hat.id);
    expect(wallet.equipped.hat, hat.id);
    expect(wallet.unequip(ShopSlot.hat).equipped.hat, isNull);
  });
}
