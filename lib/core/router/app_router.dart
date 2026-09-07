// lib/core/router/app_router.dart — GoRouter configuration with custom transitions and route-level ChangeNotifierProviders
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flight_chat/l10n/gen/app_localizations.dart';

import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/onboarding/presentation/screens/create_group_screen.dart';
import '../../features/onboarding/presentation/screens/join_group_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/onboarding/presentation/notifiers/create_group_notifier.dart';
import '../../features/onboarding/presentation/notifiers/join_group_notifier.dart';
import '../../features/chat/presentation/notifiers/chat_notifier.dart';
import '../../shared/models/user_profile.dart';
import '../constants/app_constants.dart';

/// Slide + fade condivisa dalle rotte. Rispetta "rimuovi animazioni" di sistema.
Widget _slideFade(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.05, 0),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/create',
      pageBuilder: (context, state) => CustomTransitionPage(
        transitionDuration: const Duration(milliseconds: 300),
        child: ChangeNotifierProvider(
          create: (_) => CreateGroupNotifier(),
          child: const CreateGroupScreen(),
        ),
        transitionsBuilder: _slideFade,
      ),
    ),
    GoRoute(
      path: '/join',
      pageBuilder: (context, state) => CustomTransitionPage(
        transitionDuration: const Duration(milliseconds: 300),
        child: ChangeNotifierProvider(
          create: (_) => JoinGroupNotifier(),
          child: const JoinGroupScreen(),
        ),
        transitionsBuilder: _slideFade,
      ),
    ),
    GoRoute(
      path: '/chat/:groupId',
      pageBuilder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        final l10n = AppLocalizations.of(context)!;

        // ponytail: profilo e nome gruppo viaggiano in `extra`, quindi si perdono a
        // restart o deep link. Sufficiente per Fase 1: persisterli e' deliverable
        // di Fase 2 (SQLite). Senza extra la chat resta usabile in sola lettura.
        final extra = state.extra;
        final data = extra is Map ? extra : const <Object?, Object?>{};
        final profile = data[AppConstants.extraProfile];
        final groupName = data[AppConstants.extraGroupName];

        return CustomTransitionPage(
          transitionDuration: const Duration(milliseconds: 300),
          child: ChangeNotifierProvider(
            create: (_) => ChatNotifier(
              groupId: groupId,
              localProfile: profile is UserProfile ? profile : null,
              mockCaptainName: l10n.captainDefault,
              mockPassengerName: l10n.nicknameDefault(2),
            ),
            child: ChatScreen(
              groupId: groupId,
              groupName: groupName is String && groupName.trim().isNotEmpty
                  ? groupName.trim()
                  : null,
            ),
          ),
          transitionsBuilder: _slideFade,
        );
      },
    ),
  ],
);
