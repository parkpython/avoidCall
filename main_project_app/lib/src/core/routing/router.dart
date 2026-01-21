import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Screens
import 'package:main_project_app/src/core/routing/scaffold_with_nav_bar.dart';
import 'package:main_project_app/src/features/incall/presentation/auth_provider.dart';
import 'package:main_project_app/src/features/auth/presentation/login_screen.dart';
import 'package:main_project_app/src/features/incall/presentation/in_call_screen.dart';
import 'package:main_project_app/src/features/keypad/presentation/keypad_screen.dart';
import 'package:main_project_app/src/features/settings/presentation/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      // 하단 탭바가 있는 Shell Route 설정
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // 첫 번째 탭: 키패드
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const KeypadScreen(),
              ),
            ],
          ),
          // 두 번째 탭: 설정
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
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/in-call-session',
        builder: (context, state) {
          // KeypadScreen에서 넘겨준 인자 받기
          final extra = state.extra as Map<String, dynamic>?;
          return InCallScreen(
            callId: extra?['call_id'] ?? '',
            language: extra?['language'] ?? 'English',
          );
        },
      ),
    ],
  );
});
