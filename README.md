# Avoid-Call: AI-Powered Voice Mediation System

Avoid-Call is a sophisticated communication platform that leverages AI to mediate and enhance voice calls. It provides real-time transcription, translation, and automated call handling features.

## 🚀 Project Overview

The system consists of two main components:
1.  **Backend (Python/FastAPI):** Orchestrates call routing, AI integration (STT, LLM, TTS), and real-time media streaming via Twilio.
2.  **Mobile App (Flutter):** A feature-rich dialer and call management application with real-time feedback and contact integration.

---

## 🛠 Tech Stack

### Backend
- **Framework:** FastAPI (Python)
- **Real-time Voice:** Twilio Media Streams
- **STT (Speech-to-Text):** Deepgram
- **LLM (Large Language Model):** OpenAI (GPT-4) & Groq
- **Database:** Supabase
- **Authentication:** Supabase Auth

### Mobile (main_project_app)
- **Framework:** Flutter (Dart)
- **State Management:** Riverpod
- **Local Database:** Drift (SQLite)
- **Navigation:** Go Router
- **Backend Integration:** Supabase Flutter SDK
- **Environment Management:** flutter_dotenv

---

## 📂 Project Structure

```text
avoid_call/
├── backend/                # FastAPI Python Server
│   ├── main.py             # Main entry point & Twilio WebSocket logic
│   ├── supabase_client.py  # Database interactions
│   ├── schemas.py          # Pydantic models
│   └── requirements.txt    # Python dependencies
└── main_project_app/       # Flutter Mobile Application
    ├── lib/
    │   ├── main.dart       # App entry point
    │   └── src/
    │       ├── core/       # Database, Routing, Providers
    │       └── features/   # Functional modules (Auth, Contacts, Call, etc.)
    └── assets/             # Images and Icons
```

---

## ⚙️ Setup & Installation

### Backend Setup

1.  **Navigate to the backend directory:**
    ```bash
    cd backend
    ```

2.  **Create and activate a virtual environment:**
    ```bash
    python3 -m venv venv
    source venv/bin/activate  # On Windows: venv\Scripts\activate
    ```

3.  **Install dependencies:**
    ```bash
    pip install -r requirements.txt
    ```

4.  **Configure Environment Variables:**
    Create a `.env` file in the `backend/` directory:
    ```env
    TWILIO_ACCOUNT_SID=your_twilio_sid
    TWILIO_AUTH_TOKEN=your_twilio_auth_token
    TWILIO_PHONE_NUMBER=your_twilio_phone_number
    DEEPGRAM_API_KEY=your_deepgram_api_key
    OPENAI_API_KEY=your_openai_api_key
    GROQ_API_KEY=your_groq_api_key
    SERVER_DOMAIN=your_ngrok_or_server_url
    ENVIRONMENT=development
    ALLOWED_HOSTS=localhost,127.0.0.1,your_backend_host
    CORS_ALLOWED_ORIGINS=
    MAX_REQUEST_BODY_BYTES=65536
    VERIFY_TWILIO_SIGNATURES=true
    ALLOW_UNAUTHENTICATED_REQUESTS=false
    SUPABASE_URL=your_supabase_url
    SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
    ```

    Security defaults:
    - Mobile app requests must include a Supabase bearer token.
    - Twilio voice webhooks are signature-validated by default.
    - Set `ALLOW_UNAUTHENTICATED_REQUESTS=true` only for isolated local development.

5.  **Run the server:**
    ```bash
    uvicorn main:app --reload
    ```

### Local Test Mode

Local mode runs the Flutter app against a local FastAPI backend without Supabase login, Twilio calls, Deepgram, OpenAI, or Groq by default. The backend creates a simulated call session and sends mock call replies over the same app WebSocket flow.

1.  **Backend:**
    ```bash
    cp backend/.env.local.example backend/.env
    PYTHON_BIN=backend/venv/bin/python scripts/start_local_backend.sh
    ```

2.  **Flutter app:**
    ```bash
    cp main_project_app/.env.local.example main_project_app/.env
    cd main_project_app
    flutter run
    ```

For production/deploy mode, use `backend/.env.production.example` and `main_project_app/.env.production.example` as the templates. Production mode keeps Supabase auth, subscription checks, Twilio signature verification, and provider-backed STT/TTS/LLM calls enabled.

To place real Twilio calls while keeping the app/backend in local mode, expose the local backend through a public HTTPS/WSS tunnel and set these backend variables:

```env
LOCAL_OUTBOUND_CALLS=true
SERVER_DOMAIN=your_public_tunnel_host
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_PHONE_NUMBER=your_twilio_phone_number
DEEPGRAM_API_KEY=your_deepgram_api_key
OPENAI_API_KEY=your_openai_api_key
GROQ_API_KEY=your_groq_api_key
```

