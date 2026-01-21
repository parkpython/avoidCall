import os
import json
import asyncio
import base64
import struct
import uuid
import time
from fastapi import FastAPI, WebSocket, Request, WebSocketDisconnect
from fastapi.responses import PlainTextResponse
from dotenv import load_dotenv
from pydantic import BaseModel

# Twilio, Deepgram, OpenAI
from twilio.rest import Client as TwilioClient
from twilio.twiml.voice_response import VoiceResponse, Connect
# 3.4.0 버전은 이렇게 심플하게 부르면 다 알아먹음
from deepgram import DeepgramClient, LiveOptions, LiveTranscriptionEvents
from openai import AsyncOpenAI

# Supabase Client (기존 모듈 활용)
from supabase_client import supabase

load_dotenv()

app = FastAPI()

# --- Configuration and Clients ---
DEEPGRAM_API_KEY = os.getenv("DEEPGRAM_API_KEY")
SERVER_DOMAIN = os.getenv("SERVER_DOMAIN")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN")
TWILIO_PHONE_NUMBER = os.getenv("TWILIO_PHONE_NUMBER")

# Supabase 설정 확인 (디버깅용)
if not os.getenv("SUPABASE_URL"):
    print("Warning: SUPABASE_URL is missing.")

# SERVER_DOMAIN 안전장치: https:// 제거
if SERVER_DOMAIN:
    SERVER_DOMAIN = SERVER_DOMAIN.replace("https://", "").replace("http://", "").strip("/")

deepgram_client = DeepgramClient(DEEPGRAM_API_KEY)
openai_client = AsyncOpenAI(api_key=OPENAI_API_KEY)
twilio_client = TwilioClient(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)

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

# Global Cache for TTS Audio to reduce latency
TTS_CACHE = {}
TRANSLATION_CACHE = {} # (text, target_lang) -> translated_text

# --- Centralized Call Management ---
# This dictionary will hold the state for each active call
active_calls = {}

# --- Audio Conversion Utilities ---
def linear2ulaw(sample):
    MAX = 0x7FFF; BIAS = 0x84; sign = (sample >> 8) & 0x80
    if sample < 0: sample = -sample
    if sample > MAX: sample = MAX
    sample += BIAS; exponent = 7
    for i in range(7, -1, -1):
        if sample & (1 << (i + 7)): exponent = i; break
    mantissa = (sample >> (exponent + 3)) & 0x0F
    return ~(sign | (exponent << 4) | mantissa) & 0xFF

def convert_pcm_to_mulaw(pcm_bytes):
    num_samples = len(pcm_bytes) // 2
    samples = struct.unpack(f'<{num_samples}h', pcm_bytes)
    return bytes(linear2ulaw(s) for s in samples)

# --- Core AI Functions ---
async def translate_text(text, target_lang):
    if not text or len(text.strip()) < 1: return None
    try:
        response = await openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": f"You are a translator. Translate the input to {target_lang}. If the input contains typos, infer the intended meaning. Output ONLY the translated text. Do not provide explanations."},
                {"role": "user", "content": text}
            ], max_tokens=100
        )
        return response.choices[0].message.content
    except Exception as e:
        print(f"Translation Error: {e}"); return None

async def text_to_speech_multilingual(text, voice="alloy"):
    try:
        response = await openai_client.audio.speech.create(
            model="tts-1", voice=voice, input=text, response_format="pcm"
        )
        pcm_24k = response.content
        pcm_8k = b"".join(pcm_24k[i:i+2] for i in range(0, len(pcm_24k), 6) if i + 2 <= len(pcm_24k))
        return convert_pcm_to_mulaw(pcm_8k)
    except Exception as e:
        print(f"TTS Error: {e}"); return None

# --- API Models ---
class CallRequest(BaseModel):
    user_id: str  # [수정] 사용자 식별 ID (Device ID 또는 User ID)
    target_number: str
    language: str
    greeting_text: str = None  # 사용자가 설정한 인삿말 (옵션)
    ai_mediation: bool = True  # AI 번역 사용 여부 (기본값 True)
    voice_preset: str = "alloy" # [추가] TTS 목소리 선택 (alloy, echo, fable, onyx, nova, shimmer)

class PrefetchRequest(BaseModel):
    text: str
    language: str
    voice_preset: str = "alloy"

