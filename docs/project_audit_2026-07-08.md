# Project Audit - 2026-07-08

Scope: current repository state, Fly.io production backend, Flutter app
configuration, backend security controls, secrets handling, tests, and known
remaining risks.

## Executive Summary

- Production backend is deployed on Fly.io at `https://avoid-call-backend.fly.dev`.
- Fly Machine is running in `nrt` with 1/1 health check passing.
- `/healthz` returns `200 OK` with `local_test_mode=false`.
- Flutter local `.env` now points at the Fly production backend.
- Backend authentication is enforced in production.
- Twilio webhook signature validation is enabled in production.
- Supabase backend secret deployment was initially wrong, then fixed during this
  audit. Invalid bearer tokens now return `401` instead of auth-service `503`.
- Python syntax check, Flutter analyzer, Flutter tests, and Python dependency
  vulnerability scan passed.

## Production Backend Status

Current Fly app:

```text
app: avoid-call-backend
url: https://avoid-call-backend.fly.dev
region: nrt
machine count: 1
machine size: shared-cpu-1x:1024MB
state: started
checks: 1/1 passing
current release: v5 complete
```

Health check evidence:

```text
GET https://avoid-call-backend.fly.dev/healthz -> 200
{"status":"ok","service":"avoid-call-backend","local_test_mode":false,"local_outbound_calls":false}
```

Auth behavior evidence:

```text
POST /prefetch without Authorization -> 401 Missing bearer token
POST /prefetch with invalid bearer token -> 401 Invalid or expired access token
```

## Files Added Or Changed

Tracked or pending source changes:

- `fly.toml`: Fly production deployment config.
- `.dockerignore`: excludes env files, Flutter build artifacts, venvs, demo folders, and other non-runtime files from Docker context.
- `scripts/start_service.sh`: only prepares `/data/openclaw-ops` when running `APP_MODULE=openclaw_ops:app`; this fixed Fly startup permission failure for the main backend.
- `docs/fly_deployment.md`: initial Fly deployment guide.
- `docs/fly_operations.md`: ongoing operations guide.

Local ignored environment files:

- `main_project_app/.env` now targets Fly production.
- `backend/.env` remains local-test oriented and has empty Supabase values.
- `backend/.env.backup.local` service role value was cleared during this audit
  after being migrated to Fly Secrets.

## Backend Security Review

Production controls currently present:

- `ENVIRONMENT=production` disables FastAPI docs/openapi/redoc.
- `LOCAL_TEST_MODE=false` means production auth path is used.
- `ALLOW_UNAUTHENTICATED_REQUESTS=false` in `fly.toml`.
- HTTP endpoints `/call`, `/prefetch`, `/preview-voice` require Supabase bearer auth.
- `/call` enforces authenticated user ownership against request `user_id`.
- App WebSocket authenticates with bearer token, subprotocol token, or query token.
- App WebSocket checks call ownership in production.
- Twilio `/voice/{call_id}` and `/incoming` require Twilio signature validation.
- Request body size is capped by `MAX_REQUEST_BODY_BYTES=65536`.
- Pydantic request models forbid extra fields and validate:
  - E.164 phone numbers
  - supported languages
  - supported voices
  - max text lengths
  - control characters
- Security headers are set:
  - `X-Content-Type-Options`
  - `X-Frame-Options`
  - `Referrer-Policy`
  - `Permissions-Policy`
  - `Strict-Transport-Security` in production
- Rate limiting exists for authenticated identities:
  - `/call`: 5/minute
  - `/prefetch`: 60/minute
  - `/preview-voice`: 30/minute

Security gaps / risks:

- Rate limiting is in-process memory only. This is fine for one Machine, but will not work correctly across multiple Machines.
- Active call state is in-process memory (`active_calls = {}`). Do not scale to multiple Machines until this moves to Redis or equivalent shared state.
- Twilio WebSocket `/ws/twilio/{call_id}` relies on the unguessable UUID call ID and the signed `/voice/{call_id}` setup path. This is acceptable for the current stage, but stronger media-stream auth should be revisited before scale.
- `CORS_ALLOWED_ORIGINS` is empty on Fly, so browser CORS is effectively not enabled for the backend. Native Flutter does not need browser CORS. If Flutter web becomes production, set explicit origins.
- `ALLOWED_HOSTS` is intentionally empty on Fly because Fly internal health checks were rejected by `TrustedHostMiddleware`. This trades strict host validation for working Fly health checks.
- Backend dependencies are mostly unpinned in `requirements.txt`; reproducible builds and supply-chain control should be improved.
- Some caches are unbounded in memory (`TTS_CACHE`, `MP3_CACHE`, `TRANSLATION_CACHE`).
- Supabase Edge Function CORS currently defaults to `*` if `CORS_ALLOWED_ORIGIN` is not set.