`SERVER_DOMAIN` must be reachable by Twilio. `localhost` and `127.0.0.1` are valid for simulated local calls, but not for real outbound calls.

### OpenClaw Ops Service

The repo also supports a separate Railway service for Telegram-driven operations.

- Set `APP_MODULE=openclaw_ops:app` on the `openclaw-ops` service.
- Configure `TELEGRAM_BOT_TOKEN`, `TELEGRAM_WEBHOOK_SECRET`, and `TELEGRAM_ALLOWED_CHAT_IDS`.
- `TELEGRAM_ALLOWED_CHAT_IDS` should be required for safe operation.
- Persist state on a Railway volume-backed path such as `OPENCLAW_STATE_DIR=/data/openclaw-ops`.
- Map only explicit task names with service-level variables such as:
  - `OPENCLAW_TASK_STATUS=/app/backend/openclaw_task.sh status`
  - `OPENCLAW_TASK_HEALTH=/app/backend/openclaw_task.sh health`
  - `OPENCLAW_TASK_LOGS=/app/backend/openclaw_task.sh logs`
  - `OPENCLAW_TASK_GIT_STATUS=/app/backend/openclaw_task.sh git_status`
  - `OPENCLAW_TASK_GIT_REV=/app/backend/openclaw_task.sh git_rev`
- Optional service-only runtime install:
  - `OPENCLAW_INSTALL_RUNTIME=1`
  - `OPENCLAW_RUNTIME_COMMAND=openclaw status`
- Telegram commands:
  - `/health`
  - `/tasks`
  - `/task <name>`

### Mobile App Setup

1.  **Navigate to the app directory:**
    ```bash
    cd main_project_app
    ```

2.  **Install Flutter dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Configure Environment Variables:**
    Create a `.env` file in the `main_project_app/` directory (refer to `.env.template`):
    ```env
    APP_MODE=production
    LOCAL_TEST_MODE=false
    SUPABASE_URL=your_supabase_url
    SUPABASE_ANON_KEY=your_supabase_anon_key
    API_URL=your_backend_api_url
    ```

4.  **Generate Database Code (Drift):**
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```

5.  **Run the application:**
    ```bash
    flutter run
    ```

### Supabase Auth Custom SMTP

Custom SMTP for hosted Supabase is an operational configuration, not an app-code feature toggle.

- Auth email flows currently used in this repo:
  - signup confirmation via `signUp(...)`
  - password reset via `resetPasswordForEmail(...)`
- Magic link / OTP email login is not currently implemented in app code
- Setup guide:
  - [docs/supabase_custom_smtp.md](/Users/parkjonghyeok/avoid_call/docs/supabase_custom_smtp.md)
- Use `.env.example` files as placeholders only
- Never commit SMTP credentials into git

---

## 📱 Key Features

- **Real-time AI Mediation:** Automated voice interaction during calls.
- **Smart Dialer:** Integrated contact management and call logs.
- **Transcriptions & Translation:** High-accuracy STT and real-time translation during calls.
- **Secure Authentication:** Seamless login via Supabase.
- **Local Storage:** Fast and reliable local data management using SQLite/Drift.

---

## 📜 License

This project is private and intended for internal use.


# Avoid-Call: AI 기반 음성 중재(통역 및 보조) 시스템

Avoid-Call은 AI를 활용하여 음성 통화를 중재하고 향상시키는 정교한 커뮤니케이션 플랫폼입니다. 실시간 전사(음성 인식), 번역 및 자동 통화 처리 기능을 제공합니다.

## 🚀 프로젝트 개요

이 시스템은 두 가지 주요 구성 요소로 이루어져 있습니다:

1. **백엔드 (Python/FastAPI):** 통화 라우팅, AI 연동(STT, LLM, TTS), 그리고 Twilio를 통한 실시간 미디어 스트리밍을 오케스트레이션(조율)합니다.
2. **모바일 앱 (Flutter):** 실시간 피드백과 연락처 연동 기능을 갖춘 풍부한 기능의 다이얼러 및 통화 관리 애플리케이션입니다.

---

## 🛠 기술 스택

### 백엔드 (Backend)

* **프레임워크:** FastAPI (Python)
* **실시간 음성:** Twilio Media Streams
* **STT (음성 인식):** Deepgram
* **LLM (대형 언어 모델):** OpenAI (GPT-4) & Groq
* **데이터베이스:** Supabase
* **인증:** Supabase Auth

### 모바일 (main_project_app)

* **프레임워크:** Flutter (Dart)
* **상태 관리:** Riverpod
* **로컬 데이터베이스:** Drift (SQLite)
* **네비게이션:** Go Router
* **백엔드 연동:** Supabase Flutter SDK
* **환경 변수 관리:** flutter_dotenv

---

## 📂 프로젝트 구조

```text
avoid_call/
├── backend/                # FastAPI 파이썬 서버
│   ├── main.py             # 메인 진입점 및 Twilio 웹소켓 로직
│   ├── supabase_client.py  # 데이터베이스 상호작용
│   ├── schemas.py          # Pydantic 모델
│   └── requirements.txt    # 파이썬 패키지 의존성
└── main_project_app/       # Flutter 모바일 애플리케이션
    ├── lib/
    │   ├── main.dart       # 앱 진입점
    │   └── src/
    │       ├── core/       # 데이터베이스, 라우팅, 상태 관리(Providers)
    │       └── features/   # 기능 모듈 (인증, 연락처, 통화 등)
    └── assets/             # 이미지 및 아이콘 자산

