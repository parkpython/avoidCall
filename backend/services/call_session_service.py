import asyncio
import time
from typing import Any

from config import LANGUAGE_MAP
from state_manager import active_calls


SessionData = dict[str, Any]


def create_session(
    *,
    call_id: str,
    user_id: str,
    target_number: str,
    language: str,
    greeting_text: str | None,
    ai_mediation: bool,
    voice_preset: str,
    db_id: int | None,
) -> SessionData:
    lang_settings = LANGUAGE_MAP.get(language, LANGUAGE_MAP["English"])
    session = {
        "user_id": user_id,
        "target_number": target_number,
        "start_time": time.time(),
        "to_app_queue": asyncio.Queue(),
        "from_app_queue": asyncio.Queue(),
        "language": language,
        "stt_lang": lang_settings["stt"],
        "target_lang": lang_settings["target"],
        "stream_sid": None,
        "greeting_text": greeting_text,
        "ai_mediation": ai_mediation,
        "voice_preset": voice_preset,
        "twilio_call_sid": None,
        "conversation_history": [],
        "full_logs": [],
        "db_id": db_id,
    }
    active_calls[call_id] = session
    return session


def get_session(call_id: str) -> SessionData | None:
    return active_calls.get(call_id)


def has_session(call_id: str) -> bool:
    return call_id in active_calls


def delete_session(call_id: str) -> None:
    active_calls.pop(call_id, None)


def set_twilio_call_sid(call_id: str, twilio_call_sid: str) -> None:
    session = get_session(call_id)
    if session is not None:
        session["twilio_call_sid"] = twilio_call_sid


def set_stream_sid(call_id: str, stream_sid: str) -> None:
    session = get_session(call_id)
    if session is not None:
        session["stream_sid"] = stream_sid

