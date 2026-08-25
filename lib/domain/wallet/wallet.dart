enum ShopSlot { hat, glasses, clothes }

class ShopItem {
  const ShopItem({
    required this.id,
    required this.slot,
    required this.price,
    required this.nameZh,
  });

  final String id;
  final ShopSlot slot;
  final int price;
  final String nameZh;
}

class ShopCatalog {
  static const items = <ShopItem>[
    ShopItem(id: 'hat_20', slot: ShopSlot.hat, price: 20, nameZh: '红帽子'),
    ShopItem(id: 'hat_40', slot: ShopSlot.hat, price: 40, nameZh: '探险帽'),
    ShopItem(id: 'hat_60', slot: ShopSlot.hat, price: 60, nameZh: '皇冠'),
    ShopItem(
      id: 'glasses_20',
      slot: ShopSlot.glasses,
      price: 20,
      nameZh: '圆眼镜',
    ),
    ShopItem(
      id: 'glasses_40',
      slot: ShopSlot.glasses,
      price: 40,
      nameZh: '太阳镜',
    ),
    ShopItem(
      id: 'glasses_60',
      slot: ShopSlot.glasses,
      price: 60,
      nameZh: '星星眼镜',
    ),
    ShopItem(
      id: 'clothes_20',
      slot: ShopSlot.clothes,
      price: 20,
      nameZh: '蓝T恤',
    ),
    ShopItem(
      id: 'clothes_40',
      slot: ShopSlot.clothes,
      price: 40,
      nameZh: '消防员外套',
    ),
    ShopItem(
      id: 'clothes_60',
      slot: ShopSlot.clothes,
      price: 60,
      nameZh: '勇者披风',
    ),
  ];

  static ShopItem byId(String id) => items.firstWhere((item) => item.id == id);
}

class Equipped {
  const Equipped({this.hat, this.glasses, this.clothes});

  final String? hat;
  final String? glasses;
  final String? clothes;

  Equipped withSlot(ShopSlot slot, String? id) {
    switch (slot) {
      case ShopSlot.hat:
        return Equipped(hat: id, glasses: glasses, clothes: clothes);
      case ShopSlot.glasses:
        return Equipped(hat: hat, glasses: id, clothes: clothes);
      case ShopSlot.clothes:
        return Equipped(hat: hat, glasses: glasses, clothes: id);
    }
  }
}

class WalletBuyResult {
  const WalletBuyResult({
    required this.ok,
    required this.wallet,
    this.errorKey,
  });

  final bool ok;
  final Wallet wallet;
  final String? errorKey;
}

class Wallet {
  const Wallet({
    required this.coins,
    required this.ownedItemIds,
    required this.equipped,
  });

  final int coins;
  final Set<String> ownedItemIds;
  final Equipped equipped;

  Wallet addCoins(int amount) {
    if (amount < 0) {
      throw ArgumentError.value(amount);
    }
    return Wallet(
      coins: coins + amount,
      ownedItemIds: ownedItemIds,
      equipped: equipped,
    );
  }

  WalletBuyResult buy(ShopItem item, {required bool online}) {
    if (!online) {
      return WalletBuyResult(ok: false, wallet: this, errorKey: 'offline');
    }
    if (ownedItemIds.contains(item.id)) {
      return WalletBuyResult(
        ok: false,
        wallet: this,
        errorKey: 'already_owned',
      );
    }
    if (coins < item.price) {
      return WalletBuyResult(
        ok: false,
        wallet: this,
        errorKey: 'insufficient_coins',
      );
    }
    return WalletBuyResult(
      ok: true,
      wallet: Wallet(
        coins: coins - item.price,
        ownedItemIds: {...ownedItemIds, item.id},
        equipped: equipped,
      ),
    );
  }

  Wallet equip(String itemId) {
    if (!ownedItemIds.contains(itemId)) {
      throw StateError('not_owned');
    }
    final item = ShopCatalog.byId(itemId);
    return Wallet(
      coins: coins,
      ownedItemIds: ownedItemIds,
      equipped: equipped.withSlot(item.slot, itemId),
    );
  }

  Wallet unequip(ShopSlot slot) {
    return Wallet(
      coins: coins,
      ownedItemIds: ownedItemIds,
      equipped: equipped.withSlot(slot, null),
    );
  }
}
