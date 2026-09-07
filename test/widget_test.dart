import 'package:flight_chat/app.dart';
import 'package:flight_chat/core/services/database_service.dart';
import 'package:flight_chat/features/chat/data/message_repository.dart';
import 'package:flight_chat/features/onboarding/data/group_repository.dart';
import 'package:flight_chat/features/onboarding/data/user_profile_repository.dart';
import 'package:flight_chat/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Welcome screen renders both localized CTAs', (tester) async {
    // Gli stessi provider di main.dart, perche' le rotte li leggono dal context.
    // Il database non viene mai aperto: la WelcomeScreen non interroga nulla, e
    // aprirlo qui bloccherebbe il test (l'I/O reale non gira sotto testWidgets).
    final db = DatabaseService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GroupRepository>(create: (_) => GroupRepository(db: db)),
          Provider<MessageRepository>(create: (_) => MessageRepository(db: db)),
          Provider<UserProfileRepository>(
            create: (_) => UserProfileRepository(db: db),
          ),
        ],
        child: const FlightChatApp(),
      ),
    );
    // Non pumpAndSettle: gradiente e pulsazione del logo sono animazioni infinite.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(WelcomeScreen), findsOneWidget);
    // Locale di default nei test: en.
    expect(find.text('Create Flight'), findsOneWidget);
    expect(find.text('Join Flight'), findsOneWidget);
    expect(find.text('Bluetooth Active'), findsOneWidget);
  });
}
