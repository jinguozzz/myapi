import 'package:flutter_test/flutter_test.dart';

import 'package:myapi/app.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyAIApp());
    expect(find.byType(MyAIApp), findsOneWidget);
  });
}
