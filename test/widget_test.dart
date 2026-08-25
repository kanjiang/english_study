import 'package:flutter_test/flutter_test.dart';

import 'package:english_app/main.dart';

void main() {
  testWidgets('shows Chinese app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('小词星'), findsWidgets);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('Flutter Demo'), findsNothing);
    expect(find.text('You have pushed the button this many times:'), findsNothing);
  });
}
