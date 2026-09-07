import 'package:flutter_test/flutter_test.dart';
import 'package:flight_chat/app.dart';
import 'package:flight_chat/features/onboarding/presentation/screens/welcome_screen.dart';

void main() {
  testWidgets('Welcome screen renders both localized CTAs', (tester) async {
    await tester.pumpWidget(const FlightChatApp());
    // Non pumpAndSettle: gradiente e pulsazione del logo sono animazioni infinite.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(WelcomeScreen), findsOneWidget);
    // Locale di default nei test: en.
    expect(find.text('Create Flight'), findsOneWidget);
    expect(find.text('Join Flight'), findsOneWidget);
    expect(find.text('Bluetooth Active'), findsOneWidget);
  });
}
