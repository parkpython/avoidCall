import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:main_project_app/src/features/billing/application/billing_service.dart';
import 'package:main_project_app/src/features/billing/application/subscription_provider.dart';
import 'package:main_project_app/src/features/incall/presentation/auth_provider.dart';

// Screens
import 'package:main_project_app/src/core/routing/scaffold_with_nav_bar.dart';
import 'package:main_project_app/src/features/auth/presentation/login_screen.dart';
import 'package:main_project_app/src/features/billing/presentation/pricing_screen.dart';
import 'package:main_project_app/src/features/landing/presentation/landing_screen.dart';
import 'package:main_project_app/src/features/incall/presentation/in_call_screen.dart';
import 'package:main_project_app/src/features/home/presentation/home_screen.dart';
import 'package:main_project_app/src/features/keypad/presentation/keypad_screen.dart';
import 'package:main_project_app/src/features/settings/presentation/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final billingService = ref.read(billingServiceProvider);
  final session = ref.watch(sessionProvider);
  final authRefresh = GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  );

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: authRefresh,
    redirect: (context, state) async {
      final loggedIn = session != null;
      final location = state.matchedLocation;
      const publicRoutes = {'/', '/login', '/pricing'};

      if (!loggedIn && !publicRoutes.contains(location)) {
        return '/login';
      }

      if (!loggedIn) {
        return null;
      }

      final hasActiveSubscription = await _safeHasActiveSubscription(
        billingService,
      );

      if (location == '/' || location == '/login') {
        return hasActiveSubscription ? '/home' : '/pricing';
      }

      if (!hasActiveSubscription && location != '/pricing') {
        return '/pricing';
      }

      if (hasActiveSubscription && location == '/pricing') {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/pricing',
        builder: (context, state) => PricingScreen(
          checkoutSessionId: state.uri.queryParameters['session_id'],
          checkoutState: state.uri.queryParameters['checkout'],
        ),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/keypad',
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

Future<bool> _safeHasActiveSubscription(BillingService billingService) async {
  try {
    return await billingService.hasActiveSubscription();
  } catch (_) {
    return false;
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
