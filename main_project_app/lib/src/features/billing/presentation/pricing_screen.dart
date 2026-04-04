import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:main_project_app/src/features/billing/application/apple_iap_service.dart';
import 'package:main_project_app/src/features/billing/application/billing_service.dart';
import 'package:main_project_app/src/features/billing/application/subscription_provider.dart';
import 'package:main_project_app/src/features/incall/presentation/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PricingScreen extends ConsumerStatefulWidget {
  const PricingScreen({super.key, this.checkoutSessionId, this.checkoutState});

  final String? checkoutSessionId;
  final String? checkoutState;

  @override
  ConsumerState<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends ConsumerState<PricingScreen> {
  String? _busyPlanId;
  bool _isSyncing = false;
  bool _isRestoring = false;
  AppleIapCatalog? _catalog;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool get _useAppleIap => Platform.isIOS;

  @override
  void initState() {
    super.initState();

    if (_useAppleIap) {
      _purchaseSubscription = ref
          .read(appleIapServiceProvider)
          .purchaseStream
          .listen(_handlePurchaseUpdates);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAppleCatalog();
      });
    } else {
      final shouldSync =
          widget.checkoutSessionId != null || widget.checkoutState == 'success';
      if (shouldSync) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _syncStripeSubscription(showSuccessMessage: false);
        });
      }
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAppleCatalog() async {
    try {
      final catalog = await ref
          .read(appleIapServiceProvider)
          .loadCatalog(BillingService.applePlanProductIds.values.toSet());
      if (mounted) {
        setState(() {
          _catalog = catalog;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상품 불러오기 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!mounted) {
        return;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Apple 결제 승인 대기 중입니다.')));
          break;
        case PurchaseStatus.error:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                purchase.error?.message ?? 'Apple 결제 처리 중 오류가 발생했습니다.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          break;
        case PurchaseStatus.canceled:
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('구매가 취소되었습니다.')));
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _syncApplePurchase(purchase);
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await ref.read(appleIapServiceProvider).completePurchase(purchase);
      }
    }
  }

  Future<void> _syncApplePurchase(PurchaseDetails purchase) async {
    try {
      final result = await ref
          .read(billingServiceProvider)
          .syncAppleEntitlement(purchase);

      ref.invalidate(currentSubscriptionProvider);
      ref.invalidate(hasActiveSubscriptionProvider);

      if (!mounted) {
        return;
      }

      if (result.hasActiveSubscription) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              purchase.status == PurchaseStatus.restored
                  ? '구매 내역을 복원했습니다.'
                  : 'Apple 구독이 활성화되었습니다.',
            ),
            backgroundColor: const Color(0xFF1D7B61),
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구독 동기화 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyPlanId = null;
          _isRestoring = false;
        });
      }
    }
  }

  Future<void> _startApplePurchase(String planId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      context.go('/login');
      return;
    }

    final catalog = _catalog;
    if (catalog == null || !catalog.isStoreAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('StoreKit 상품이 아직 준비되지 않았습니다.')),
      );
      return;
    }

    final productId = BillingService.applePlanProductIds[planId];
    final product = catalog.products
        .where((item) => item.id == productId)
        .cast<ProductDetails?>()
        .firstOrNull;

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이 플랜의 StoreKit 상품을 찾지 못했습니다. .storekit 설정을 확인하세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _busyPlanId = planId;
    });

    try {
      await ref
          .read(appleIapServiceProvider)
          .buySubscription(
            product: product,
            applicationUserName: currentUser.id,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구매 시작 실패: $e'), backgroundColor: Colors.red),
        );
        setState(() {
          _busyPlanId = null;
        });
      }
    }
  }

  Future<void> _restoreApplePurchases() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      context.go('/login');
      return;
    }

    setState(() {
      _isRestoring = true;
    });

    try {
      await ref
          .read(appleIapServiceProvider)
          .restorePurchases(applicationUserName: currentUser.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('복원 실패: $e'), backgroundColor: Colors.red),
        );
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  Future<void> _startStripeCheckout(String planId) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      context.go('/login');
      return;
    }

    setState(() {
      _busyPlanId = planId;
    });

    try {
      final result = await ref
          .read(billingServiceProvider)
          .createCheckoutSession(planId);
      final launched = await launchUrl(
        Uri.parse(result.url),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('체크아웃 URL을 열지 못했습니다.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stripe 결제창을 열었습니다. 결제 후 앱으로 돌아와 접근 상태를 새로고침하세요.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('결제 시작 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyPlanId = null;
        });
      }
    }
  }

  Future<void> _syncStripeSubscription({bool showSuccessMessage = true}) async {
    if (_isSyncing) {
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await ref
          .read(billingServiceProvider)
          .syncSubscription(sessionId: widget.checkoutSessionId);

      ref.invalidate(currentSubscriptionProvider);
      ref.invalidate(hasActiveSubscriptionProvider);

      if (!mounted) {
        return;
      }

      if (result.hasActiveSubscription) {
        if (showSuccessMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('구독 상태가 확인되었습니다. 홈으로 이동합니다.'),
              backgroundColor: Color(0xFF1D7B61),
            ),
          );
        }
        context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('활성 구독을 아직 찾지 못했습니다. 결제가 끝난 뒤 다시 새로고침하세요.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구독 동기화 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSubscription = ref.watch(currentSubscriptionProvider);
    final currentUser = ref.watch(userProvider);
    final activePlanId = currentSubscription.value?.planId;
    final helperText = _useAppleIap
        ? 'iOS에서는 Xcode StoreKit Testing으로 로컬 구매/복원/entitlement sync를 테스트합니다.'
        : '기타 플랫폼은 기존 Stripe checkout 흐름을 사용합니다.';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Plans',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: _useAppleIap
                            ? (_isRestoring ? null : _restoreApplePurchases)
                            : (_isSyncing
                                  ? null
                                  : () => _syncStripeSubscription()),
                        icon: _useAppleIap
                            ? (_isRestoring
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.settings_backup_restore))
                            : (_isSyncing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded)),
                        label: Text(
                          _useAppleIap ? 'Restore purchases' : 'Refresh access',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Choose how much call coverage you need.',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF171717),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    helperText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF5D6571),
                      height: 1.45,
                    ),
                  ),
                  if (_useAppleIap) ...[
                    const SizedBox(height: 16),
                    _AppleTestingBanner(catalog: _catalog),
                  ],
                  const SizedBox(height: 24),
                  currentSubscription.when(
                    data: (subscription) =>
                        _SubscriptionBanner(subscription: subscription),
                    loading: () =>
                        const _StatusBanner(message: '현재 구독 상태를 확인하고 있습니다.'),
                    error: (_, _) => const _StatusBanner(
                      message: '구독 상태를 불러오지 못했습니다. 결제 후 access 상태를 다시 확인하세요.',
                    ),
                  ),
                  const SizedBox(height: 28),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 920;
                      final width = compact ? constraints.maxWidth : 290.0;
                      return Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: [
                          _PlanCard(
                            width: width,
                            name: 'Starter',
                            price: _displayPrice(
                              fallback: '\$9/month',
                              productId:
                                  BillingService
                                      .applePlanProductIds[BillingService
                                      .starterPlanId]!,
                            ),
                            description:
                                'For occasional calls and basic voice relay.',
                            features: const [
                              '60 relay minutes',
                              'Realtime transcription',
                              '3 voice presets',
                            ],
                            accent: const Color(0xFFB7C7F4),
                            emphasized: false,
                            actionLabel: _actionLabel(
                              currentUser: currentUser,
                              activePlanId: activePlanId,
                              planId: BillingService.starterPlanId,
                            ),
                            isBusy: _busyPlanId == BillingService.starterPlanId,
                            isCurrentPlan:
                                activePlanId == BillingService.starterPlanId,
                            onPressed: () =>
                                _handlePlanTap(BillingService.starterPlanId),
                          ),
                          _PlanCard(
                            width: width,
                            name: 'Core',
                            price: _displayPrice(
                              fallback: '\$24/month',
                              productId:
                                  BillingService
                                      .applePlanProductIds[BillingService
                                      .corePlanId]!,
                            ),
                            description:
                                'Best fit for frequent personal call mediation.',
                            features: const [
                              '300 relay minutes',
                              'Priority transcription',
                              'Call log export',
                              'Preferred support',
                            ],
                            accent: const Color(0xFF111111),
                            emphasized: true,
                            actionLabel: _actionLabel(
                              currentUser: currentUser,
                              activePlanId: activePlanId,
                              planId: BillingService.corePlanId,
                            ),
                            isBusy: _busyPlanId == BillingService.corePlanId,
                            isCurrentPlan:
                                activePlanId == BillingService.corePlanId,
                            onPressed: () =>
                                _handlePlanTap(BillingService.corePlanId),
                          ),
                          _PlanCard(
                            width: width,
                            name: 'Operator',
                            price: _displayPrice(
                              fallback: '\$59/month',
                              productId:
                                  BillingService
                                      .applePlanProductIds[BillingService
                                      .operatorPlanId]!,
                            ),
                            description:
                                'For power users who need high-volume handled calls.',
                            features: const [
                              '1000 relay minutes',
                              'Higher quality voice',
                              'Future team seats',
                              'Priority routing',
                            ],
                            accent: const Color(0xFFD9B37D),
                            emphasized: false,
                            actionLabel: _actionLabel(
                              currentUser: currentUser,
                              activePlanId: activePlanId,
                              planId: BillingService.operatorPlanId,
                            ),
                            isBusy:
                                _busyPlanId == BillingService.operatorPlanId,
                            isCurrentPlan:
                                activePlanId == BillingService.operatorPlanId,
                            onPressed: () =>
                                _handlePlanTap(BillingService.operatorPlanId),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            currentUser == null
                                ? 'Need an account before choosing a plan?'
                                : _useAppleIap
                                ? 'Local StoreKit purchase not reflected yet? Use Restore purchases or relaunch after syncing.'
                                : 'Finished checkout in the browser? Refresh your billing access here.',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: currentUser == null
                              ? () => context.go('/login')
                              : (_useAppleIap
                                    ? (_isRestoring
                                          ? null
                                          : _restoreApplePurchases)
                                    : (_isSyncing
                                          ? null
                                          : () => _syncStripeSubscription())),
                          child: Text(
                            currentUser == null
                                ? 'Continue to account'
                                : _useAppleIap
                                ? 'Restore purchases'
                                : 'Refresh access',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _displayPrice({required String fallback, required String productId}) {
    if (!_useAppleIap || _catalog == null) {
      return fallback;
    }

    final product = _catalog!.products
        .where((item) => item.id == productId)
        .cast<ProductDetails?>()
        .firstOrNull;
    return product?.price ?? fallback;
  }

  String _actionLabel({
    required User? currentUser,
    required String? activePlanId,
    required String planId,
  }) {
    if (currentUser == null) {
      return 'Sign in to continue';
    }

    if (activePlanId == planId) {
      return 'Current plan';
    }

    return _useAppleIap ? 'Buy with Apple' : 'Checkout with Stripe';
  }

  Future<void> _handlePlanTap(String planId) async {
    final activePlanId = ref.read(currentSubscriptionProvider).value?.planId;
    if (activePlanId == planId) {
      return;
    }

    if (_useAppleIap) {
      await _startApplePurchase(planId);
      return;
    }

    await _startStripeCheckout(planId);
  }
}

class _AppleTestingBanner extends StatelessWidget {
  const _AppleTestingBanner({required this.catalog});

  final AppleIapCatalog? catalog;

  @override
  Widget build(BuildContext context) {
    final message = switch (catalog) {
      null => 'StoreKit catalog를 불러오는 중입니다.',
      AppleIapCatalog(isStoreAvailable: false) =>
        '이 기기에서는 App Store / StoreKit을 사용할 수 없습니다.',
      _ when catalog!.notFoundIds.isNotEmpty =>
        '.storekit 파일에 없는 상품이 있습니다: ${catalog!.notFoundIds.join(', ')}',
      _ => 'Xcode Scheme에서 LocalStoreKit.storekit을 선택하면 로컬 테스트 구매가 동작합니다.',
    };

    return _StatusBanner(
      backgroundColor: const Color(0xFFE8EEF9),
      message: message,
    );
  }
}

class _SubscriptionBanner extends StatelessWidget {
  const _SubscriptionBanner({required this.subscription});

  final SubscriptionSnapshot? subscription;

  @override
  Widget build(BuildContext context) {
    if (subscription == null) {
      return const _StatusBanner(
        message: '아직 활성 플랜이 없습니다. 구매 또는 복원 후 access가 즉시 반영됩니다.',
      );
    }

    final end = subscription!.currentPeriodEnd;
    final periodText = end == null
        ? '만료일 없음'
        : '${end.year}.${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')}';
    final providerText = subscription!.provider ?? 'unknown';
    final environmentText = subscription!.environment ?? 'n/a';

    return _StatusBanner(
      backgroundColor: subscription!.isActive
          ? const Color(0xFFE8F5EE)
          : const Color(0xFFF7EAD8),
      message:
          '현재 플랜: ${subscription!.planId} · 상태: ${subscription!.status} · 제공자: $providerText · 환경: $environmentText · 종료일: $periodText',
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    this.backgroundColor = const Color(0xFFFFFFFF),
  });

  final String message;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.width,
    required this.name,
    required this.price,
    required this.description,
    required this.features,
    required this.accent,
    required this.actionLabel,
    required this.onPressed,
    required this.isBusy,
    required this.isCurrentPlan,
    this.emphasized = false,
  });

  final double width;
  final String name;
  final String price;
  final String description;
  final List<String> features;
  final Color accent;
  final String actionLabel;
  final VoidCallback onPressed;
  final bool isBusy;
  final bool isCurrentPlan;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final foreground = emphasized ? Colors.white : const Color(0xFF171717);
    final background = emphasized ? accent : Colors.white;

    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
        boxShadow: emphasized
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 26,
                  offset: const Offset(0, 18),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (emphasized)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Most practical',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (emphasized) const SizedBox(height: 18),
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            price,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.45,
              color: emphasized
                  ? Colors.white.withValues(alpha: 0.82)
                  : const Color(0xFF59606B),
            ),
          ),
          const SizedBox(height: 18),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: emphasized
                        ? const Color(0xFFF3DCA1)
                        : const Color(0xFF2C6C4E),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(feature, style: TextStyle(color: foreground)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: emphasized
                ? FilledButton(
                    onPressed: isBusy || isCurrentPlan ? null : onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF0E7D4),
                      foregroundColor: const Color(0xFF171717),
                    ),
                    child: isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(actionLabel),
                  )
                : OutlinedButton(
                    onPressed: isBusy || isCurrentPlan ? null : onPressed,
                    child: isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(actionLabel),
                  ),
          ),
        ],
      ),
    );
  }
}