# --- API Endpoints ---
@app.post("/prefetch")
async def prefetch(request: PrefetchRequest):
    """미리 번역하고 TTS를 생성하여 캐시에 저장합니다."""
    lang_settings = LANGUAGE_MAP.get(request.language, LANGUAGE_MAP["English"])
    target_lang = lang_settings["target"]
    
    # 1. Translation Cache Check & Execute
    cache_key = (request.text, target_lang)
    if cache_key in TRANSLATION_CACHE:
        translated_text = TRANSLATION_CACHE[cache_key]
    else:
        translated_text = await translate_text(request.text, target_lang)
        if translated_text:
            TRANSLATION_CACHE[cache_key] = translated_text
    
    if not translated_text:
        return {"status": "error", "message": "Translation failed"}

    # 2. TTS Cache Check & Execute
    voice = request.voice_preset
    if (translated_text, voice) not in TTS_CACHE:
        audio = await text_to_speech_multilingual(translated_text, voice)
        if audio:
            TTS_CACHE[(translated_text, voice)] = audio
    
    return {"status": "success", "translated_text": translated_text}

@app.post("/call")
async def call(request: CallRequest):
    if not SERVER_DOMAIN:
        return {"status": "error", "message": "SERVER_DOMAIN is not configured."}
    
    call_id = str(uuid.uuid4())
    lang_settings = LANGUAGE_MAP.get(request.language, LANGUAGE_MAP["English"])
    
    # [TODO] 결제 시스템 연동 포인트
    # request.user_id(Device ID)를 조회하여 남은 통화 시간이 있는지 확인하는 로직이 이곳에 들어갑니다.
    # if get_user_balance(request.user_id) <= 0: return {"status": "error", "message": "Insufficient balance"}

    # Set up communication queues for this call
    active_calls[call_id] = {
        "user_id": request.user_id,         # Device ID 저장
        "target_number": request.target_number,
        "start_time": time.time(),          # [추가] 통화 시작 시간
        "to_app_queue": asyncio.Queue(),
        "from_app_queue": asyncio.Queue(),
        "language": request.language,
        "stt_lang": lang_settings["stt"],
        "target_lang": lang_settings["target"],
        "stream_sid": None,
        "greeting_text": request.greeting_text,  # 인삿말 저장
        "ai_mediation": request.ai_mediation,    # AI 중재 여부 저장
        "voice_preset": request.voice_preset,    # [추가] 목소리 설정 저장
        "twilio_call_sid": None                  # [추가] Twilio SID 저장 공간
    }
    
    try:
        twilio_call = twilio_client.calls.create(
            to=request.target_number,
            from_=TWILIO_PHONE_NUMBER,
            url=f"https://{SERVER_DOMAIN}/voice/{call_id}",
            method="POST"
        )
        active_calls[call_id]["twilio_call_sid"] = twilio_call.sid
        return {"status": "success", "call_id": call_id}
    except Exception as e:
        del active_calls[call_id]
        return {"status": "error", "message": str(e)}

@app.post("/voice/{call_id}")
async def voice(call_id: str):
    response = VoiceResponse()
    if call_id in active_calls:
        connect = Connect()
        connect.stream(url=f"wss://{SERVER_DOMAIN}/ws/twilio/{call_id}")
        response.append(connect)
    else:
        response.say("Call session not found.")
    return PlainTextResponse(str(response), media_type="text/xml")

@app.post("/incoming")
async def incoming_call(request: Request):
    """Handle incoming calls: Reject immediately."""
    response = VoiceResponse()
    response.reject() # 전화를 받지 않고 즉시 거절 (요금 발생 안 함)
    return PlainTextResponse(str(response), media_type="text/xml")

# --- WebSocket Endpoints ---

# 1. WebSocket for the Frontend App
@app.websocket("/ws/app/{call_id}")
async def websocket_app_endpoint(websocket: WebSocket, call_id: str):
    await websocket.accept()
    if call_id not in active_calls:
        await websocket.close(code=1011, reason="Call ID not found.")
        return

    call_info = active_calls[call_id]
    
    async def listen_to_app():
        try:
            while True:
                msg = await websocket.receive_text()
                data = json.loads(msg)
                if data.get("event") == "frontend_text":
                    await call_info["from_app_queue"].put(data["text"])
        except WebSocketDisconnect:
            print(f"[App:{call_id}] App disconnected.")
            await call_info["from_app_queue"].put("HANG_UP") # Signal hang up

    async def send_to_app():
        try:
            while True:
                message = await call_info["to_app_queue"].get()
                if message == "HANG_UP": break
                await websocket.send_json(message)
        except WebSocketDisconnect:
            print(f"[App:{call_id}] App disconnected while sending.")
        except RuntimeError as e:
            # Catch ASGI runtime errors if sending to a closed socket (e.g. app closed abruptly)
            if "websocket.close" in str(e) or "response already completed" in str(e):
                print(f"[App:{call_id}] Connection closed (RuntimeError) while sending.")
            else:
                raise e

    await asyncio.gather(listen_to_app(), send_to_app())

