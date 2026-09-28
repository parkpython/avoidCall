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
    SUPABASE_URL=your_supabase_url
    SUPABASE_KEY=your_supabase_service_role_key
    ```

5.  **Run the server:**
    ```bash
    uvicorn main:app --reload
    ```

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
  - [docs/supabase_custom_smtp.md](docs/supabase_custom_smtp.md)
- Use `.env.example` files as placeholders only
- Never commit SMTP credentials into git

---

### Optional development tooling

For a local Supabase connection, copy `.codex/config.example.toml` to
`.codex/config.toml` and replace `YOUR_PROJECT_REF` with your own project reference.
The local configuration is ignored by Git; keep credentials out of the template.

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
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_service_role_key

```


5. **서버를 실행합니다:**
```bash
uvicorn main:app --reload

```



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
