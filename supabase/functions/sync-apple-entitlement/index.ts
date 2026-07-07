import 'jsr:@supabase/functions-js/edge-runtime.d.ts';

import { createClient } from 'npm:@supabase/supabase-js@2.57.4';

import { corsHeaders } from '../_shared/cors.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

type SyncAppleRequest = {
  mode?: 'local_storekit' | 'app_store_server_api';
  planId?: string;
  productId?: string;
  transactionId?: string | null;
  originalTransactionId?: string | null;
  status?: string;
  purchaseDate?: string | null;
  expiresDate?: string | null;
  environmentHint?: string | null;
  verificationData?: Record<string, unknown>;
  signedTransactionInfo?: string | null;
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function isActiveStatus(status: string | undefined) {
  return status === 'active' || status === 'trialing';
}

async function syncLocalStoreKitEntitlement(
  adminClient: ReturnType<typeof createClient>,
  userId: string,
  request: SyncAppleRequest,
) {
  const productId = request.productId;
  const planId =
    request.planId ??
    (productId
      ? await resolvePlanIdFromProduct(adminClient, productId)
      : null);

  if (!planId || !productId) {
    return jsonResponse(
      { error: 'planId or productId could not be resolved for local StoreKit.' },
      400,
    );
  }

  const status = request.status ?? 'active';
  const purchaseDate = request.purchaseDate
    ? new Date(request.purchaseDate).toISOString()
    : new Date().toISOString();
  const expiresDate = request.expiresDate
    ? new Date(request.expiresDate).toISOString()
    : null;
  const providerTransactionId =
    request.transactionId ?? request.originalTransactionId ?? crypto.randomUUID();
  const originalTransactionId =
    request.originalTransactionId ?? request.transactionId ?? providerTransactionId;

  const payload = {
    user_id: userId,
    plan_id: planId,
    provider: 'apple',
    provider_product_id: productId,
    provider_transaction_id: providerTransactionId,
    original_transaction_id: originalTransactionId,
    environment: request.environmentHint ?? 'xcode_storekit',
    verification_status: 'local_unverified',
    entitlement_source: 'local_storekit',
    status,
    current_period_start: purchaseDate,
    current_period_end: expiresDate,
    cancel_at_period_end: false,
    raw: {
      mode: 'local_storekit',
      verificationData: request.verificationData ?? {},
    },
  };

  const { data: existing } = await adminClient
    .from('user_subscriptions')
    .select('id')
    .eq('original_transaction_id', originalTransactionId)
    .maybeSingle();

  if (existing?.id) {
    await adminClient.from('user_subscriptions').update(payload).eq(
      'id',
      existing.id,
    );
  } else {
    await adminClient.from('user_subscriptions').insert(payload);
  }

  return jsonResponse({
    hasActiveSubscription: isActiveStatus(status),
    planId,
    provider: 'apple',
    status,
    currentPeriodEnd: expiresDate,
  });
}

async function resolvePlanIdFromProduct(
  adminClient: ReturnType<typeof createClient>,
  productId: string,
) {
  const { data, error } = await adminClient
    .from('subscription_plans')
    .select('plan_id')
    .eq('apple_product_id', productId)
    .maybeSingle();

  if (error || !data) {
    return null;
  }

  return data.plan_id as string;
}

function productionNotImplementedResponse(request: SyncAppleRequest) {
  return jsonResponse(
    {
      error:
        'Production Apple verification path is prepared but not implemented yet. Use mode=local_storekit for Stage 1 Xcode StoreKit testing.',
      expectedFuturePayload: {
        mode: 'app_store_server_api',
        signedTransactionInfo:
          request.signedTransactionInfo ?? '<signedTransactionInfo>',
        transactionId: request.transactionId ?? '<transactionId>',
      },
    },
    501,
  );
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
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

    const request = (await req.json().catch(() => ({}))) as SyncAppleRequest;
    const mode = request.mode ?? 'local_storekit';

    if (mode === 'local_storekit') {
      return await syncLocalStoreKitEntitlement(adminClient, user.id, request);
    }

    return productionNotImplementedResponse(request);
  } catch (error) {
    console.error('sync-apple-entitlement failed', error);
    return jsonResponse({ error: 'Internal server error.' }, 500);
  }
});
