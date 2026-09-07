// lib/main.dart — App entry point with Provider setup
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/services/database_service.dart';
import 'features/chat/data/message_repository.dart';
import 'features/onboarding/data/group_repository.dart';
import 'features/onboarding/data/user_profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = DatabaseService();
  // Apre e crea il database prima del primo frame: le rotte assumono uno
  // schema pronto e non devono gestire un DB a metà inizializzazione.
  await db.database;

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: db),
        Provider<GroupRepository>(create: (_) => GroupRepository(db: db)),
        Provider<MessageRepository>(create: (_) => MessageRepository(db: db)),
        Provider<UserProfileRepository>(
          create: (_) => UserProfileRepository(db: db),
        ),
      ],
      child: const FlightChatApp(),
    ),
  );
}
