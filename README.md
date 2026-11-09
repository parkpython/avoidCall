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

아래 명령은 macOS·Linux 기준입니다. 서버와 앱은 각각 저장소 루트에서 시작합니다.

### Flutter 앱

Dart 3.9.2 이상(3.x)이 포함된 Flutter SDK가 필요합니다.

```sh
cd main_project_app
cp .env.example .env
flutter pub get
flutter test
```

위젯 테스트는 예시 설정만으로 실행할 수 있습니다. 통화용 API 키는 필요하지 않습니다. 앱을 직접 실행하려면 `.env`에 Supabase 주소와 앱용 공개 키, 기기에서 접근할 수 있는 백엔드 주소(`API_URL`)를 입력한 뒤 `flutter run`을 실행합니다. 통화 화면에 들어가려면 로그인과 활성 구독 상태가 필요합니다. iOS에서 테스트 구독을 설정하는 방법은 [StoreKit 테스트 문서](docs/apple_iap_stage1_stage2.md)에 있습니다.

### Python 서버

저장소의 Dockerfile과 같은 Python 3.10 기준입니다.

```sh
cd backend
python3.10 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
cp .env.example .env
```

`.env`에 Twilio 발신 번호와 계정 정보, Deepgram·Groq·OpenAI 키, Supabase 서버 설정을 입력합니다. 실제 전화에서는 Twilio가 `SERVER_DOMAIN`의 HTTPS와 WebSocket 주소로 접속할 수 있어야 합니다. 서버에서 사용하는 Supabase 서비스 키는 백엔드에만 둡니다.

```sh
python -m uvicorn main:app --reload
```

Supabase의 가입 확인·비밀번호 재설정 메일은 [SMTP 설정 문서](docs/supabase_custom_smtp.md)를 참고하세요. 개발 중 Codex에서 Supabase에 연결하려면 [.codex/config.example.toml](.codex/config.example.toml)을 `.codex/config.toml`로 복사하고 본인의 프로젝트 식별자를 입력하면 됩니다.

## English

Avoid Call is an unreleased prototype for travelers making restaurant reservations in Japan. The caller types in Korean, the restaurant hears the request in Japanese, and the restaurant’s reply appears as Korean subtitles. The call screen keeps the basic translation visible and labels any suggested correction separately. Two to three friends tried the prototype. I also tested it on a live call with a Japanese friend.

To run the widget tests, follow the Flutter commands above. For live calls, configure the app and backend using their respective `.env.example` files. Run `flutter run` in `main_project_app/` and `python -m uvicorn main:app --reload` in `backend/`.
