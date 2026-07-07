import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

import Stripe from 'npm:stripe@17.7.0';
import { createClient } from 'npm:@supabase/supabase-js@2.57.4';

import { corsHeaders } from '../_shared/cors.ts';

const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY');
const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const checkoutSuccessUrl =
  Deno.env.get('STRIPE_CHECKOUT_SUCCESS_URL') ??
  'https://example.com/pricing?checkout=success&session_id={CHECKOUT_SESSION_ID}';
const checkoutCancelUrl =
  Deno.env.get('STRIPE_CHECKOUT_CANCEL_URL') ??
  'https://example.com/pricing?checkout=cancelled';

if (!stripeSecretKey) {
  console.error('Missing STRIPE_SECRET_KEY');
}

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

    const { planId } = await req.json();
    if (typeof planId !== 'string' || planId.length === 0) {
      return jsonResponse({ error: 'planId is required.' }, 400);
    }

    const { data: plan, error: planError } = await adminClient
      .from('subscription_plans')
      .select('plan_id, stripe_price_id, is_active')
      .eq('plan_id', planId)
      .eq('is_active', true)
      .maybeSingle();

    if (planError || !plan) {
      return jsonResponse({ error: 'Requested plan was not found.' }, 404);
    }

    if (!plan.stripe_price_id) {
      return jsonResponse(
        {
          error:
            'This plan is missing stripe_price_id. Update subscription_plans first.',
        },
        400,
      );
    }

    const { data: profile } = await adminClient
      .from('profiles')
      .select('stripe_customer_id, email')
      .eq('id', user.id)
      .maybeSingle();

    let stripeCustomerId = profile?.stripe_customer_id as string | null;

    if (!stripeCustomerId) {
      const customer = await stripe.customers.create({
        email: user.email ?? profile?.email ?? undefined,
        metadata: {
          user_id: user.id,
        },
      });
      stripeCustomerId = customer.id;

      await adminClient.from('profiles').upsert({
        id: user.id,
        email: user.email ?? profile?.email ?? null,
        stripe_customer_id: stripeCustomerId,
      });
    }

    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      customer: stripeCustomerId,
      line_items: [{ price: plan.stripe_price_id, quantity: 1 }],
      success_url: checkoutSuccessUrl,
      cancel_url: checkoutCancelUrl,
      client_reference_id: user.id,
      metadata: {
        user_id: user.id,
        plan_id: plan.plan_id,
      },
      subscription_data: {
        metadata: {
          user_id: user.id,
          plan_id: plan.plan_id,
        },
      },
    });

    await adminClient.from('stripe_checkout_sessions').insert({
      user_id: user.id,
      plan_id: plan.plan_id,
      stripe_customer_id: stripeCustomerId,
      stripe_checkout_session_id: session.id,
      checkout_url: session.url,
      status: session.status ?? 'open',
      expires_at: session.expires_at
        ? new Date(session.expires_at * 1000).toISOString()
        : null,
      raw: session,
    });

    return jsonResponse({
      url: session.url,
      sessionId: session.id,
    });
  } catch (error) {
    console.error('create-checkout-session failed', error);
    return jsonResponse({ error: 'Internal server error.' }, 500);
  }
});
