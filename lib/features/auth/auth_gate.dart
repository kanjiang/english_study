import 'package:english_app/app/providers.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/features/auth/login_page.dart';
import 'package:english_app/features/auth/onboarding_page.dart';
import 'package:english_app/features/home/child_home_page.dart';
import 'package:english_app/features/lock/time_lock_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(userRepositoryProvider);
    final foregroundSnapshot = ref.watch(foregroundUserSnapshotProvider);
    final authState = ref.watch(firebaseAuthStateProvider);

    return StreamBuilder<UserSnapshot?>(
      stream: repository.watch(),
      builder: (context, snapshot) {
        final user = foregroundSnapshot ?? snapshot.data;
        if (user != null) {
          return _HomeWithLock(snapshot: user);
        }

        final signedIn = authState.maybeWhen(
          data: (user) => user != null,
          orElse: () => false,
        );
        if (!signedIn) {
          return const LoginPage();
        }

        return FutureBuilder<UserSnapshot?>(
          future: repository.load(),
          builder: (context, loadSnapshot) {
            if (loadSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (loadSnapshot.data != null) {
              return _HomeWithLock(snapshot: loadSnapshot.data!);
            }

            return const OnboardingPage();
          },
        );
      },
    );
  }
}

class _HomeWithLock extends StatelessWidget {
  const _HomeWithLock({required this.snapshot});

  final UserSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ChildHomePage(snapshot: snapshot),
        if (snapshot.time.isLocked) TimeLockPage(snapshot: snapshot),
      ],
    );
  }
}
