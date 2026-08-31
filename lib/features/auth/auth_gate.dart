import 'package:english_app/app/providers.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/features/auth/login_page.dart';
import 'package:english_app/features/auth/onboarding_page.dart';
import 'package:english_app/features/home/child_home_page.dart';
import 'package:english_app/features/lock/time_lock_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  UserRepository? _repository;
  Stream<UserSnapshot?>? _userStream;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(userRepositoryProvider);
    final foregroundSnapshot = ref.watch(foregroundUserSnapshotProvider);
    final authState = ref.watch(firebaseAuthStateProvider);
    if (!identical(_repository, repository)) {
      _repository = repository;
      _userStream = repository.watch();
    }

    return StreamBuilder<UserSnapshot?>(
      stream: _userStream,
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

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const OnboardingPage();
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
