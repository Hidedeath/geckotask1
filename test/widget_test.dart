import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('Dashboard shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Hourly Energy Comparison'), findsOneWidget);
    expect(find.text('30-Day Solar Trend'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
  });
}
