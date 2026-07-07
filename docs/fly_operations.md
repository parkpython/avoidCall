# Fly.io 운영 매뉴얼

운영 앱:

```text
avoid-call-backend
https://avoid-call-backend.fly.dev
```

이 서비스는 Flutter 앱이 호출하는 production FastAPI 백엔드입니다. 현재
통화 세션이 서버 프로세스 메모리에 저장되므로, Redis 같은 공유 저장소로
옮기기 전까지는 Fly Machine 1대만 운영합니다.

## 매일 상태 확인

```sh
fly status --app avoid-call-backend
curl -s https://avoid-call-backend.fly.dev/healthz
fly logs --app avoid-call-backend --no-tail
```

정상 `/healthz` 응답:

```json
{"status":"ok","service":"avoid-call-backend","local_test_mode":false}
```

정상 Fly 상태:

```text
STATE   started
CHECKS  1 total, 1 passing
```

## 코드 업데이트 배포

repo root에서 실행합니다.

```sh
fly config validate
fly deploy --remote-only
curl -s https://avoid-call-backend.fly.dev/healthz
fly status --app avoid-call-backend
```

`--remote-only`를 쓰면 로컬 Docker Desktop이 켜져 있지 않아도 됩니다. Fly가
원격 builder에서 root `Dockerfile`로 이미지를 빌드합니다.

배포 후 확인할 것:

- `/healthz`가 `200`을 반환하는지
- `local_test_mode`가 `false`인지
- Machine이 1대만 떠 있는지
- health check가 passing인지

## Secret 관리

Secret 이름만 확인합니다. 값은 출력되지 않습니다.

```sh
fly secrets list --app avoid-call-backend
```

Secret 추가/교체:

```sh
fly secrets set --app avoid-call-backend \
  TWILIO_ACCOUNT_SID=... \
  TWILIO_AUTH_TOKEN=... \
  TWILIO_PHONE_NUMBER=... \
  DEEPGRAM_API_KEY=... \
  OPENAI_API_KEY=... \
  GROQ_API_KEY=... \
  SUPABASE_URL=... \
  SUPABASE_SERVICE_ROLE_KEY=...
```

Secret은 런타임 환경변수입니다. `fly.toml`에 넣지 말고, `.env`도 commit하지
않습니다.

Secret 변경이 staged 상태로만 남으면 아래 명령으로 반영합니다.

```sh
fly secrets deploy --app avoid-call-backend
```

## 비용 폭주 방지 스위치

충전 전 기본 운영값은 실발신 차단입니다.

```env
OUTBOUND_CALLS_ENABLED=false
MAX_ACTIVE_CALLS=1
MAX_ACTIVE_CALLS_PER_USER=1
MAX_CALL_DURATION_SECONDS=300
CALLS_PER_USER_PER_MINUTE=2
CALLS_PER_USER_PER_HOUR=5
CALLS_PER_IP_PER_MINUTE=5
CALLS_PER_IP_PER_HOUR=20
```

이 상태에서는 앱이 인증되어 있어도 실제 Twilio 발신은 `503`으로 막힙니다.
OpenAI/Groq/Deepgram 기반 보조 기능은 `AI_FEATURES_ENABLED=true`일 때만
동작합니다.

Twilio 충전 후 1회 실검증을 열 때:

```sh
fly secrets set --app avoid-call-backend OUTBOUND_CALLS_ENABLED=true
fly logs --app avoid-call-backend
```

검증이 끝났거나 이상 트래픽이 보이면 즉시 닫습니다.

```sh
fly secrets set --app avoid-call-backend OUTBOUND_CALLS_ENABLED=false
```

AI 비용성 기능까지 같이 잠그려면:

```sh
fly secrets set --app avoid-call-backend \
  OUTBOUND_CALLS_ENABLED=false \
  AI_FEATURES_ENABLED=false
```

다시 열 때:

```sh
fly secrets set --app avoid-call-backend AI_FEATURES_ENABLED=true
```

현재 rate limit과 동시 통화 제한은 프로세스 메모리 기반입니다. Machine 1대
운영에서는 유효하지만, 여러 Machine으로 늘리기 전에는 Redis 같은 공유 저장소로
옮겨야 합니다.

## 서버 재시작

전체 Machine 재시작:

```sh
fly machine restart --app avoid-call-backend
```

특정 Machine만 재시작:

```sh
fly machine list --app avoid-call-backend
fly machine restart <machine-id> --app avoid-call-backend
```

재시작 후 확인:

```sh
curl -s https://avoid-call-backend.fly.dev/healthz
```

## 로그와 디버깅

실시간 로그 보기:

```sh
fly logs --app avoid-call-backend
```

최근 로그만 보고 종료:

```sh
fly logs --app avoid-call-backend --no-tail
```

자주 쓰는 진단 명령:

