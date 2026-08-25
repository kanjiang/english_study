import 'package:flutter/material.dart';

class TimeLockPage extends StatelessWidget {
  const TimeLockPage({super.key});

  static const copy = '今天的学习时间用完了，请爸爸妈妈来帮忙。';

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
                  onPressed: () => _pushPlaceholder(context, '家长'),
                  child: const Text('家长'),
                ),
              ],
            ),
          ),
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