## Secrets Review

Tracked repository scan:

- No tracked `.env` files.
- `backend/.env.example`, `backend/.env.local.example`, and production examples contain placeholders only.
- `main_project_app/.env` is ignored and not tracked.

Fly Secrets:

```text
DEEPGRAM_API_KEY          Deployed
GROQ_API_KEY              Deployed
OPENAI_API_KEY            Deployed
SUPABASE_SERVICE_ROLE_KEY Deployed
SUPABASE_URL              Deployed
TWILIO_ACCOUNT_SID        Deployed
TWILIO_AUTH_TOKEN         Deployed
TWILIO_PHONE_NUMBER       Deployed
```

Important fix made during audit:

- `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` were initially deployed with the same digest because local `backend/.env` had empty Supabase values.
- They were reset from the backup local env and redeployed.
- Backend logs now show Supabase client initialization success.
- Invalid bearer token behavior changed from `503 Authentication service is not configured` to `401 Invalid or expired access token`.
- The local backup service role value was then cleared.

## Flutter App Status

Current local Flutter `.env`:

```env
APP_MODE=production
LOCAL_TEST_MODE=false
API_URL=https://avoid-call-backend.fly.dev
SUPABASE_URL=<configured>
SUPABASE_ANON_KEY=<publishable key>
```

Behavior:

- `flutter run` inside `main_project_app` uses the Fly backend by default.
- `--dart-define=API_URL=...` overrides `.env`.
- Supabase initialization is required when `LOCAL_TEST_MODE=false`.

Tests:

```text
flutter analyze -> No issues found
flutter test -> All tests passed
```

Dependency status:

- `flutter pub outdated` shows many upgradable packages.
- Main direct dependencies with newer versions include `audioplayers`,
  `flutter_riverpod`, `go_router`, `supabase_flutter`, `shared_preferences`,
  and others.
- This is not currently blocking, but dependency update planning is recommended.

## Supabase Edge Functions

Functions present:

- `create-checkout-session`
- `sync-my-subscription`
- `sync-apple-entitlement`

Status:

- Stripe checkout and subscription sync code exists.
- Apple local StoreKit sync exists.
- Apple production App Store Server API verification is explicitly not implemented and returns `501`.
- Shared CORS defaults to `*` when `CORS_ALLOWED_ORIGIN` is not set.

## Vercel Demo

`vercel_demo` is mock/demo only:

- `/api/call` returns fake `call_id: test_mode`.
- `/api/prefetch` returns demo translation.
- `/api/preview-voice` returns silent WAV.

It is not suitable for production calling, Twilio streams, or real backend use.

## Verification Commands Run

Passed:

```sh
fly status --app avoid-call-backend
fly checks list --app avoid-call-backend
curl -s -i https://avoid-call-backend.fly.dev/healthz
curl -s -i -X POST https://avoid-call-backend.fly.dev/prefetch ...
fly config validate
python3 -c "import tomllib; tomllib.load(open('fly.toml','rb'))"
cd backend && ../.venv/bin/python -m compileall -q -x '(^|/)(venv|__pycache__)(/|$)' .
cd backend && ../.venv/bin/python -m pip_audit -r requirements.txt
cd main_project_app && flutter analyze
cd main_project_app && flutter test
cd main_project_app && flutter pub outdated
```

Results:

- Fly status: 1 Machine started, checks passing.
- Health check: 200.
- Auth without token: 401.
- Auth with invalid token: 401.
- `fly.toml`: valid.
- Backend project compile: passed when excluding venv.
- `pip-audit`: no known vulnerabilities found.
- Flutter analyzer: no issues.
- Flutter tests: all passed.
- Flutter outdated: many packages are upgradable.

## Recommended Next Work

Priority 1:

- Commit Fly deployment files and startup script fix.
- Keep service role keys out of local backup files.
- Add a deployment smoke test script that checks `/healthz`, unauthenticated 401,
  invalid-token 401, and Fly check status.

Priority 2:

- Pin backend dependency versions or generate a lock/constraints file.
- Add backend tests for auth, request validation, Twilio signature validation,
  and local-test behavior.
- Add Redis/shared-state design before increasing Fly Machine count.

Priority 3:

- Bound or expire in-memory TTS/translation caches.
- Decide production web CORS policy if Flutter web is used.
- Implement production Apple App Store Server API verification.
- Schedule Flutter dependency upgrades.
