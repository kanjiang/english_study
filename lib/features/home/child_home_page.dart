import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/features/avatar/kid_avatar.dart';
import 'package:english_app/features/games/firefighter_page.dart';
import 'package:english_app/features/games/monster_page.dart';
import 'package:english_app/features/games/treasure_page.dart';
import 'package:english_app/features/parental/parent_gate.dart';
import 'package:english_app/features/shop/shop_page.dart';
import 'package:flutter/material.dart';

class ChildHomePage extends StatelessWidget {
  const ChildHomePage({required this.snapshot, super.key});

  final UserSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final remainingText = snapshot.time.remainingSeconds == 0
        ? '时间到了'
        : '还剩 ${snapshot.time.remainingMinutesDisplay} 分钟';

    return Scaffold(
      appBar: AppBar(
        title: const Text('小词星'),
        actions: [
          TextButton(
            key: const Key('parent_entry'),
            onPressed: () => _pushParentGate(context),
            child: const Text('家长'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: KidAvatar(
                equipped: snapshot.child.wallet.equipped,
                onTap: snapshot.time.isLocked ? null : () => _pushShop(context),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              snapshot.child.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '金币 ${snapshot.child.wallet.coins}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              remainingText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 32),
            if (!snapshot.time.isLocked) ...[
              _GameButton(
                label: '寻宝翻牌',
                onPressed: () => _pushGame(context, const TreasurePage()),
              ),
              _GameButton(
                label: '消防员灭火',
                onPressed: () => _pushGame(context, const FirefighterPage()),
              ),
              _GameButton(
                label: '打怪兽',
                onPressed: () => _pushGame(context, const MonsterPage()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _pushGame(BuildContext context, Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => page));
  }

  void _pushParentGate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ParentGate(snapshot: snapshot),
      ),
    );
  }

  void _pushShop(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ShopPage(initialSnapshot: snapshot),
      ),
    );
  }
}

class _GameButton extends StatelessWidget {
  const _GameButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
