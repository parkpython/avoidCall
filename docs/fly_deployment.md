# Fly.io Deployment

This backend is deployed as a single FastAPI service on Fly.io. Keep one
Machine running because active call state is currently stored in process memory.

## 1. Install and log in

```sh
brew install flyctl
fly auth login
```

Fly requires billing information before creating apps or deploying Machines.

## 2. Create the app

```sh
fly apps create avoid-call-backend --org personal
```

If the app name is unavailable, choose another name and update these values in
`fly.toml`:

```toml
app = "your-app-name"
SERVER_DOMAIN = "your-app-name.fly.dev"
```

Keep `ALLOWED_HOSTS` empty on Fly so internal health checks are not rejected by
the FastAPI trusted-host middleware.

## 3. Set secrets

Do not put these values in `fly.toml`.

```sh
fly secrets set \
  TWILIO_ACCOUNT_SID=... \
  TWILIO_AUTH_TOKEN=... \
  TWILIO_PHONE_NUMBER=... \
  DEEPGRAM_API_KEY=... \
  OPENAI_API_KEY=... \
  GROQ_API_KEY=... \
  SUPABASE_URL=... \
  SUPABASE_SERVICE_ROLE_KEY=...
```

## 4. Deploy

```sh
fly deploy
```

Check the backend:

```sh
curl https://avoid-call-backend.fly.dev/healthz
fly logs
```

## 5. Point the Flutter app at Fly

Use the deployed backend URL for production builds:

```sh
flutter build ios \
  --dart-define=APP_MODE=production \
  --dart-define=LOCAL_TEST_MODE=false \
  --dart-define=API_URL=https://avoid-call-backend.fly.dev
```

Use the matching command for Android or macOS builds.

For ongoing updates, logs, restarts, rollback, and scaling, see
[`docs/fly_operations.md`](fly_operations.md).

## Scaling note

The current backend stores active call sessions in memory:

```py
active_calls = {}
```

That means one Fly Machine with one Uvicorn process is the correct starting
point. Multiple concurrent users can still place calls, but running multiple
Machines before moving call session state to Redis can route Twilio callbacks to
a Machine that does not know the call ID.
