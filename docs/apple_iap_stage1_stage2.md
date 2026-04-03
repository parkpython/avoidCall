# Apple IAP rollout

## Stage 1: Local StoreKit testing in Xcode

Implemented now:

- `main_project_app/ios/Runner/LocalStoreKit.storekit` contains three local auto-renewable subscription products
- `main_project_app/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` points the shared Runner scheme at that `.storekit` file
- iOS pricing flow uses Flutter `in_app_purchase` instead of Stripe
- purchase updates and restore updates sync entitlement state into Supabase through `sync-apple-entitlement`
- paywall routing still reads the common Supabase `has_active_subscription()` function, so Apple and Stripe share the same gate

Local product IDs:

- `com.avoidcall.plan.starter.monthly`
- `com.avoidcall.plan.core.monthly`
- `com.avoidcall.plan.operator.monthly`

How to test locally in Xcode:

1. Open `main_project_app/ios/Runner.xcworkspace` in Xcode.
2. Select the shared `Runner` scheme.
3. Confirm `Product > Scheme > Edit Scheme > Run > Options` shows `LocalStoreKit.storekit`.
4. Run the app on an iPhone simulator or device from Xcode.
5. Sign in inside the app.
6. Open `/pricing`, buy a plan, then verify the app routes to `/home`.
7. Use `Restore purchases` to verify restore flow after reinstall or entitlement reset.

Current local-only entitlement sync path:

- The Supabase function `sync-apple-entitlement` accepts `mode=local_storekit`
- In this mode, the function trusts Xcode StoreKit test purchase metadata sent by the app and writes `provider='apple'`, `environment='xcode_storekit'`
- This path is intentionally isolated from the future production verification path

## Stage 2: App Store Connect / Sandbox / TestFlight

Prepared but not fully implemented yet:

- `subscription_plans.apple_product_id` already exists and is populated with stable product IDs
- `user_subscriptions` now stores generic provider fields:
  - `provider`
  - `provider_product_id`
  - `provider_transaction_id`
  - `original_transaction_id`
  - `environment`
  - `verification_status`
  - `entitlement_source`
- `sync-apple-entitlement` is the server interface that should own the future production verification path

Still required later in App Store Connect:

1. Create the app record and enable In-App Purchase capability.
2. Create the three auto-renewable subscriptions with the same product IDs.
3. Create a subscription group matching the local StoreKit setup.
4. Fill pricing, localizations, review metadata, and screenshots.
5. Configure Sandbox testers and/or TestFlight distribution.
6. Generate App Store Server API credentials:
   - Issuer ID
   - Key ID
   - private key `.p8`
7. Configure server env vars for Apple verification on Supabase Edge Functions.
8. Add App Store Server Notifications if you want renewal/cancel/refund events pushed server-to-server.

Planned production verification structure:

- App sends signed transaction data or transaction ID to `sync-apple-entitlement`
- Supabase function verifies against Apple App Store Server API
- Server resolves the authoritative subscription state
- Server upserts the shared `user_subscriptions` table
- Router/paywall remains unchanged because it already depends on common entitlement state

Apple-recommended server-side direction to use later:

- App Store Server API
- signed transaction payloads
- server-to-server notifications for ongoing lifecycle sync
