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
