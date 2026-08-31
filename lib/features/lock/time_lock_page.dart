import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/features/parental/parent_gate.dart';
import 'package:flutter/material.dart';

class TimeLockPage extends StatelessWidget {
  const TimeLockPage({required this.snapshot, super.key});

  static const copy = '今天的学习时间用完了，请爸爸妈妈来帮忙。';

  final UserSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_clock,
                  size: 88,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  copy,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('parent_entry'),
                  onPressed: () => _pushParentGate(context),
                  child: const Text('家长'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pushParentGate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ParentGate(snapshot: snapshot),
      ),
    );
  }
}
