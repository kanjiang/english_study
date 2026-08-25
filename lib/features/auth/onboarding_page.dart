import 'package:english_app/app/providers.dart';
import 'package:english_app/domain/auth/parent_pin.dart';
import 'package:english_app/domain/shanghai_clock.dart';
import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/domain/wallet/wallet.dart';
import 'package:english_app/features/home/child_home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();

  String _avatarId = UserSnapshot.avatarIds.first;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建孩子档案')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '给孩子起个名字'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final avatarId in UserSnapshot.avatarIds)
                  ChoiceChip(
                    label: Text(avatarId),
                    selected: _avatarId == avatarId,
                    onSelected: (_) {
                      setState(() {
                        _avatarId = avatarId;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              obscureText: true,
              decoration: const InputDecoration(labelText: '设置家长密码（6位）'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: const Text('完成建档'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    if (!isSixDigitPin(pin)) {
      _showMessage('请输入6位数字');
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('请先给孩子起个名字');
      return;
    }

    setState(() {
      _submitting = true;
    });

    final firebaseUser = FirebaseAuth.instance.currentUser;
    final uid = firebaseUser?.uid ?? 'local';
    final snapshot = UserSnapshot(
      uid: uid,
      email: firebaseUser?.email,
      phone: firebaseUser?.phoneNumber,
      parentPinHash: hashParentPin(uid: uid, pin: pin),
      child: ChildProfile(
        name: name,
        avatarId: _avatarId,
        wallet: Wallet(
          coins: 0,
          ownedItemIds: const {},
          equipped: const Equipped(),
        ),
      ),
      time: TimeQuota(
        dailyLimitMinutes: TimeQuota.defaultDailyLimitMinutes,
        bonusMinutes: 0,
        usedSeconds: 0,
        usedOnDate: const ShanghaiClock().todayYyyyMmDd(),
      ),
    );

    await ref.read(userRepositoryProvider).createInitial(snapshot);

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ChildHomePage(snapshot: snapshot),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
