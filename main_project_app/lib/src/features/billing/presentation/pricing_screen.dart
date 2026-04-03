import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:main_project_app/src/features/billing/application/billing_service.dart';
import 'package:main_project_app/src/features/billing/application/subscription_provider.dart';
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

  @override
  void initState() {
    super.initState();
    final shouldSync =
        widget.checkoutSessionId != null || widget.checkoutState == 'success';
    if (shouldSync) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncSubscription(showSuccessMessage: false);
      });
    }
  }

  Future<void> _startCheckout(String planId) async {
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

  Future<void> _syncSubscription({bool showSuccessMessage = true}) async {
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
    final currentUser = Supabase.instance.client.auth.currentUser;

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
                        onPressed: _isSyncing
                            ? null
                            : () => _syncSubscription(),
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh access'),
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
                    currentUser == null
                        ? '로그인 후 Stripe checkout으로 결제를 시작할 수 있습니다.'
                        : '결제 버튼은 실제 Stripe checkout session을 만들고, 완료 후 Supabase 구독 상태를 동기화합니다.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF5D6571),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  currentSubscription.when(
                    data: (subscription) =>
                        _SubscriptionBanner(subscription: subscription),
                    loading: () =>
                        const _StatusBanner(message: '현재 구독 상태를 확인하고 있습니다.'),
                    error: (_, _) => const _StatusBanner(
                      message:
                          '구독 상태를 불러오지 못했습니다. 결제 후 Refresh access를 눌러 다시 확인하세요.',
                    ),
                  ),
                  const SizedBox(height: 28),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 920;
                      final width = compact ? constraints.maxWidth : 290.0;
                      final activePlanId = currentSubscription.value?.planId;

                      return Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: [
                          _PlanCard(
                            width: width,
                            planId: 'starter',
                            name: 'Starter',
                            price: '\$9',
                            cadence: '/month',
                            description:
                                'For occasional calls and basic voice relay.',
                            features: const [
                              '60 relay minutes',
                              'Realtime transcription',
                              '3 voice presets',
                            ],
                            accent: const Color(0xFFB7C7F4),
                            actionLabel: _actionLabel(
                              currentUser: currentUser,
                              activePlanId: activePlanId,
                              planId: 'starter',
                            ),
                            emphasized: false,
                            isBusy: _busyPlanId == 'starter',
                            isCurrentPlan: activePlanId == 'starter',
                            onPressed: () => _handlePlanTap('starter'),
                          ),
                          _PlanCard(
                            width: width,
                            planId: 'core',
                            name: 'Core',
                            price: '\$24',
                            cadence: '/month',
                            description:
                                'Best fit for frequent personal call mediation.',
                            features: const [
                              '300 relay minutes',
                              'Priority transcription',
                              'Call log export',
                              'Preferred support',
                            ],
                            accent: const Color(0xFF111111),
                            actionLabel: _actionLabel(
                              currentUser: currentUser,
                              activePlanId: activePlanId,
                              planId: 'core',
                            ),
                            emphasized: true,
                            isBusy: _busyPlanId == 'core',
                            isCurrentPlan: activePlanId == 'core',
                            onPressed: () => _handlePlanTap('core'),
                          ),
                          _PlanCard(
                            width: width,
                            planId: 'operator',
                            name: 'Operator',
                            price: '\$59',
                            cadence: '/month',
                            description:
                                'For power users who need high-volume handled calls.',
                            features: const [
                              '1000 relay minutes',
                              'Higher quality voice',
                              'Future team seats',
                              'Priority routing',
                            ],
                            accent: const Color(0xFFD9B37D),
                            actionLabel: _actionLabel(
                              currentUser: currentUser,
                              activePlanId: activePlanId,
                              planId: 'operator',
                            ),
                            emphasized: false,
                            isBusy: _busyPlanId == 'operator',
                            isCurrentPlan: activePlanId == 'operator',
                            onPressed: () => _handlePlanTap('operator'),
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
                                ? 'Need an account before choosing a paid plan?'
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
                              : (_isSyncing ? null : () => _syncSubscription()),
                          child: Text(
                            currentUser == null
                                ? 'Continue to account'
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

    return 'Checkout with Stripe';
  }

  Future<void> _handlePlanTap(String planId) async {
    final activePlanId = ref.read(currentSubscriptionProvider).value?.planId;
    if (activePlanId == planId) {
      return;
    }
    await _startCheckout(planId);
  }
}

class _SubscriptionBanner extends StatelessWidget {
  const _SubscriptionBanner({required this.subscription});

  final SubscriptionSnapshot? subscription;

  @override
  Widget build(BuildContext context) {
    if (subscription == null) {
      return const _StatusBanner(
        message: '아직 활성 플랜이 없습니다. 결제 후 access를 새로고침하면 즉시 반영됩니다.',
      );
    }

    final end = subscription!.currentPeriodEnd;
    final periodText = end == null
        ? '만료일 없음'
        : '${end.year}.${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')}';

    return _StatusBanner(
      backgroundColor: subscription!.isActive
          ? const Color(0xFFE8F5EE)
          : const Color(0xFFF7EAD8),
      message:
          '현재 플랜: ${subscription!.planId} · 상태: ${subscription!.status} · 종료일: $periodText',
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
    required this.planId,
    required this.name,
    required this.price,
    required this.cadence,
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
  final String planId;
  final String name;
  final String price;
  final String cadence;
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
          RichText(
            text: TextSpan(
              text: price,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
              children: [
                TextSpan(
                  text: cadence,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: emphasized
                        ? Colors.white.withValues(alpha: 0.78)
                        : const Color(0xFF59606B),
                  ),
                ),
              ],
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
