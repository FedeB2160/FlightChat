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
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
        },
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
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
        },
      ),
    ),
    GoRoute(
      path: '/chat/:groupId',
      pageBuilder: (context, state) {
        final groupId = state.pathParameters['groupId']!;
        return CustomTransitionPage(
          transitionDuration: const Duration(milliseconds: 300),
          child: ChangeNotifierProvider(
            create: (_) => ChatNotifier(groupId: groupId),
            child: ChatScreen(groupId: groupId),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
          },
        );
      },
    ),
  ],
);