# 2. WebSocket for Twilio Media Stream
@app.websocket("/ws/twilio/{call_id}")
async def websocket_twilio_endpoint(websocket: WebSocket, call_id: str):
    await websocket.accept()
    if call_id not in active_calls:
        await websocket.close(code=1011, reason="Call ID not found.")
        return

    call_info = active_calls[call_id]
    
    # Notify app immediately that Twilio has connected (Call Answered)
    await call_info["to_app_queue"].put({"type": "call_connected"})
    stt_lang = call_info["stt_lang"]
    target_lang = call_info["target_lang"]
    voice_preset = call_info.get("voice_preset", "alloy")
    loop = asyncio.get_running_loop()

    # --- [Optimization 1] Prefetch Greeting TTS ---
    # 'start' 이벤트를 기다리지 않고, 연결 즉시 TTS 생성을 시작합니다.
    greeting_text = GREETINGS.get(target_lang, GREETINGS["English"])
    user_greeting = call_info.get("greeting_text")
    
    async def prepare_greeting():
        final_text = greeting_text
        if user_greeting:
            # Check Translation Cache first
            cache_key = (user_greeting, target_lang)
            if cache_key in TRANSLATION_CACHE:
                translated = TRANSLATION_CACHE[cache_key]
            else:
                translated = await translate_text(user_greeting, target_lang)
                if translated:
                    TRANSLATION_CACHE[cache_key] = translated
            
            if translated:
                final_text = translated
        
        # Check Cache first (메모리에 저장된 오디오가 있으면 즉시 반환)
        if (final_text, voice_preset) in TTS_CACHE:
            return final_text, TTS_CACHE[(final_text, voice_preset)]
        
        audio = await text_to_speech_multilingual(final_text, voice_preset)
        if audio:
            TTS_CACHE[(final_text, voice_preset)] = audio
        return final_text, audio

    greeting_task = asyncio.create_task(prepare_greeting())
    # -----------------------------------------------

    # --- [Optimization 2] Async Deepgram Setup ---
    # Deepgram 연결을 백그라운드에서 수행하여 메인 루프를 차단하지 않습니다.
    deepgram_socket = deepgram_client.listen.live.v("1")
    deepgram_ready = asyncio.Event()

    async def setup_deepgram():
        try:
            options = LiveOptions(model="nova-2", language=stt_lang, encoding="mulaw", sample_rate=8000, smart_format=True)
            
            async def handle_deepgram_transcript(transcript):
                if len(transcript) > 0:
                    if call_info.get("ai_mediation", True):
                        korean_translation = await translate_text(transcript, "Korean")
                    else:
                        korean_translation = transcript # 번역 없이 원문 그대로 전송
                    if korean_translation:
                        await call_info["to_app_queue"].put({
                            "type": "translation",
                            "original": transcript,
                            "translated": korean_translation,
                        })
            
            def on_deepgram_transcript_sync(self, result, **kwargs):
                transcript = result.channel.alternatives[0].transcript
                if transcript:
                    asyncio.run_coroutine_threadsafe(handle_deepgram_transcript(transcript), loop)

            deepgram_socket.on(LiveTranscriptionEvents.Transcript, on_deepgram_transcript_sync)
            
            # start()가 블로킹일 수 있으므로 executor에서 실행
            if await loop.run_in_executor(None, lambda: deepgram_socket.start(options)) is False:
                print(f"[Twilio:{call_id}] Deepgram failed to start.")
                return
            
            deepgram_ready.set()
        except Exception as e:
            print(f"[Twilio:{call_id}] Deepgram connection failed: {e}")

    deepgram_setup_task = asyncio.create_task(setup_deepgram())
    # ---------------------------------------------

    # Main loop to process messages from Twilio and the App Queue
    async def process_twilio_media():
        try:
            while True:
                msg = await websocket.receive_text()
                data = json.loads(msg)
                if data['event'] == 'start':
                    call_info["stream_sid"] = data['start']['streamSid']
                    print(f"📞 Twilio stream started (SID: {call_info['stream_sid']})")
                    
                    # --- [UX Improvement] Send Automated Greeting ---
                    # 미리 준비해둔 TTS 데이터를 기다렸다가 즉시 전송
                    final_greeting_text, greeting_audio = await greeting_task
                    
                    # 1. Notify App User
                    await call_info["to_app_queue"].put({
                        "type": "translation",
                        "original": "System",
                        "translated": f"(Automated Greeting: {final_greeting_text})",
                    })

                    # 2. Generate & Send Audio to Recipient
                    if greeting_audio:
                        payload = base64.b64encode(greeting_audio).decode('utf-8')
                        await websocket.send_json({
                            "event": "media",
                            "streamSid": call_info["stream_sid"],
                            "media": {"payload": payload}
                        })
                    # ------------------------------------------------
                elif data['event'] == 'media':
                    # Deepgram이 준비될 때까지 기다림 (오디오 손실 방지)
                    if not deepgram_ready.is_set():
                        await deepgram_ready.wait()
                    deepgram_socket.send(base64.b64decode(data['media']['payload']))
                elif data['event'] == 'stop':
                    print("📞 Twilio stream stopped.")
                    break
        except WebSocketDisconnect:
            print(f"[Twilio:{call_id}] Twilio disconnected.")
        finally:
            # Notify frontend that call has ended
            await call_info["to_app_queue"].put({"type": "call_ended"})
            # Signal both other tasks to hang up
            await call_info["to_app_queue"].put("HANG_UP")
            await call_info["from_app_queue"].put("HANG_UP")
            
            # --- [추가] 통화 종료 및 로그 저장 ---
            try:
                duration = int(time.time() - call_info["start_time"])
                log_data = {
                    "user_id": call_info["user_id"],
                    "call_uuid": call_id,
                    "twilio_sid": call_info.get("twilio_call_sid", ""),
                    "target_number": call_info["target_number"],
                    "duration_seconds": duration,
                    "cost": 0.0 # [TODO] 10분당 1000원 등 과금 로직 적용 가능
                }
                
                # Supabase insert는 동기 함수이므로 executor에서 실행하여 이벤트 루프 차단 방지
                await loop.run_in_executor(
                    None, 
                    lambda: supabase.table("call_logs").insert(log_data).execute()
                )
                print(f"✅ Call Log Saved: {duration}s for User {call_info['user_id']}")
            except Exception as e:
                print(f"❌ Failed to save call log: {e}")

            try:
                deepgram_socket.finish()
            except:
                pass
            if call_id in active_calls: del active_calls[call_id] # Clean up

    async def process_app_messages():
        try:
            while True:
                user_text = await call_info["from_app_queue"].get()
                if user_text == "HANG_UP":
                    print(f"[App:{call_id}] App requested hang up. Terminating Twilio call.")
                    twilio_call_sid = call_info.get("twilio_call_sid")
                    if twilio_call_sid:
                        try:
                            twilio_client.calls(twilio_call_sid).update(status="completed")
                        except Exception as e:
                            print(f"Error terminating Twilio call {twilio_call_sid}: {e}")
                    break
                
                if call_info.get("ai_mediation", True):
                    translated_text = await translate_text(user_text, target_lang)
                else:
                    translated_text = user_text # 번역 없이 입력한 텍스트 그대로 사용
                
                if translated_text:
                    await call_info["to_app_queue"].put({
                        "type": "user_text",
                        "original": user_text,
                        "translated": translated_text
                    })
                    audio_bytes = await text_to_speech_multilingual(translated_text, voice_preset)
                    if audio_bytes and call_info["stream_sid"]:
                        payload = base64.b64encode(audio_bytes).decode('utf-8')
                        await websocket.send_json({
                            "event": "media",
                            "streamSid": call_info["stream_sid"],
                            "media": {"payload": payload}
                        })
        except asyncio.CancelledError:
            pass

    # Run both tasks concurrently
    twilio_task = asyncio.create_task(process_twilio_media())
    app_task = asyncio.create_task(process_app_messages())
    await asyncio.gather(twilio_task, app_task)