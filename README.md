# Avoid Call

친구는 일본 여행에서 식당에 예약 전화를 걸 때마다 일본어 표현을 찾아보고, 몇 번 소리 내어 연습한 뒤에야 전화를 걸었습니다. 한국어로 입력해도 식당과 통화할 수 있으면 좋겠다고 생각해서 만든 앱입니다.

앱에 ‘오늘 저녁 두 명 예약할 수 있나요?’라고 입력하면 식당에는 일본어 음성으로 들립니다. 직원이 일본어로 답하면 여행자는 앱에서 한국어 자막을 읽습니다. 친구 2~3명이 사용해 봤고, 일본인 친구와 실제 통화로 동작을 확인했습니다. 정식 출시하지 않은 프로토타입입니다.

## 통화 화면에서 신경 쓴 점

전화로 들은 짧은 말은 문맥에 따라 뜻이 달라집니다. 잘 안 들린 말을 AI가 매끄럽게 고치다 보면 상대가 하지 않은 말도 붙을 수 있었습니다. 그래서 기본 번역을 그대로 보여 주고, 별도의 보정안이 있을 때만 그 아래에 **AI 추측**이라고 표시했습니다. 서버에서는 보정안이 인식 원문 길이의 4배를 넘으면 버립니다.

## 코드 구성

| 위치 | 맡은 일 |
| --- | --- |
| [Flutter 앱](main_project_app/lib/src/features/) | 상대방 전화번호 입력, 통화 중 메시지 전송, 원문과 번역 표시. 화면 상태는 Riverpod, 화면 이동은 GoRouter로 관리합니다. |
| [FastAPI 서버](backend/routers/) | Twilio로 전화를 걸고 WebSocket으로 앱의 메시지와 통화 음성을 주고받습니다. |
| [번역·음성 처리](backend/services/ai_service.py) | Deepgram이 전화 음성을 인식하고, Groq에서 실행하는 Llama가 번역합니다. 앱에서 보낼 문장은 OpenAI 음성 합성으로 읽습니다. |
| [Supabase](backend/schema.sql) | 앱은 Supabase Auth로 로그인하고 서버는 통화 기록을 저장합니다. |

## 실행 방법

**통화 화면만 확인하려면 1단계만 실행하면 됩니다.** 실제 전화를 걸려면 2~5단계의 외부 서비스와 구독 테스트 환경이 필요합니다. 명령은 macOS·Linux 기준이며 각 코드 블록의 시작 위치를 표시했습니다.

### 1. API 키 없이 통화 화면 테스트

저장소 루트에서 Dart 3.9.2 이상(3.x)을 포함한 Flutter SDK로 실행합니다.

```sh
cd main_project_app
cp -n .env.example .env
flutter pub get
flutter test test/in_call_screen_test.dart
```

테스트는 통화 화면에 메시지를 주입해 말풍선과 번역 상태를 확인합니다. 외부 서비스에 연결하거나 실제로 전화를 걸지는 않습니다.

### 2. Supabase 연결 — 로그인과 통화 기록

