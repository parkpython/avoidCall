import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

import Stripe from 'npm:stripe@17.7.0';
import { createClient } from 'npm:@supabase/supabase-js@2.57.4';

import { corsHeaders } from '../_shared/cors.ts';

const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY');
const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const stripe = new Stripe(stripeSecretKey ?? '', {
  apiVersion: '2025-02-24.acacia',
});

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function resolvePlanId(
  subscription: Stripe.Subscription,
  pricePlanMap: Map<string, string>,
) {
  const metadataPlanId = subscription.metadata?.plan_id;
  if (metadataPlanId) {
    return metadataPlanId;
  }

  const firstPriceId = subscription.items.data[0]?.price?.id;
  if (firstPriceId && pricePlanMap.has(firstPriceId)) {
    return pricePlanMap.get(firstPriceId) ?? null;
  }

  return null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (!stripeSecretKey) {
      return jsonResponse({ error: 'STRIPE_SECRET_KEY is not configured.' }, 500);
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return jsonResponse({ error: 'Missing Authorization header.' }, 401);
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey);

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse({ error: 'Unauthorized user.' }, 401);
    }

    const payload = await req.json().catch(() => ({}));
    const sessionId =
      payload && typeof payload.sessionId == 'string' ? payload.sessionId : null;

    const { data: profile } = await adminClient
      .from('profiles')
      .select('stripe_customer_id')
      .eq('id', user.id)
      .maybeSingle();

    const stripeCustomerId = profile?.stripe_customer_id as string | null;
    if (!stripeCustomerId) {
      return jsonResponse({ hasActiveSubscription: false });
    }

    const { data: plans, error: planError } = await adminClient
      .from('subscription_plans')
      .select('plan_id, stripe_price_id');

    if (planError) {
      return jsonResponse({ error: planError.message }, 500);
    }

    const pricePlanMap = new Map<string, string>();
    for (const plan of plans ?? []) {
      if (plan.stripe_price_id) {
        pricePlanMap.set(plan.stripe_price_id as string, plan.plan_id as string);
      }
    }

    let targetSubscription: Stripe.Subscription | null = null;
    let targetCheckoutSessionId: string | null = sessionId;

    if (sessionId) {
      const checkoutSession = await stripe.checkout.sessions.retrieve(sessionId, {
        expand: ['subscription'],
      });
      targetCheckoutSessionId = checkoutSession.id;

      if (
        checkoutSession.subscription &&
        typeof checkoutSession.subscription !== 'string'
      ) {
        targetSubscription = checkoutSession.subscription;
      }

      await adminClient
        .from('stripe_checkout_sessions')
        .update({
          status: checkoutSession.status ?? 'complete',
          completed_at:
            checkoutSession.status == 'complete'
                ? new Date().toISOString()
                : null,
          raw: checkoutSession,
        })
        .eq('stripe_checkout_session_id', checkoutSession.id)
        .eq('user_id', user.id);
    }

    if (!targetSubscription) {
      const subscriptions = await stripe.subscriptions.list({
        customer: stripeCustomerId,
        status: 'all',
        limit: 10,
      });

      let newestActive: Stripe.Subscription | null = null;
      for (const item of subscriptions.data) {
        if (item.status !== 'active' && item.status !== 'trialing') {
          continue;
        }

        if (!newestActive) {
          newestActive = item;
          continue;
        }

        const currentCreated = newestActive.created ?? 0;
        const nextCreated = item.created ?? 0;
        if (nextCreated >= currentCreated) {
          newestActive = item;
        }
      }

      targetSubscription =
        newestActive ?? (subscriptions.data.length > 0 ? subscriptions.data[0] : null);
    }

    if (targetSubscription == null) {
      return jsonResponse({ hasActiveSubscription: false });
    }

    const planId = resolvePlanId(targetSubscription, pricePlanMap);
    if (!planId) {
      return jsonResponse({
        error:
          'Could not resolve plan_id from Stripe subscription. Check subscription_plans.stripe_price_id values.',
      }, 400);
    }

    await adminClient.from('user_subscriptions').upsert(
      {
        user_id: user.id,
        plan_id: planId,
        stripe_customer_id: stripeCustomerId,
        stripe_subscription_id: targetSubscription.id,
        stripe_price_id: targetSubscription.items.data[0]?.price?.id ?? null,
        stripe_checkout_session_id: targetCheckoutSessionId,
        status: targetSubscription.status,
        current_period_start: targetSubscription.current_period_start
          ? new Date(targetSubscription.current_period_start * 1000).toISOString()
          : null,
        current_period_end: targetSubscription.current_period_end
          ? new Date(targetSubscription.current_period_end * 1000).toISOString()
          : null,
        cancel_at_period_end: targetSubscription.cancel_at_period_end ?? false,
        raw: targetSubscription,
      },
      { onConflict: 'stripe_subscription_id' },
    );

    return jsonResponse({
      hasActiveSubscription:
        targetSubscription.status == 'active' ||
        targetSubscription.status == 'trialing',
      planId,
      status: targetSubscription.status,
      currentPeriodEnd: targetSubscription.current_period_end
        ? new Date(targetSubscription.current_period_end * 1000).toISOString()
        : null,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return jsonResponse({ error: message }, 500);
  }
});