```sh
fly status --app avoid-call-backend
fly machine list --app avoid-call-backend
fly machine status <machine-id> --app avoid-call-backend
fly checks list --app avoid-call-backend
```

Fly에서 `/healthz`가 400이면 `ALLOWED_HOSTS`부터 봅니다. 현재 설정처럼
`fly.toml`에서 비워둬야 Fly 내부 health check가 FastAPI
`TrustedHostMiddleware`에 막히지 않습니다.

시작 로그에 `/data` permission error가 나오면 `scripts/start_service.sh`를
확인합니다. `APP_MODULE=openclaw_ops:app`일 때만 `/data/openclaw-ops`를
만들어야 합니다.

## 롤백

이전 release와 이미지 확인:

```sh
fly releases --app avoid-call-backend --image
```

정상 동작하던 이전 이미지 태그를 복사해서 재배포합니다.

```sh
fly deploy --app avoid-call-backend --image registry.fly.io/avoid-call-backend:<image-tag>
```

롤백 후 확인:

```sh
curl -s https://avoid-call-backend.fly.dev/healthz
fly status --app avoid-call-backend
```

## 스케일링

현재 안전한 운영 형태:

```text
Machine count: 1
Uvicorn worker count: 1
```

아직 Machine을 여러 대로 늘리면 안 됩니다. active call 상태가 프로세스 메모리에
있습니다.

```py
active_calls = {}
```

예를 들어 `/call`은 Machine A에서 처리됐는데 Twilio의 `/voice/{call_id}`가
Machine B로 가면, Machine B는 해당 call ID를 모릅니다.

Redis 이전에 용량이 필요하면 Machine 수를 늘리지 말고 먼저 VM 스펙을 키웁니다.

```sh
fly scale show --app avoid-call-backend
fly scale vm shared-cpu-2x --vm-memory=2048 --app avoid-call-backend
```

Machine 수 증가는 call session과 rate limit을 Redis 같은 공유 저장소로 옮긴 뒤에
합니다.

## Flutter 앱 빌드 설정

현재 `main_project_app/.env`는 Fly production 서버를 보도록 맞춰져 있습니다.
그래서 repo root 또는 `main_project_app`에서 일반 `flutter run`을 실행하면 앱은
기본적으로 아래 백엔드를 사용합니다.

```text
https://avoid-call-backend.fly.dev
```

현재 `.env` 기준:

```env
APP_MODE=production
LOCAL_TEST_MODE=false
API_URL=https://avoid-call-backend.fly.dev
SUPABASE_URL=https://rboplwlffqhaoyfrnpzk.supabase.co
SUPABASE_ANON_KEY=<publishable key>
```

production Flutter 빌드도 같은 값을 쓰면 됩니다. 명령어에서 명시하려면 아래
값을 넣습니다.

```sh
--dart-define=APP_MODE=production
--dart-define=LOCAL_TEST_MODE=false
--dart-define=API_URL=https://avoid-call-backend.fly.dev
```

iOS 예시:

```sh
cd main_project_app
flutter build ios --release \
  --dart-define=APP_MODE=production \
  --dart-define=LOCAL_TEST_MODE=false \
  --dart-define=API_URL=https://avoid-call-backend.fly.dev
```

Android 예시:

```sh
cd main_project_app
flutter build apk --release \
  --dart-define=APP_MODE=production \
  --dart-define=LOCAL_TEST_MODE=false \
  --dart-define=API_URL=https://avoid-call-backend.fly.dev
```

로컬 백엔드로 되돌려 테스트하려면 `main_project_app/.env`를 아래처럼 바꿉니다.

```env
APP_MODE=local
LOCAL_TEST_MODE=true
API_URL=http://127.0.0.1:8000
SUPABASE_URL=
SUPABASE_ANON_KEY=
```

## 유지해야 할 설정

`fly.toml`에는 production 기준으로 아래 값이 유지되어야 합니다.

```toml
APP_MODE = "production"
ENVIRONMENT = "production"
LOCAL_TEST_MODE = "false"
SERVER_DOMAIN = "avoid-call-backend.fly.dev"
ALLOWED_HOSTS = ""
auto_stop_machines = "off"
min_machines_running = 1
```

`LOCAL_OUTBOUND_CALLS`는 local test mode에서만 의미가 있습니다. production에서는
`LOCAL_TEST_MODE=false`이므로 실제 Twilio 발신 경로가 사용됩니다.

## 자주 쓰는 링크

- Dashboard: https://fly.io/apps/avoid-call-backend
- Public backend: https://avoid-call-backend.fly.dev
- Health check: https://avoid-call-backend.fly.dev/healthz
- Fly deploy docs: https://fly.io/docs/flyctl/deploy/
- Fly secrets docs: https://fly.io/docs/flyctl/secrets/
- Fly scale docs: https://fly.io/docs/flyctl/scale/
- Fly machine docs: https://fly.io/docs/flyctl/machine/