1. 테스트용 Supabase 프로젝트를 만들고 **Connect**에서 프로젝트 URL, **Settings → API Keys**에서 앱용 공개 키와 서버용 키를 확인합니다. 앱과 서버가 같은 프로젝트를 사용해야 합니다. [키 종류와 발급 위치](https://supabase.com/docs/guides/getting-started/api-keys)
2. 새 프로젝트의 SQL Editor에서 [backend/schema.sql](backend/schema.sql)을 한 번 실행합니다. 기본 `profiles`, `call_logs` 테이블과 가입 시 프로필을 만드는 트리거가 생성됩니다. 이메일 로그인을 사용할 경우 이메일 인증을 활성화하고 테스트 계정으로 가입·로그인합니다. [인증 메일 설정](docs/supabase_custom_smtp.md)
3. 1단계에서 만든 앱 설정 파일과 서버 설정 파일에 아래 값을 입력합니다. 서버 파일은 저장소 루트에서 `cp -n backend/.env.example backend/.env`로 준비합니다. 앱의 `.env`는 빌드에 포함되므로 **서버용 키는 백엔드에만** 둡니다.

| 파일 | 변수 | 입력값 |
| --- | --- | --- |
| `main_project_app/.env` | `SUPABASE_URL`, `SUPABASE_ANON_KEY` | 프로젝트 URL, 앱용 공개 키(프로젝트의 publishable 키 또는 기존 `anon` 키) |
| `backend/.env` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | 같은 프로젝트 URL, 서버용 키(기존 프로젝트는 `service_role`) |

**새 프로젝트에서 재현할 수 있는 범위:** 공개 SQL은 기본 테이블까지만 만듭니다. 통화 화면 진입에 쓰는 `has_active_subscription()` 함수와 구독 테이블의 마이그레이션이 빠져 있어, 앱에서 실제 통화를 하려면 해당 스키마가 구성된 테스트 프로젝트와 활성 테스트 구독이 필요합니다. [구독 확인 코드](main_project_app/lib/src/features/billing/application/billing_service.dart) · [iOS StoreKit 테스트](docs/apple_iap_stage1_stage2.md)

통화 기록 저장도 별도로 확인해야 합니다. 서버가 쓰는 `device_id`, `language`, `status`, `ended_at`, `transcript` 열은 공개 SQL의 `call_logs`에 없습니다. 기본 SQL만 적용한 상태에서는 발신이 되더라도 전체 기록은 저장되지 않습니다. [통화 기록 저장 코드](backend/services/db_service.py)

### 3. Twilio 연결 — 발신 번호와 콜백

[Twilio Console](https://console.twilio.com/)에서 Voice 발신이 가능한 번호를 준비하고 같은 계정의 Account SID와 Auth Token을 확인합니다. 테스트 계정을 쓰면 수신 번호 인증과 발신 가능 국가도 확인하세요. [Twilio 체험 계정 안내](https://www.twilio.com/docs/usage/tutorials/how-to-use-your-free-trial-account)

| 파일 | 변수 | 입력값 |
| --- | --- | --- |
| `backend/.env` | `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` | Twilio 계정의 SID와 인증 토큰 |
| `backend/.env` | `TWILIO_PHONE_NUMBER` | 내 Twilio **발신 번호**. 국가 코드를 포함한 E.164 형식 |
| `backend/.env` | `SERVER_DOMAIN` | Twilio가 HTTPS와 WSS로 접근할 수 있는 백엔드 호스트명. 예: `voice.example.com` |
| `main_project_app/.env` | `API_URL` | 앱에서 접근할 백엔드 기본 주소. 예: `https://voice.example.com` |

**발신용 콜백 URL은 코드가 통화마다 만듭니다.** 앱에서 번호를 입력하면 서버가 Twilio에 전화를 요청하면서 `https://<SERVER_DOMAIN>/voice/<call_id>`를 전달합니다. 상대가 받으면 Twilio가 이 주소에 POST하고, 응답에 적힌 `wss://<SERVER_DOMAIN>/ws/twilio/<call_id>`로 음성을 주고받습니다. Twilio 번호의 수신 전화용 웹훅 칸에 이 주소를 등록하는 단계는 없습니다. [발신 코드](backend/routers/http_routes.py) · [Twilio Media Streams](https://www.twilio.com/docs/voice/media-streams)

실제 번호를 연결할 때는 발신 API를 테스트 사용자에게만 허용하고 Twilio 콜백의 서명을 검증하는 환경을 사용하세요. 공개 프로토타입의 라우터에는 이 보호가 구현되어 있지 않습니다.

### 4. 음성 인식·번역·음성 합성 API 연결

아래 서비스에서 테스트용 API 키를 각각 발급해 **`backend/.env`**에 넣습니다. 키를 바꾼 뒤에는 서버를 재시작합니다.

| 서비스 | 환경 변수 | 통화에서 맡는 일 |
| --- | --- | --- |
| [Deepgram](https://developers.deepgram.com/docs/create-additional-api-keys) | `DEEPGRAM_API_KEY` | 상대방의 전화 음성을 텍스트로 인식 |
| [Groq](https://console.groq.com/keys) | `GROQ_API_KEY` | 인식한 문장과 앱에서 입력한 답장을 번역 |
| [OpenAI](https://platform.openai.com/api-keys) | `OPENAI_API_KEY` | 보낼 문장을 음성으로 합성하고 목소리 미리듣기를 제공 |

### 5. 실행하고 연결 확인

서버 터미널을 저장소 루트에서 엽니다. [Dockerfile](Dockerfile)과 같은 Python 3.10 기준입니다.

```sh
cd backend
python3.10 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python -m uvicorn main:app --port 8000
```

1. **서버 기동:** 같은 컴퓨터에서 `http://127.0.0.1:8000/docs`를 엽니다. API 목록이 보이면 FastAPI가 실행된 것입니다. 실제 통화에서는 위에 지정한 HTTPS/WSS 호스트가 이 서버로 연결되어야 합니다.
2. **앱 로그인:** 다른 터미널에서 저장소 루트 기준 `cd main_project_app` 후 `flutter run`을 실행합니다. 앱에서 테스트 계정으로 로그인하고, 활성 구독으로 통화 화면에 진입하는지 확인합니다.
3. **양방향 통화:** 동의한 테스트 상대의 국가와 번호를 선택하고 전화를 겁니다. 일본어 통화라면 한국어로 보낸 한 문장이 상대에게 일본어 음성으로 들리는지, 상대가 일본어로 답하면 앱에 한국어 자막이 표시되는지 각각 확인합니다. 발신 자체가 실패하면 Twilio의 통화 로그를, 연결 후 자막만 비면 서버의 Media Stream 연결과 Deepgram 설정을 확인합니다.

개발용 Codex와 Supabase의 연결 설정 예시는 [.codex/config.example.toml](.codex/config.example.toml)에 있습니다.

## English

Avoid Call is an unreleased prototype for travelers making restaurant reservations in Japan. The caller types in Korean, the restaurant hears the request in Japanese, and the restaurant’s reply appears as Korean subtitles. The call screen keeps the basic translation visible and labels any suggested correction separately. Two to three friends tried the prototype. I also tested it on a live call with a Japanese friend.

To run the widget tests, follow the Flutter commands above. For live calls, configure the app and backend using their respective `.env.example` files. Run `flutter run` in `main_project_app/` and `python -m uvicorn main:app --reload` in `backend/`.
