import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/features/avatar/kid_avatar.dart';
import 'package:flutter/material.dart';

class ChildHomePage extends StatelessWidget {
  const ChildHomePage({
    required this.snapshot,
    super.key,
  });

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
            onPressed: () => _pushPlaceholder(context, '家长'),
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
                onTap: snapshot.time.isLocked
                    ? null
                    : () => _pushPlaceholder(context, '商店'),
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
                onPressed: () => _pushPlaceholder(context, '寻宝翻牌'),
              ),
              _GameButton(
                label: '消防员灭火',
                onPressed: () => _pushPlaceholder(context, '消防员灭火'),
              ),
              _GameButton(
                label: '打怪兽',
                onPressed: () => _pushPlaceholder(context, '打怪兽'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _pushPlaceholder(BuildContext context, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Center(child: Text('$title（占位）')),
        ),
      ),
    );
  }
}

class _GameButton extends StatelessWidget {
  const _GameButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
