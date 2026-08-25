import 'package:english_app/app/providers.dart';
import 'package:english_app/features/auth/onboarding_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  String? _verificationId;
  String? _errorText;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('登录 / 注册'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '邮箱'),
              Tab(text: '手机号'),
            ],
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _EmailLoginForm(
                        emailController: _emailController,
                        passwordController: _passwordController,
                        submitting: _submitting,
                        onLogin: () => _submitEmail(register: false),
                        onRegister: () => _submitEmail(register: true),
                      ),
                      _PhoneLoginForm(
                        phoneController: _phoneController,
                        codeController: _codeController,
                        submitting: _submitting,
                        codeSent: _verificationId != null,
                        onSendCode: _sendPhoneCode,
                        onLogin: _submitPhoneCode,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitEmail({required bool register}) async {
    await _runAuthAction(() async {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (register) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    });
  }

  Future<void> _sendPhoneCode() async {
    setState(() {
      _errorText = null;
      _submitting = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phoneController.text.trim(),
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          await _goToNextStep();
        },
        verificationFailed: (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _errorText = _authErrorMessage(error.code);
            _submitting = false;
          });
        },
        codeSent: (verificationId, _) {
          if (!mounted) {
            return;
          }
          setState(() {
            _verificationId = verificationId;
            _submitting = false;
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (error) {
      _setAuthError(error.code);
    } catch (_) {
      _setAuthError(null);
    }
  }

  Future<void> _submitPhoneCode() async {
    final verificationId = _verificationId;
    if (verificationId == null) {
      await _sendPhoneCode();
      return;
    }

    await _runAuthAction(() async {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: _codeController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    });
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    setState(() {
      _errorText = null;
      _submitting = true;
    });

    try {
      await action();
      await _goToNextStep();
    } on FirebaseAuthException catch (error) {
      _setAuthError(error.code);
    } catch (_) {
      _setAuthError(null);
    }
  }

  Future<void> _goToNextStep() async {
    final repository = ref.read(userRepositoryProvider);
    final existing = await repository.load();

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    if (existing == null) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const OnboardingPage()),
      );
    }
  }

  void _setAuthError(String? code) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorText = _authErrorMessage(code);
      _submitting = false;
    });
  }
}

String _authErrorMessage(String? code) {
  switch (code) {
    case 'user-not-found':
      return '账号不存在';
    case 'wrong-password':
      return '密码不对';
    case 'invalid-verification-code':
      return '验证码不对';
    default:
      return '登录失败，请稍后重试';
  }
}

class _EmailLoginForm extends StatelessWidget {
  const _EmailLoginForm({
    required this.emailController,
    required this.passwordController,
    required this.submitting,
    required this.onLogin,
    required this.onRegister,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool submitting;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: '邮箱'),
        ),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: '密码'),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: submitting ? null : onLogin,
          child: const Text('登录'),
        ),
        TextButton(
          onPressed: submitting ? null : onRegister,
          child: const Text('注册'),
        ),
      ],
    );
  }
}

class _PhoneLoginForm extends StatelessWidget {
  const _PhoneLoginForm({
    required this.phoneController,
    required this.codeController,
    required this.submitting,
    required this.codeSent,
    required this.onSendCode,
    required this.onLogin,
  });

  final TextEditingController phoneController;
  final TextEditingController codeController;
  final bool submitting;
  final bool codeSent;
  final VoidCallback onSendCode;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: '手机号'),
        ),
        TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '验证码'),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: submitting ? null : onSendCode,
          child: const Text('发送验证码'),
        ),
        FilledButton(
          onPressed: submitting ? null : onLogin,
          child: Text(codeSent ? '登录' : '登录 / 注册'),
        ),
      ],
    );
  }
}
