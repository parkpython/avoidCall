import os
from dotenv import load_dotenv
from twilio.rest import Client as TwilioClient
from deepgram import DeepgramClient
from openai import AsyncOpenAI

load_dotenv()

# --- Environment Variables ---
DEEPGRAM_API_KEY = os.getenv("DEEPGRAM_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN")
TWILIO_PHONE_NUMBER = os.getenv("TWILIO_PHONE_NUMBER")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
SERVER_DOMAIN = os.getenv("SERVER_DOMAIN")

# SERVER_DOMAIN 안전장치: https:// 제거
if SERVER_DOMAIN:
    SERVER_DOMAIN = SERVER_DOMAIN.replace("https://", "").replace("http://", "").strip("/")

# --- Client Initialization ---
deepgram_client = DeepgramClient(DEEPGRAM_API_KEY)
openai_client = AsyncOpenAI(api_key=OPENAI_API_KEY)

# [Groq] 번역 및 텍스트 생성을 위한 Groq 클라이언트 설정 (OpenAI 호환)
groq_client = AsyncOpenAI(
    api_key=GROQ_API_KEY,
    base_url="https://api.groq.com/openai/v1"
)

twilio_client = TwilioClient(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)

# --- Constants ---
LANGUAGE_MAP = {
    "English": {"stt": "en-US", "target": "English"},
    "Japanese": {"stt": "ja", "target": "Japanese"},
    "Chinese": {"stt": "zh", "target": "Chinese"},
    "Spanish": {"stt": "es", "target": "Spanish"},
    "Dutch": {"stt": "nl", "target": "Dutch"},
}

GREETINGS = {
    "English": "Hello. This is an AI-assisted call. Please speak naturally.",
    "Japanese": "もしもし。AI通訳を使用しています。そのままお話しください。",
    "Chinese": "你好。这是一个人工智能辅助通话。请自然说话。",
    "Spanish": "Hola. Esta es una llamada asistida por IA. Por favor hable con naturalidad.",
    "Dutch": "Hallo. Dit is een door AI ondersteund gesprek. Spreek alsjeblieft natuurlijk.",
}