```

---

## ⚙️ 설정 및 설치 방법

### 백엔드 설정

1. **backend 디렉토리로 이동합니다:**
```bash
cd backend

```


2. **가상 환경을 생성하고 활성화합니다:**
```bash
python3 -m venv venv
source venv/bin/activate  # Windows의 경우: venv\Scripts\activate

```


3. **의존성 패키지를 설치합니다:**
```bash
pip install -r requirements.txt

```


4. **환경 변수(.env)를 설정합니다:**
`backend/` 디렉토리 안에 `.env` 파일을 생성하고 다음 내용을 입력합니다:
```env
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_PHONE_NUMBER=your_twilio_phone_number
DEEPGRAM_API_KEY=your_deepgram_api_key
OPENAI_API_KEY=your_openai_api_key
GROQ_API_KEY=your_groq_api_key
SERVER_DOMAIN=your_ngrok_or_server_url
ENVIRONMENT=development
ALLOWED_HOSTS=localhost,127.0.0.1,your_backend_host
CORS_ALLOWED_ORIGINS=
MAX_REQUEST_BODY_BYTES=65536
VERIFY_TWILIO_SIGNATURES=true
ALLOW_UNAUTHENTICATED_REQUESTS=false
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

```

보안 기본값:
- 모바일 앱 요청은 Supabase bearer token이 있어야 처리됩니다.
- Twilio voice webhook은 기본적으로 signature 검증을 수행합니다.
- `ALLOW_UNAUTHENTICATED_REQUESTS=true`는 격리된 로컬 개발에서만 사용하세요.


5. **서버를 실행합니다:**
```bash
uvicorn main:app --reload

```

### 로컬 테스트 모드

로컬 모드는 Supabase 로그인, Twilio 발신, Deepgram, OpenAI, Groq 없이 앱과 로컬 FastAPI 백엔드만으로 통화 흐름을 테스트합니다. 백엔드가 가짜 통화 세션을 만들고 앱 WebSocket으로 모의 응답을 보냅니다.

1. **백엔드**
```bash
cp backend/.env.local.example backend/.env
PYTHON_BIN=backend/venv/bin/python scripts/start_local_backend.sh
```

2. **Flutter 앱**
```bash
cp main_project_app/.env.local.example main_project_app/.env
cd main_project_app
flutter run
```

배포 모드는 `backend/.env.production.example`과 `main_project_app/.env.production.example`을 기준으로 설정하세요. 배포 모드에서는 Supabase 인증, 구독 체크, Twilio signature 검증, 실제 STT/TTS/LLM 연동이 켜진 상태로 동작합니다.



### 모바일 앱 설정

1. **앱 디렉토리로 이동합니다:**
```bash
cd main_project_app

```


2. **Flutter 패키지를 설치합니다:**
```bash
flutter pub get

```


3. **환경 변수를 설정합니다:**
`main_project_app/` 디렉토리 안에 `.env` 파일을 생성합니다 (`.env.template` 파일 참고):
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
API_URL=your_backend_api_url

```


4. **데이터베이스 코드 생성 (Drift):**
```bash
dart run build_runner build --delete-conflicting-outputs

```


5. **애플리케이션을 실행합니다:**
```bash
flutter run

```



---

## 📱 주요 기능

* **실시간 AI 중재:** 통화 중 자동화된 음성 상호작용을 지원합니다.
* **스마트 다이얼러:** 연락처 관리 및 통화 기록이 통합되어 있습니다.
* **전사 및 번역:** 높은 정확도의 STT와 통화 중 실시간 번역을 제공합니다.
* **안전한 인증:** Supabase를 통한 매끄러운 로그인 환경을 제공합니다.
* **로컬 스토리지:** SQLite/Drift를 사용한 빠르고 안정적인 로컬 데이터 관리를 지원합니다.

---

## 📜 라이선스

이 프로젝트는 비공개(Private)이며 내부 사용을 목적으로 합니다.
