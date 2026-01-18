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
  // authStateProvider의 스트림을 구독하여 인증 상태가 바뀔 때마다 라우터에 알림
  final authStream = Supabase.instance.client.auth.onAuthStateChange;

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    // Supabase 인증 상태(로그인/로그아웃)가 변할 때마다 라우트 갱신
    refreshListenable: GoRouterRefreshStream(authStream),

    // 화면 이동 시마다 실행되는 리다이렉트 로직
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;

      final isLoggingIn = state.uri.path == '/login';

      // 1. 로그인이 안 되어 있는데, 로그인 페이지가 아니라면 -> 로그인 페이지로 강제 이동
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      // 2. 이미 로그인이 되어 있는데, 로그인 페이지에 있다면 -> 홈(키패드)으로 이동
      if (isLoggedIn && isLoggingIn) {
        return '/';
      }

      // 그 외에는 원래 가려던 곳으로 이동
      return null;
    },
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

/// Supabase 인증 상태 스트림(Stream)을 GoRouter가 감지할 수 있는 Listenable로 변환해주는 클래스
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
