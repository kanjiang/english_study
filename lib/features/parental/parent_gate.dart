import 'package:english_app/app/providers.dart';
import 'package:english_app/domain/auth/parent_pin.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/features/parental/parent_zone_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ParentGate extends ConsumerStatefulWidget {
  const ParentGate({required this.snapshot, super.key});

  final UserSnapshot snapshot;

  @override
  ConsumerState<ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends ConsumerState<ParentGate> {
  final _gate = PinGate();
  final _pinController = TextEditingController();
  final _proofController = TextEditingController();
  final _newPinController = TextEditingController();
  late UserSnapshot _snapshot;
  bool _unlocked = false;
  bool _forgotPin = false;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.snapshot;
  }

  @override
  void dispose() {
    _pinController.dispose();
    _proofController.dispose();
    _newPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) {
      return ParentZonePage(initialSnapshot: _snapshot);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('家长')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: _forgotPin ? _buildForgotPinForm() : _buildPinForm(),
        ),
      ),
    );
  }

  List<Widget> _buildPinForm() {
    return [
      Text('请输入家长密码', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      TextField(
        key: const Key('parent_pin_input'),
        controller: _pinController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        obscureText: true,
        decoration: const InputDecoration(labelText: '6 位家长密码'),
      ),
      if (_errorText != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      FilledButton(onPressed: _submitPin, child: const Text('进入家长区')),
      TextButton(
        onPressed: () {
          setState(() {
            _forgotPin = true;
            _errorText = null;
          });
        },
        child: const Text('忘记家长密码'),
      ),
    ];
  }

  List<Widget> _buildForgotPinForm() {
    return [
      Text('忘记家长密码', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('重新验证邮箱密码或短信验证码后，设置新的 6 位家长密码。'),
      const SizedBox(height: 16),
      TextField(
        controller: _proofController,
        obscureText: true,
        decoration: const InputDecoration(labelText: '当前登录密码或验证码'),
      ),
      TextField(
        key: const Key('forgot_parent_new_pin_input'),
        controller: _newPinController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        obscureText: true,
        decoration: const InputDecoration(labelText: '新家长密码（6位）'),
      ),
      if (_errorText != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      FilledButton(
        onPressed: _saving ? null : _resetForgotPin,
        child: const Text('重置家长密码'),
      ),
      TextButton(
        onPressed: _saving
            ? null
            : () {
                setState(() {
                  _forgotPin = false;
                  _errorText = null;
                });
              },
        child: const Text('返回输入密码'),
      ),
    ];
  }

  void _submitPin() {
    final pin = _pinController.text.trim();
    if (!isSixDigitPin(pin)) {
      setState(() {
        _errorText = '请输入6位数字';
      });
      return;
    }

    final result = _gate.tryPin(
      uid: _snapshot.uid,
      pin: pin,
      hash: _snapshot.parentPinHash,
      now: DateTime.now(),
    );

    if (result.ok) {
      setState(() {
        _unlocked = true;
        _errorText = null;
      });
      return;
    }

    setState(() {
      _errorText = result.errorKey == 'locked' ? '请 1 分钟后再试' : '密码不对';
    });
  }

  Future<void> _resetForgotPin() async {
    final pin = _newPinController.text.trim();
    if (!isSixDigitPin(pin)) {
      setState(() {
        _errorText = '请输入6位数字';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    final reauthenticated = await _tryReauthenticate(_proofController.text);
    if (!mounted) {
      return;
    }
    if (!reauthenticated) {
      setState(() {
        _saving = false;
      });
      return;
    }

    final updated = _snapshot.copyWith(
      parentPinHash: hashParentPin(uid: _snapshot.uid, pin: pin),
    );
    await ref.read(userRepositoryProvider).save(updated);
    ref.read(foregroundUserSnapshotProvider.notifier).state = updated;

    if (!mounted) {
      return;
    }

    setState(() {
      _snapshot = updated;
      _unlocked = true;
      _saving = false;
    });
  }

  Future<bool> _tryReauthenticate(String proof) async {
    final normalizedProof = proof.trim();
    if (normalizedProof.isEmpty) {
      setState(() {
        _errorText = '请输入当前登录密码或验证码';
      });
      return false;
    }

    final user = _currentUser();
    if (user == null) {
      return true;
    }

    final email = user?.email;
    if (email == null || email.isEmpty) {
      setState(() {
        _errorText = '重新验证失败，请重试';
      });
      return false;
    }

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: normalizedProof),
      );
      return true;
    } catch (_) {
      setState(() {
        _errorText = '重新验证失败，请重试';
      });
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
}
