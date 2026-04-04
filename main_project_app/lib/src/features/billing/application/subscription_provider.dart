import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:main_project_app/src/core/providers/supabase_provider.dart';
import 'package:main_project_app/src/features/billing/application/apple_iap_service.dart';
import 'package:main_project_app/src/features/billing/application/billing_service.dart';
import 'package:main_project_app/src/features/incall/presentation/auth_provider.dart';

final billingServiceProvider = Provider<BillingService>((ref) {
  return BillingService(ref.watch(supabaseProvider));
});

final appleIapServiceProvider = Provider<AppleIapService>((ref) {
  return AppleIapService();
});

final currentSubscriptionProvider = FutureProvider<SubscriptionSnapshot?>((
  ref,
) async {
  final session = ref.watch(sessionProvider);
  if (session == null) {
    return null;
  }
  final billingService = ref.watch(billingServiceProvider);
  return billingService.fetchCurrentSubscription();
});

final hasActiveSubscriptionProvider = FutureProvider<bool>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) {
    return false;
  }
  final billingService = ref.watch(billingServiceProvider);
  return billingService.hasActiveSubscription();
});
