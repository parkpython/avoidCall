import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BillingService {
  BillingService(this._client);

  final SupabaseClient _client;

  static const String starterPlanId = 'starter';
  static const String corePlanId = 'core';
  static const String operatorPlanId = 'operator';

  static const Map<String, String> applePlanProductIds = {
    starterPlanId: 'com.avoidcall.plan.starter.monthly',
    corePlanId: 'com.avoidcall.plan.core.monthly',
    operatorPlanId: 'com.avoidcall.plan.operator.monthly',
  };

  static const Map<String, String> appleProductPlanIds = {
    'com.avoidcall.plan.starter.monthly': starterPlanId,
    'com.avoidcall.plan.core.monthly': corePlanId,
    'com.avoidcall.plan.operator.monthly': operatorPlanId,
  };

  bool get useAppleIap => Platform.isIOS;

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
          'plan_id, provider, provider_product_id, status, current_period_end, cancel_at_period_end, updated_at, environment',
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

  Future<SubscriptionSyncResult> syncAppleEntitlement(
    PurchaseDetails purchase,
  ) async {
    final status = switch (purchase.status) {
      PurchaseStatus.purchased => 'active',
      PurchaseStatus.restored => 'active',
      PurchaseStatus.pending => 'pending',
      PurchaseStatus.canceled => 'canceled',
      PurchaseStatus.error => 'error',
    };

    final planId = appleProductPlanIds[purchase.productID];
    if (planId == null) {
      throw BillingException('지원하지 않는 Apple 상품입니다: ${purchase.productID}');
    }

    final response = await _client.functions.invoke(
      'sync-apple-entitlement',
      body: {
        'mode': 'local_storekit',
        'planId': planId,
        'productId': purchase.productID,
        'transactionId': purchase.purchaseID,
        'originalTransactionId': purchase.purchaseID,
        'status': status,
        'purchaseDate': purchase.transactionDate,
        'environmentHint': 'xcode_storekit',
        'verificationData': {
          'source': purchase.verificationData.source,
          'localVerificationData':
              purchase.verificationData.localVerificationData,
          'serverVerificationData':
              purchase.verificationData.serverVerificationData,
        },
      },
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
    this.provider,
    this.providerProductId,
    this.environment,
    this.currentPeriodEnd,
    this.updatedAt,
  });

  final String planId;
  final String status;
  final bool cancelAtPeriodEnd;
  final String? provider;
  final String? providerProductId;
  final String? environment;
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
      provider: map['provider'] as String?,
      providerProductId: map['provider_product_id'] as String?,
      environment: map['environment'] as String?,
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
    this.provider,
    this.status,
    this.currentPeriodEnd,
  });

  final bool hasActiveSubscription;
  final String? planId;
  final String? provider;
  final String? status;
  final DateTime? currentPeriodEnd;

  factory SubscriptionSyncResult.fromMap(Map<String, dynamic> map) {
    return SubscriptionSyncResult(
      hasActiveSubscription:
          map['hasActiveSubscription'] as bool? ??
          map['has_active_subscription'] as bool? ??
          false,
      planId: map['planId'] as String? ?? map['plan_id'] as String?,
      provider: map['provider'] as String?,
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
