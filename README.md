# Avoid Call

친구는 일본에서 식당에 전화하기 전에 꼭 예약할 때 쓸 말을 찾아봤습니다. 소리 내서 몇 번 연습한 다음에야 전화를 걸었습니다. 그걸 보고 한국어로 하고 싶은 말을 적으면 대신 일본어로 읽어 주는 앱을 만들었습니다.

앱에 “오늘 저녁에 두 명 예약할 수 있을까요?”라고 쓰면, 전화를 받은 쪽에는 일본어로 들립니다. 상대가 일본어로 답하면 저는 화면에서 한국어 자막을 읽습니다. 친구 두세 명이 써 봤고, 저도 일본인 친구에게 직접 전화해서 양쪽에서 말이 잘 전달되는지 확인했습니다. 아직 출시하지 않은 프로토타입입니다.

## 통화 화면에서 신경 쓴 점

통화 화면을 만들 때 가장 신경 쓴 건 잘 안 들린 말이었습니다. AI가 짧은 소리를 그럴듯한 문장으로 바꾸면, 전화를 건 사람은 상대가 정말 그렇게 말했다고 받아들일 수 있습니다. 그래서 화면에는 기본 번역을 먼저 보여 줍니다. AI가 문맥을 보고 고친 문장은 그 아래에 **AI 추측**이라고 따로 표시합니다. 고친 문장이 음성 인식 원문보다 네 배 넘게 길어지면 아예 표시하지 않습니다.

## 코드 구성

| 위치 | 맡은 일 |
| --- | --- |
| [Flutter 앱](main_project_app/lib/src/features/) | 상대방 전화번호 입력, 통화 중 메시지 전송, 원문과 번역 표시. 화면 상태는 Riverpod, 화면 이동은 GoRouter로 관리합니다. |
| [FastAPI 서버](backend/routers/) | Twilio로 전화를 걸고 WebSocket으로 앱의 메시지와 통화 음성을 주고받습니다. |
| [번역·음성 처리](backend/services/ai_service.py) | Deepgram이 전화 음성을 인식하고, Groq에서 실행하는 Llama가 번역합니다. 앱에서 보낼 문장은 OpenAI 음성 합성으로 읽습니다. |
| [Supabase](backend/schema.sql) | 앱은 Supabase Auth로 로그인하고 서버는 통화 기록을 저장합니다. |

## 실행 방법

통화 화면 코드가 어떻게 동작하는지 보려면 1단계의 테스트부터 돌려 보세요. 실제로 전화를 걸려면 2~5단계의 서비스 설정과 활성 테스트 구독이 필요합니다. 아래 명령은 macOS·Linux 기준입니다.

### 1. API 키 없이 통화 화면 테스트

Dart 3.9.2 이상(3.x)이 포함된 Flutter SDK를 사용합니다. 저장소 루트에서 실행하세요.

```sh
cd main_project_app
cp -n .env.example .env
flutter pub get
flutter test test/in_call_screen_test.dart
```

이 테스트에서는 “네”를 연달아 두 번 보냅니다. 번역이 돌아왔을 때 두 말풍선 모두에서 ‘전송 중’ 표시가 사라지는지 확인합니다. 실제 전화나 API 키는 필요 없습니다.

### 2. Supabase 연결 — 로그인과 통화 기록

