import uuid
import time
import asyncio
from fastapi import APIRouter, Request
from fastapi.responses import PlainTextResponse, Response

from models import CallRequest, PrefetchRequest, PreviewRequest
import config
from config import LANGUAGE_MAP
from services import ai_service, db_service
from state_manager import active_calls

from twilio.twiml.voice_response import VoiceResponse, Connect

router = APIRouter()

@router.post("/prefetch")
async def prefetch(request: PrefetchRequest):
    """미리 번역하고 TTS를 생성하여 캐시에 저장합니다."""
    lang_settings = LANGUAGE_MAP.get(request.language, LANGUAGE_MAP["English"])
    target_lang = lang_settings["target"]
    
    # 1. Translation
    translated_text = await ai_service.translate_text(request.text, target_lang)
    
    if not translated_text:
        return {"status": "error", "message": "Translation failed"}

    # 2. TTS
    voice = request.voice_preset
    await ai_service.text_to_speech_multilingual(translated_text, voice)
    
    return {"status": "success", "translated_text": translated_text}

@router.post("/preview-voice")
async def preview_voice(request: PreviewRequest):
    """목소리 미리듣기를 위해 MP3 오디오를 반환합니다."""
    if not request.text: return {"status": "error", "message": "No text provided"}
    
    audio = await ai_service.text_to_speech_mp3(request.text, request.voice_preset)
    
    if audio:
        return Response(content=audio, media_type="audio/mpeg")
    return {"status": "error", "message": "TTS generation failed"}

@router.post("/call")
async def call(request: CallRequest):
    if not config.SERVER_DOMAIN:
        return {"status": "error", "message": "SERVER_DOMAIN is not configured."}
    
    call_id = str(uuid.uuid4())
    lang_settings = LANGUAGE_MAP.get(request.language, LANGUAGE_MAP["English"])
    
    # [TEST MODE]
    if request.target_number == "TEST":
        # (테스트 모드 로직은 간소화를 위해 생략하거나 필요시 main.py의 로직을 그대로 가져오면 됩니다. 
        #  여기서는 구조 분리에 집중하여 일반 통화 로직 위주로 작성합니다.)
        pass 

    # [Supabase] 1. 통화 시작 기록
    db_id = await db_service.create_call_log(request.user_id, request.target_number, request.language)

    # Set up communication queues
    active_calls[call_id] = {
        "user_id": request.user_id,
        "target_number": request.target_number,
        "start_time": time.time(),
        "to_app_queue": asyncio.Queue(),
        "from_app_queue": asyncio.Queue(),
        "language": request.language,
        "stt_lang": lang_settings["stt"],
        "target_lang": lang_settings["target"],
        "stream_sid": None,
        "greeting_text": request.greeting_text,
        "ai_mediation": request.ai_mediation,
        "voice_preset": request.voice_preset,
        "twilio_call_sid": None,
        "conversation_history": [],
        "db_id": db_id,
    }
    
    try:
        twilio_call = config.twilio_client.calls.create(
            to=request.target_number,
            from_=config.TWILIO_PHONE_NUMBER,
            url=f"https://{config.SERVER_DOMAIN}/voice/{call_id}",
            method="POST"
        )
        active_calls[call_id]["twilio_call_sid"] = twilio_call.sid
        return {"status": "success", "call_id": call_id}
    except Exception as e:
        if call_id in active_calls: del active_calls[call_id]
        return {"status": "error", "message": str(e)}

@router.post("/voice/{call_id}")
async def voice(call_id: str):
    response = VoiceResponse()
    if call_id in active_calls:
        connect = Connect()
        connect.stream(url=f"wss://{config.SERVER_DOMAIN}/ws/twilio/{call_id}")
        response.append(connect)
    else:
        response.say("Call session not found.")
    return PlainTextResponse(str(response), media_type="text/xml")

@router.post("/incoming")
async def incoming_call(request: Request):
    response = VoiceResponse()
    response.reject()
    return PlainTextResponse(str(response), media_type="text/xml")