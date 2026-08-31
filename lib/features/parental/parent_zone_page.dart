import 'package:english_app/app/providers.dart';
import 'package:english_app/domain/auth/parent_pin.dart';
import 'package:english_app/domain/time/time_quota.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ParentZonePage extends ConsumerStatefulWidget {
  const ParentZonePage({required this.initialSnapshot, super.key});

  final UserSnapshot initialSnapshot;

  @override
  ConsumerState<ParentZonePage> createState() => _ParentZonePageState();
}

class _ParentZonePageState extends ConsumerState<ParentZonePage> {
  final _emailController = TextEditingController();
  final _emailPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneCodeController = TextEditingController();
  final _resetProofController = TextEditingController();
  final _newPinController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialSnapshot.email ?? '';
    _phoneController.text = widget.initialSnapshot.phone ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailPasswordController.dispose();
    _phoneController.dispose();
    _phoneCodeController.dispose();
    _resetProofController.dispose();
    _newPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot =
        ref.watch(foregroundUserSnapshotProvider) ?? widget.initialSnapshot;
    final usedMinutes = snapshot.time.usedSeconds ~/ 60;

    return Scaffold(
      appBar: AppBar(title: const Text('家长区')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '已用 $usedMinutes 分钟',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('每日限额', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final minutes in TimeQuota.allowedDailyLimitMinutes)
                  ChoiceChip(
                    label: Text('$minutes 分钟'),
                    selected: snapshot.time.dailyLimitMinutes == minutes,
                    onSelected: _saving
                        ? null
                        : (selected) {
                            if (selected) {
                              _saveSnapshot(
                                snapshot.copyWith(
                                  time: snapshot.time.setDailyLimitMinutes(
                                    minutes,
                                  ),
                                ),
                              );
                            }
                          },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () => _saveSnapshot(
                      snapshot.copyWith(time: snapshot.time.addBonusMinutes()),
                    ),
              child: const Text('加时 10 分钟'),
            ),
            const SizedBox(height: 24),
            _SectionTitle('修改邮箱'),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '新邮箱'),
            ),
            TextField(
              controller: _emailPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '当前密码'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving ? null : () => _saveEmail(snapshot),
              child: const Text('保存邮箱'),
            ),
            const SizedBox(height: 24),
            _SectionTitle('修改手机号'),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '新手机号'),
            ),
            TextField(
              controller: _phoneCodeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '验证码'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving ? null : () => _savePhone(snapshot),
              child: const Text('保存手机号'),
            ),
            const SizedBox(height: 24),
            _SectionTitle('重置 6 位密码'),
            TextField(
              controller: _resetProofController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '当前登录密码或验证码'),
            ),
            TextField(
              key: const Key('parent_new_pin_input'),
              controller: _newPinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              obscureText: true,
              decoration: const InputDecoration(labelText: '新家长密码（6位）'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : () => _resetPin(snapshot),
              child: const Text('保存新 PIN'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEmail(UserSnapshot snapshot) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('请输入邮箱');
      return;
    }

    final reauthenticated = await _tryReauthenticate(
      _emailPasswordController.text,
    );
    if (!reauthenticated) {
      return;
    }

    try {
      await _currentUser()?.verifyBeforeUpdateEmail(email);
    } catch (_) {}

    await _saveSnapshot(snapshot.copyWith(email: email), message: '邮箱已保存');
  }

  Future<void> _savePhone(UserSnapshot snapshot) async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMessage('请输入手机号');
      return;
    }

    final reauthenticated = await _tryReauthenticate(_phoneCodeController.text);
    if (!reauthenticated) {
      return;
    }

    await _saveSnapshot(snapshot.copyWith(phone: phone), message: '手机号已保存');
  }

  Future<void> _resetPin(UserSnapshot snapshot) async {
    final pin = _newPinController.text.trim();
    if (!isSixDigitPin(pin)) {
      _showMessage('请输入6位数字');
      return;
    }

    final reauthenticated = await _tryReauthenticate(_resetProofController.text);
    if (!reauthenticated) {
      return;
    }

    await _saveSnapshot(
      snapshot.copyWith(
        parentPinHash: hashParentPin(uid: snapshot.uid, pin: pin),
      ),
      message: '家长密码已重置',
    );
    _newPinController.clear();
  }

  Future<void> _saveSnapshot(
    UserSnapshot snapshot, {
    String message = '已保存',
  }) async {
    setState(() {
      _saving = true;
    });

    await ref.read(userRepositoryProvider).save(snapshot);
    ref.read(foregroundUserSnapshotProvider.notifier).state = snapshot;

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
    });
    _showMessage(message);
  }

  Future<bool> _tryReauthenticate(String proof) async {
    final normalizedProof = proof.trim();
    if (normalizedProof.isEmpty) {
      _showMessage('请输入当前登录密码或验证码');
      return false;
    }

    final user = _currentUser();
    if (user == null) {
      return true;
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      _showMessage('重新验证失败，请重试');
      return false;
    }

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: normalizedProof),
      );
      return true;
    } catch (_) {
      _showMessage('重新验证失败，请重试');
      return false;
    }
  }

  User? _currentUser() {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
