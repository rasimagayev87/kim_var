import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kim_var/main.dart';

void main() {
  testWidgets('App boots to the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MeevimaApp()));
    await tester.pump();

    expect(find.byType(MeevimaApp), findsOneWidget);
  });
}
