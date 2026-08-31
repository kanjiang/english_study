import 'package:english_app/app/providers.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/domain/wallet/wallet.dart';
import 'package:english_app/features/avatar/kid_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({required this.initialSnapshot, super.key});

  final UserSnapshot initialSnapshot;

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  String? _pendingItemId;
  UserSnapshot? _displaySnapshot;

  @override
  Widget build(BuildContext context) {
    final snapshot =
        _displaySnapshot ??
        ref.watch(foregroundUserSnapshotProvider) ??
        widget.initialSnapshot;
    final wallet = snapshot.child.wallet;

    return Scaffold(
      appBar: AppBar(title: const Text('商店')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: KidAvatar(equipped: wallet.equipped)),
            const SizedBox(height: 12),
            Text(
              '金币 ${wallet.coins}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            for (final item in ShopCatalog.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    title: Text(item.nameZh),
                    subtitle: Text('${item.price} 金币'),
                    trailing: _ShopItemAction(
                      item: item,
                      wallet: wallet,
                      busy: _pendingItemId == item.id,
                      onBuy: () => _buyItem(snapshot, item),
                      onEquip: () => _equipItem(snapshot, item),
                      onUnequip: () => _unequipItem(snapshot, item),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _buyItem(UserSnapshot snapshot, ShopItem item) async {
    setState(() {
      _pendingItemId = item.id;
    });

    try {
      await ref.read(userRepositoryProvider).purchase(item);
      final purchasedSnapshot =
          await ref.read(userRepositoryProvider).load() ?? snapshot;
      final updated = _copyWithWallet(
        purchasedSnapshot,
        purchasedSnapshot.child.wallet.equip(item.id),
      );
      _publishSnapshot(updated);
      await ref.read(userRepositoryProvider).save(updated);
    } on ShopPurchaseException catch (error) {
      if (error.errorKey == 'already_owned') {
        final latestSnapshot =
            await ref.read(userRepositoryProvider).load() ?? snapshot;
        _publishSnapshot(latestSnapshot);
        _showSnackBar('已经买过了');
      } else {
        _showSnackBar(_purchaseMessage(error.errorKey));
      }
    } catch (_) {
      _showSnackBar('现在买不了，稍后再试');
    } finally {
      if (mounted) {
        setState(() {
          _pendingItemId = null;
        });
      }
    }
  }

  Future<void> _equipItem(UserSnapshot snapshot, ShopItem item) async {
    final updated = _copyWithWallet(
      snapshot,
      snapshot.child.wallet.equip(item.id),
    );
    _publishSnapshot(updated);
    await ref.read(userRepositoryProvider).save(updated);
  }

  Future<void> _unequipItem(UserSnapshot snapshot, ShopItem item) async {
    final updated = _copyWithWallet(
      snapshot,
      snapshot.child.wallet.unequip(item.slot),
    );
    _publishSnapshot(updated);
    await ref.read(userRepositoryProvider).save(updated);
  }

  void _publishSnapshot(UserSnapshot snapshot) {
    if (mounted) {
      setState(() {
        _displaySnapshot = snapshot;
      });
    }
    ref.read(foregroundUserSnapshotProvider.notifier).state = snapshot;
  }

  UserSnapshot _copyWithWallet(UserSnapshot snapshot, Wallet wallet) {
    return snapshot.copyWith(
      child: ChildProfile(
        name: snapshot.child.name,
        avatarId: snapshot.child.avatarId,
        wallet: wallet,
      ),
    );
  }

  String _purchaseMessage(String errorKey) {
    switch (errorKey) {
      case 'insufficient_coins':
        return '金币不够';
      case 'already_owned':
        return '已经买过了';
      case 'offline':
      case 'not_authenticated':
      case 'not_found':
      case 'unknown':
        return '现在买不了，稍后再试';
    }
    return '现在买不了，稍后再试';
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ShopItemAction extends StatelessWidget {
  const _ShopItemAction({
    required this.item,
    required this.wallet,
    required this.busy,
    required this.onBuy,
    required this.onEquip,
    required this.onUnequip,
  });

  final ShopItem item;
  final Wallet wallet;
  final bool busy;
  final VoidCallback onBuy;
  final VoidCallback onEquip;
  final VoidCallback onUnequip;

  @override
  Widget build(BuildContext context) {
    final owned = wallet.ownedItemIds.contains(item.id);
    final equipped = _isEquipped(item, wallet.equipped);

    if (!owned) {
      return FilledButton(
        key: Key('buy_${item.id}'),
        onPressed: busy ? null : onBuy,
        child: const Text('购买'),
      );
    }

    return FilledButton(
      onPressed: busy ? null : (equipped ? onUnequip : onEquip),
      child: Text(equipped ? '脱下' : '穿上'),
    );
  }

  bool _isEquipped(ShopItem item, Equipped equipped) {
    switch (item.slot) {
      case ShopSlot.hat:
        return equipped.hat == item.id;
      case ShopSlot.glasses:
        return equipped.glasses == item.id;
      case ShopSlot.clothes:
        return equipped.clothes == item.id;
    }
  }
}