1. Supabase에서 테스트 프로젝트를 하나 만드세요. **Connect**에 있는 프로젝트 URL은 앱과 서버 양쪽에 씁니다. 키는 **Settings → API Keys**에서 확인합니다. [키 종류와 발급 위치](https://supabase.com/docs/guides/getting-started/api-keys)
2. 새 프로젝트의 SQL Editor에서 [backend/schema.sql](backend/schema.sql)을 한 번 실행하세요. 사용자 프로필과 통화 기록 테이블이 생기고, 이후 가입하는 사용자는 프로필이 자동으로 만들어집니다. 이메일 로그인을 쓸 때는 이메일 인증을 켜고 테스트 계정으로 가입한 뒤 로그인해 보세요. [인증 메일 설정](docs/supabase_custom_smtp.md)
3. 저장소 루트에서 `cp -n backend/.env.example backend/.env`로 서버 설정 파일을 준비하세요. 1단계에서 만든 앱 설정 파일에는 공개 키를 넣고, 서버용 키는 `backend/.env`에만 넣으세요. 앱의 `.env`는 빌드에 포함됩니다.

| 파일 | 변수 | 입력값 |
| --- | --- | --- |
| `main_project_app/.env` | `SUPABASE_URL`, `SUPABASE_ANON_KEY` | 프로젝트 URL, 앱용 공개 키(프로젝트의 publishable 키 또는 기존 `anon` 키) |
| `backend/.env` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | 같은 프로젝트 URL, 서버용 키(기존 프로젝트는 `service_role`) |

**새 프로젝트에서 통화 화면까지 열려면** 구독 설정이 더 필요합니다. 앱은 로그인한 뒤 `has_active_subscription()`으로 구독 상태를 확인합니다. 공개 SQL에는 이 함수와 구독 테이블을 만드는 부분이 빠져 있어서, 실제 발신 테스트에는 둘 다 설정된 프로젝트와 활성 테스트 구독이 필요합니다. [구독 확인 코드](main_project_app/lib/src/features/billing/application/billing_service.dart) · [iOS StoreKit 테스트](docs/apple_iap_stage1_stage2.md)

통화 기록도 기본 SQL만으로는 전부 저장되지 않습니다. 서버가 기록을 남길 때 쓰는 `device_id`, `language`, `status`, `ended_at`, `transcript` 열이 공개 SQL의 `call_logs`에는 빠져 있습니다. [통화 기록 저장 코드](backend/services/db_service.py)

### 3. Twilio 연결 — 발신 번호와 콜백

[Twilio Console](https://console.twilio.com/)에서 Voice 발신이 가능한 번호를 준비하고 같은 계정의 Account SID와 Auth Token을 확인합니다. 테스트 계정을 쓰면 수신 번호 인증과 발신 가능 국가도 확인하세요. [Twilio 체험 계정 안내](https://www.twilio.com/docs/usage/tutorials/how-to-use-your-free-trial-account)

| 파일 | 변수 | 입력값 |
| --- | --- | --- |
| `backend/.env` | `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` | Twilio 계정의 SID와 인증 토큰 |
| `backend/.env` | `TWILIO_PHONE_NUMBER` | 내 Twilio **발신 번호**. 국가 코드를 포함한 E.164 형식 |
| `backend/.env` | `SERVER_DOMAIN` | Twilio가 HTTPS와 WSS로 접근할 수 있는 백엔드 호스트명. 예: `voice.example.com` |
| `main_project_app/.env` | `API_URL` | 앱에서 접근할 백엔드 기본 주소. 예: `https://voice.example.com` |

발신할 때는 Twilio 콘솔에 통화별 URL을 따로 등록할 필요가 없습니다. 앱에서 전화를 걸면 서버가 `https://<SERVER_DOMAIN>/voice/<call_id>`를 만들어 Twilio에 넘깁니다. 상대가 전화를 받으면 Twilio가 그 주소로 POST 요청을 보내고, 서버가 알려 준 `wss://<SERVER_DOMAIN>/ws/twilio/<call_id>`로 음성을 주고받습니다. [발신 코드](backend/routers/http_routes.py) · [Twilio Media Streams](https://www.twilio.com/docs/voice/media-streams)

공개한 버전에는 발신 요청을 보낸 사용자나 Twilio 콜백 서명을 검증하는 코드가 없습니다. 실제 번호를 연결할 때는 테스트 사용자만 발신할 수 있고 콜백 서명을 검증하는 환경에서 사용하세요.

### 4. 음성 인식·번역·음성 합성 API 연결

상대방의 말을 받아 적을 때는 Deepgram, 번역할 때는 Groq, 내가 쓴 답장을 읽어 줄 때는 OpenAI를 씁니다. 각 서비스에서 키를 발급해 `backend/.env`에 넣고 서버를 다시 시작하세요.

| 서비스 | 환경 변수 | 통화에서 맡는 일 |
| --- | --- | --- |
| [Deepgram](https://developers.deepgram.com/docs/create-additional-api-keys) | `DEEPGRAM_API_KEY` | 상대방의 전화 음성을 텍스트로 인식 |
| [Groq](https://console.groq.com/keys) | `GROQ_API_KEY` | 인식한 문장과 앱에서 입력한 답장을 번역 |
| [OpenAI](https://platform.openai.com/api-keys) | `OPENAI_API_KEY` | 보낼 문장을 음성으로 합성하고 목소리 미리듣기를 제공 |

### 5. 실행하고 연결 확인

저장소 루트에서 터미널을 열고 서버부터 실행하세요. Python 버전은 [Dockerfile](Dockerfile)과 같은 3.10입니다.

```sh
cd backend
python3.10 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python -m uvicorn main:app --port 8000
```

1. 같은 컴퓨터에서 `http://127.0.0.1:8000/docs`를 열어 보세요. API 목록이 보이면 서버가 켜진 겁니다. 실제 전화가 연결되려면 Twilio도 3단계에서 설정한 호스트를 통해 이 서버에 HTTPS와 WSS로 접속할 수 있어야 합니다.
2. 새 터미널을 열고 저장소 루트에서 `cd main_project_app` 후 `flutter run`을 실행하세요. 활성 테스트 구독이 있는 계정으로 로그인해 통화 화면을 엽니다.
3. 통화하기로 한 상대의 국가와 번호를 선택하고 전화를 거세요. 일본어로 테스트한다면 한국어로 짧은 문장을 보내고, 상대에게 뭐라고 들렸는지 물어보세요. 반대로 상대가 한 대답은 내 화면에 한국어로 뜨면 됩니다. 전화가 울리지 않으면 Twilio 통화 로그부터, 전화는 연결됐는데 자막이 없으면 서버의 Media Stream 연결과 Deepgram 설정부터 확인하세요.

개발용 Codex와 Supabase의 연결 설정 예시는 [.codex/config.example.toml](.codex/config.example.toml)에 있습니다.

## English

I built Avoid Call after watching a friend rehearse what to say before calling a restaurant in Japan. You type your question in Korean, the person on the phone hears it in Japanese, and you read their reply in Korean. The app shows the basic translation first and labels any AI guess separately. Two or three friends tried the prototype, and I tested it on a call with a Japanese friend. I haven’t released it.

You can run the call-screen test in step 1 without API keys. For a live call, follow steps 2–5 to connect Supabase, Twilio and the speech and translation services. A fresh Supabase project also needs the subscription setup described in step 2.
