import 'package:english_app/app.dart';
import 'package:english_app/app/providers.dart';
import 'package:english_app/data/user_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/seed.dart';

void main() {
  testWidgets('shows Chinese app shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(FakeUserRepository(seed())),
        ],
        child: const XiaoCiXingApp(),
      ),
    );
    await tester.pump();

    expect(find.text('小词星'), findsWidgets);
    expect(find.text('寻宝翻牌'), findsOneWidget);
    expect(find.text('Flutter Demo'), findsNothing);
    expect(
      find.text('You have pushed the button this many times:'),
      findsNothing,
    );
  });
}
