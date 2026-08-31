import 'package:english_app/app.dart';
import 'package:english_app/app/providers.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:english_app/features/auth/onboarding_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
  });

  testWidgets('signed out shows login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(FakeUserRepository.empty()),
        ],
        child: const XiaoCiXingApp(),
      ),
    );

    expect(find.text('登录'), findsWidgets);
  });

  testWidgets('signed-in empty profile shows onboarding in auth gate', (
    tester,
  ) async {
    final repository = FakeUserRepository.empty();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(repository),
          firebaseAuthStateProvider.overrideWith(
            (ref) => Stream<User?>.value(_FakeUser('u1')),
          ),
        ],
        child: const XiaoCiXingApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.text('登录 / 注册'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '豆豆');
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('完成建档'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.text('寻宝翻牌'), findsOneWidget);
  });

  testWidgets('onboarding returns to caller after creating profile', (
    tester,
  ) async {
    final repository = FakeUserRepository.empty();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [userRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: _OnboardingHost()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '豆豆');
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('完成建档'));
    await tester.pumpAndSettle();

    expect(find.text('返回壳'), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
  });
}

class _OnboardingHost extends StatefulWidget {
  const _OnboardingHost();

  @override
  State<_OnboardingHost> createState() => _OnboardingHostState();
}

class _OnboardingHostState extends State<_OnboardingHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const OnboardingPage()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('返回壳')));
  }
}

class _FakeUser implements User {
  _FakeUser(this._uid);

  final String _uid;

  @override
  String get uid => _uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
