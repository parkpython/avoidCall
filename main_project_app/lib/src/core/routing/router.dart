import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:main_project_app/src/features/onboarding/presentation/onboarding_screen.dart';
import 'package:main_project_app/src/features/main/presentation/main_screen.dart';
import 'package:main_project_app/src/features/keypad/presentation/keypad_screen.dart';
import 'package:main_project_app/src/features/recents/presentation/recents_screen.dart';
import 'package:main_project_app/src/features/contacts/presentation/contacts_screen.dart';
import 'package:main_project_app/src/features/incall/presentation/in_call_screen.dart';
import 'package:main_project_app/src/features/settings/presentation/settings_screen.dart';
import 'package:main_project_app/src/features/translation_call_screen.dart';

// For simplicity, the ErrorScreen is defined here.
// In a real app, this would be in its own file in a 'shared' directory.
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: const Center(
        child: Text('Page not found!'),
      ),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    errorBuilder: (context, state) => const ErrorScreen(),
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/translation-call',
        builder: (context, state) => const TranslationCallScreen(),
      ),
      // The InCallScreen is now a top-level route to simplify navigation.
      GoRoute(
        path: '/in-call-session',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final callId = extra['call_id'] as String? ?? 'no-call-id';
          final language = extra['language'] as String? ?? 'English';
          return InCallScreen(callId: callId, language: language);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/keypad',
                builder: (context, state) => const KeypadScreen(),
                // The nested in-call route has been removed from here.
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/recents',
                builder: (context, state) => const RecentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/contacts',
                builder: (context, state) => const ContactsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});