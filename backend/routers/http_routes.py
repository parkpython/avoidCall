import logging
import uuid
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import PlainTextResponse, Response

from models import CallRequest, PrefetchRequest, PreviewRequest
import config
from config import LANGUAGE_MAP
from security import (
    AuthenticatedUser,
    enforce_rate_limit,
    require_authenticated_user,
    require_matching_user,
    require_valid_twilio_request,
)
from services import ai_service, call_session_service, db_service

from twilio.twiml.voice_response import VoiceResponse, Connect

router = APIRouter()
logger = logging.getLogger(__name__)

_LOCAL_SERVER_DOMAINS = {"localhost", "127.0.0.1", "::1"}


def _is_public_server_domain(domain: str | None) -> bool:
    if not domain:
        return False
    host = domain.split(":", 1)[0].strip("[]").lower()
    return host not in _LOCAL_SERVER_DOMAINS


def _validate_outbound_call_config() -> None:
    if not config.SERVER_DOMAIN:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="SERVER_DOMAIN is not configured.",
        )
    if config.LOCAL_TEST_MODE and not _is_public_server_domain(config.SERVER_DOMAIN):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Local outbound calls require a public SERVER_DOMAIN "
                "so Twilio can reach /voice and /ws/twilio."
            ),
        )
    if not config.HAS_TWILIO_CONFIG:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Twilio credentials are required for outbound calls.",
        )
    if not config.OPENAI_API_KEY or not config.DEEPGRAM_API_KEY or not config.GROQ_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "OPENAI_API_KEY, DEEPGRAM_API_KEY, and GROQ_API_KEY are "
                "required for real outbound calls."
            ),
        )


@router.post("/prefetch")
async def prefetch(
    request: PrefetchRequest,
    current_user: AuthenticatedUser = Depends(require_authenticated_user),
):
    """미리 번역하고 TTS를 생성하여 캐시에 저장합니다."""
    enforce_rate_limit(
        identity=current_user.user_id,
        action="prefetch",
        limit=60,
        window_seconds=60,
    )
    lang_settings = LANGUAGE_MAP.get(request.language, LANGUAGE_MAP["English"])
    target_lang = lang_settings["target"]

    if config.LOCAL_TEST_MODE:
        return {
            "status": "success",
            "translated_text": f"[local {target_lang}] {request.text}",
        }

    # 1. Translation
    translated_text = await ai_service.translate_text(request.text, target_lang)

    if not translated_text:
        return {"status": "error", "message": "Translation failed"}

    # 2. TTS
    voice = request.voice_preset
    await ai_service.text_to_speech_multilingual(translated_text, voice)

    return {"status": "success", "translated_text": translated_text}


@router.post("/preview-voice")
async def preview_voice(
    request: PreviewRequest,
    current_user: AuthenticatedUser = Depends(require_authenticated_user),
):
    """목소리 미리듣기를 위해 MP3 오디오를 반환합니다."""
    enforce_rate_limit(
        identity=current_user.user_id,
        action="preview-voice",
        limit=30,
        window_seconds=60,
    )

    if not config.HAS_OPENAI_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="OPENAI_API_KEY is required for voice preview.",
        )

    audio = await ai_service.text_to_speech_mp3(request.text, request.voice_preset)

    if audio:
        return Response(content=audio, media_type="audio/mpeg")
    return {"status": "error", "message": "TTS generation failed"}


@router.post("/call")
async def call(
    request: CallRequest,
    current_user: AuthenticatedUser = Depends(require_authenticated_user),
):
    require_matching_user(current_user, request.user_id)
    enforce_rate_limit(
        identity=current_user.user_id,
        action="call",
        limit=5,
        window_seconds=60,
    )

    real_outbound_call = config.real_outbound_calls_enabled()
    if real_outbound_call:
        _validate_outbound_call_config()

    call_id = str(uuid.uuid4())

    # [Supabase] 1. 통화 시작 기록
    db_id = None
    if not config.LOCAL_TEST_MODE:
        db_id = await db_service.create_call_log(
            current_user.user_id,
            request.target_number,
            request.language,
        )

    session = call_session_service.create_session(
        call_id=call_id,
        user_id=current_user.user_id,
        target_number=request.target_number,
        language=request.language,
        greeting_text=request.greeting_text,
        ai_mediation=request.ai_mediation,
        voice_preset=request.voice_preset,
        db_id=db_id,
    )

    if config.LOCAL_TEST_MODE and not real_outbound_call:
        session["local_test_mode"] = True
        return {"status": "success", "call_id": call_id, "mode": "local_test"}

    try:
        twilio_call = config.twilio_client.calls.create(
            to=request.target_number,
            from_=config.TWILIO_PHONE_NUMBER,
            url=f"https://{config.SERVER_DOMAIN}/voice/{call_id}",
            method="POST",
        )
        call_session_service.set_twilio_call_sid(call_id, twilio_call.sid)
        if config.LOCAL_TEST_MODE:
            session["local_outbound_call"] = True
            return {"status": "success", "call_id": call_id, "mode": "local_outbound"}
        return {"status": "success", "call_id": call_id, "mode": "production"}
    except Exception:
        logger.exception("Failed to start outbound call.")
        call_session_service.delete_session(call_id)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Call provider failed to start the call.",
        )


@router.post("/voice/{call_id}")
async def voice(call_id: str, request: Request):
    await require_valid_twilio_request(request)
    response = VoiceResponse()
    if call_session_service.has_session(call_id):
        connect = Connect()
        connect.stream(url=f"wss://{config.SERVER_DOMAIN}/ws/twilio/{call_id}")
        response.append(connect)
    else:
        response.say("Call session not found.")
    return PlainTextResponse(str(response), media_type="text/xml")


@router.post("/incoming")
async def incoming_call(request: Request):
    await require_valid_twilio_request(request)
    response = VoiceResponse()
    response.reject()
    return PlainTextResponse(str(response), media_type="text/xml")
