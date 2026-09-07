import 'package:flutter_test/flutter_test.dart';
import 'package:flight_chat/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FlightChatApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FlightChatApp), findsOneWidget);
  });
}
