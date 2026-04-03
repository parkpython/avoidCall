import 'package:supabase_flutter/supabase_flutter.dart';

class BillingService {
  BillingService(this._client);

  final SupabaseClient _client;

  Future<bool> hasActiveSubscription() async {
    final response = await _client.rpc('has_active_subscription');
    return response == true;
  }

  Future<SubscriptionSnapshot?> fetchCurrentSubscription() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    final row = await _client
        .from('user_subscriptions')
        .select(
          'plan_id, status, current_period_end, cancel_at_period_end, updated_at',
        )
        .eq('user_id', user.id)
        .order('current_period_end', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return SubscriptionSnapshot.fromMap(row);
  }

  Future<CheckoutLaunchResult> createCheckoutSession(String planId) async {
    final response = await _client.functions.invoke(
      'create-checkout-session',
      body: {'planId': planId},
    );

    final data = response.data;
    if (response.status != 200 || data is! Map<String, dynamic>) {
      throw BillingException(_extractErrorMessage(data, response.status));
    }

    final url = data['url'] as String?;
    final sessionId = data['sessionId'] as String?;
    if (url == null || url.isEmpty) {
      throw const BillingException('Stripe checkout URL을 받지 못했습니다.');
    }

    return CheckoutLaunchResult(url: url, sessionId: sessionId);
  }

  Future<SubscriptionSyncResult> syncSubscription({String? sessionId}) async {
    final response = await _client.functions.invoke(
      'sync-my-subscription',
      body: {'sessionId': sessionId},
    );

    final data = response.data;
    if (response.status != 200 || data is! Map<String, dynamic>) {
      throw BillingException(_extractErrorMessage(data, response.status));
    }

    return SubscriptionSyncResult.fromMap(data);
  }

  String _extractErrorMessage(dynamic data, int status) {
    if (data is Map<String, dynamic>) {
      final error = data['error'] ?? data['message'];
      if (error is String && error.isNotEmpty) {
        return error;
      }
    }
    return '결제 요청에 실패했습니다. (HTTP $status)';
  }
}

class SubscriptionSnapshot {
  const SubscriptionSnapshot({
    required this.planId,
    required this.status,
    required this.cancelAtPeriodEnd,
    this.currentPeriodEnd,
    this.updatedAt,
  });

  final String planId;
  final String status;
  final bool cancelAtPeriodEnd;
  final DateTime? currentPeriodEnd;
  final DateTime? updatedAt;

  bool get isActive =>
      (status == 'active' || status == 'trialing') &&
      (currentPeriodEnd == null || currentPeriodEnd!.isAfter(DateTime.now()));

  factory SubscriptionSnapshot.fromMap(Map<String, dynamic> map) {
    return SubscriptionSnapshot(
      planId: map['plan_id'] as String? ?? '',
      status: map['status'] as String? ?? 'inactive',
      cancelAtPeriodEnd: map['cancel_at_period_end'] as bool? ?? false,
      currentPeriodEnd: _parseDateTime(map['current_period_end']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}

class CheckoutLaunchResult {
  const CheckoutLaunchResult({required this.url, this.sessionId});

  final String url;
  final String? sessionId;
}

class SubscriptionSyncResult {
  const SubscriptionSyncResult({
    required this.hasActiveSubscription,
    this.planId,
    this.status,
    this.currentPeriodEnd,
  });

  final bool hasActiveSubscription;
  final String? planId;
  final String? status;
  final DateTime? currentPeriodEnd;

  factory SubscriptionSyncResult.fromMap(Map<String, dynamic> map) {
    return SubscriptionSyncResult(
      hasActiveSubscription:
          map['hasActiveSubscription'] as bool? ??
          map['has_active_subscription'] as bool? ??
          false,
      planId: map['planId'] as String? ?? map['plan_id'] as String?,
      status: map['status'] as String?,
      currentPeriodEnd: SubscriptionSnapshot._parseDateTime(
        map['currentPeriodEnd'] ?? map['current_period_end'],
      ),
    );
  }
}

class BillingException implements Exception {
  const BillingException(this.message);

  final String message;

  @override
  String toString() => message;
}
