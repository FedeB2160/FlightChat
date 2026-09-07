// lib/app.dart — Root MaterialApp widget configuring dark theme, router, and i18n
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flight_chat/l10n/gen/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

class FlightChatApp extends StatelessWidget {
  const FlightChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FlightChat',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en'),
        const Locale('it'),
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}
