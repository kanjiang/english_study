import 'package:english_app/app/providers.dart';
import 'package:english_app/domain/user/user_snapshot.dart';
import 'package:english_app/features/auth/login_page.dart';
import 'package:english_app/features/auth/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(userRepositoryProvider);
    final authState = ref.watch(firebaseAuthStateProvider);

    return StreamBuilder<UserSnapshot?>(
      stream: repository.watch(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null) {
          return const ChildHomePage();
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
              return const ChildHomePage();
            }

            return const OnboardingPage();
          },
        );
      },
    );
  }
}

class ChildHomePage extends StatelessWidget {
  const ChildHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('小词星')),
      body: const Center(child: Text('首页')),
    );
  }
}
