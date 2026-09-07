// lib/core/router/app_router.dart — GoRouter configuration with custom transitions and route-level ChangeNotifierProviders
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/onboarding/presentation/screens/create_group_screen.dart';
import '../../features/onboarding/presentation/screens/join_group_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/onboarding/presentation/notifiers/create_group_notifier.dart';
import '../../features/onboarding/presentation/notifiers/join_group_notifier.dart';
import '../../features/chat/presentation/notifiers/chat_notifier.dart';
import '../../features/chat/data/message_repository.dart';
import '../../features/onboarding/data/group_repository.dart';
import '../../features/onboarding/data/user_profile_repository.dart';

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
          create: (context) => CreateGroupNotifier(
            groupRepo: context.read<GroupRepository>(),
            profileRepo: context.read<UserProfileRepository>(),
          ),
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
          create: (context) => JoinGroupNotifier(
            groupRepo: context.read<GroupRepository>(),
            profileRepo: context.read<UserProfileRepository>(),
          ),
          child: const JoinGroupScreen(),
        ),
        transitionsBuilder: _slideFade,
      ),
    ),
    GoRoute(
      path: '/chat/:groupId',
      pageBuilder: (context, state) {
        final groupId = state.pathParameters['groupId']!;

        // Il solo groupId basta: chiave, t0, nome gruppo e profilo locale
        // arrivano dal database, quindi la rotta funziona anche a freddo dopo
        // un restart o da deep link. Il passaggio via `extra` della Fase 1
        // non serve più.
        return CustomTransitionPage(
          transitionDuration: const Duration(milliseconds: 300),
          child: ChangeNotifierProvider(
            create: (context) => ChatNotifier(
              groupId: groupId,
              messageRepo: context.read<MessageRepository>(),
              groupRepo: context.read<GroupRepository>(),
              profileRepo: context.read<UserProfileRepository>(),
            ),
            child: ChatScreen(groupId: groupId),
          ),
          transitionsBuilder: _slideFade,
        );
      },
    ),
  ],
);
