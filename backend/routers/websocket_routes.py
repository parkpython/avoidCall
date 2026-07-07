import json
import asyncio
import base64
import re
from datetime import datetime, timezone
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

import config
from config import GREETINGS
from security import auth_is_disabled_for_local_dev, require_authenticated_websocket
from services import ai_service, call_runtime_service, call_session_service, db_service

from deepgram import LiveOptions, LiveTranscriptionEvents

router = APIRouter()
_CONTROL_CHARS = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
_MAX_APP_MESSAGE_BYTES = 2048
_MAX_FRONTEND_TEXT_CHARS = 500


def _local_translate(text: str, target_lang: str, ai_mediation: bool) -> str:
    if not ai_mediation:
        return text
    return f"[local {target_lang}] {text}"


def _local_responder_text(user_text: str) -> tuple[str, str, list[str]]:
    normalized = user_text.strip()
    if any(word in normalized for word in ("예약", "reserve", "reservation")):
        return (
            "Local test responder: reservation is available.",
            "로컬 테스트 응답: 예약 가능합니다.",
            ["몇 시로 예약해드릴까요?", "성함을 알려주시겠어요?", "인원은 몇 명인가요?"],
        )
    if any(word in normalized for word in ("주차", "parking")):
        return (
            "Local test responder: parking is available behind the building.",
            "로컬 테스트 응답: 건물 뒤편에 주차 가능합니다.",
            ["주차 위치를 다시 알려주세요.", "몇 시간까지 가능한가요?", "감사합니다."],
        )
    return (
        "Local test responder: I heard you. Please continue.",
        "로컬 테스트 응답: 잘 들었습니다. 계속 말씀해주세요.",
        ["네, 알겠습니다.", "잠시만 기다려주세요.", "다시 한번 말씀해주시겠어요?"],
    )


async def _run_local_call_simulator(call_id: str, call_info: dict) -> None:
    target_lang = call_info["target_lang"]
    ai_mediation = call_info.get("ai_mediation", True)

    await call_runtime_service.send_to_app(call_info, {"type": "call_connected"})
    await call_runtime_service.send_to_app(
        call_info,
        {
            "type": "translation",
            "original": "System",
            "translated": "(Local test call connected. No Twilio, Deepgram, or OpenAI calls are being made.)",
        },
    )

    try:
        while True:
            user_text = await call_runtime_service.next_user_text(call_info)
            if user_text == "HANG_UP":
                break

            translated_text = _local_translate(user_text, target_lang, ai_mediation)
            call_runtime_service.append_log(
                call_info,
                original=user_text,
                translated=translated_text,
                is_user=True,
            )
            await call_runtime_service.send_to_app(
                call_info,
                {
                    "type": "user_text",
                    "original": user_text,
                    "translated": translated_text,
                },
            )

            await asyncio.sleep(0.35)
            original, translated, suggestions = _local_responder_text(user_text)
            call_runtime_service.append_conversation_history(
                call_info,
                "Other",
                translated,
            )
            call_runtime_service.append_log(
                call_info,
                original=original,
                translated=translated,
                is_user=False,
            )
            await call_runtime_service.send_to_app(
                call_info,
                {
                    "type": "translation",
                    "original": original,
                    "translated": translated,
                    "refined": None,
                },
            )
            await call_runtime_service.send_to_app(
                call_info,
                {"type": "suggestions_update", "suggestions": suggestions},
            )
    finally:
        await call_runtime_service.send_to_app(call_info, {"type": "call_ended"})
        await call_runtime_service.send_hang_up(call_info)
        call_session_service.delete_session(call_id)


# 1. WebSocket for the Frontend App
@router.websocket("/ws/app/{call_id}")
async def websocket_app_endpoint(websocket: WebSocket, call_id: str):
    current_user = await require_authenticated_websocket(websocket)
    if current_user is None:
        return

    await websocket.accept()
    call_info = call_session_service.get_session(call_id)
    if call_info is None:
        await websocket.close(code=1011, reason="Call ID not found.")
        return

    if (
        not auth_is_disabled_for_local_dev()
        and call_info.get("user_id") != current_user.user_id
    ):
        await websocket.close(code=1008, reason="Call ownership mismatch.")
        return
    
    async def listen_to_app():
        try:
            while True:
                msg = await websocket.receive_text()
                if len(msg.encode("utf-8")) > _MAX_APP_MESSAGE_BYTES:
                    await websocket.close(code=1009, reason="Message too large.")
                    await call_runtime_service.queue_user_text(call_info, "HANG_UP")
                    break
                try:
                    data = json.loads(msg)
                except json.JSONDecodeError:
                    await websocket.close(code=1003, reason="Invalid JSON.")
                    await call_runtime_service.queue_user_text(call_info, "HANG_UP")
                    break
                if data.get("event") == "frontend_text":
                    text = data.get("text")
                    if (
                        not isinstance(text, str)
                        or not text.strip()
                        or len(text) > _MAX_FRONTEND_TEXT_CHARS
                        or _CONTROL_CHARS.search(text)
                    ):
                        await websocket.close(code=1008, reason="Invalid text.")
                        await call_runtime_service.queue_user_text(call_info, "HANG_UP")
                        break
                    await call_runtime_service.queue_user_text(call_info, text.strip())
        except WebSocketDisconnect:
            print(f"[App:{call_id}] App disconnected.")
            await call_runtime_service.queue_user_text(call_info, "HANG_UP")

    async def send_to_app():
        try:
            while True:
                message = await call_runtime_service.next_app_message(call_info)
                if message == "HANG_UP": break
                await websocket.send_json(message)
        except WebSocketDisconnect:
            print(f"[App:{call_id}] App disconnected while sending.")
        except RuntimeError:
            pass

    tasks = [listen_to_app(), send_to_app()]
    if call_info.get("local_test_mode"):
        tasks.append(_run_local_call_simulator(call_id, call_info))

    await asyncio.gather(*tasks)

# 2. WebSocket for Twilio Media Stream
@router.websocket("/ws/twilio/{call_id}")
async def websocket_twilio_endpoint(websocket: WebSocket, call_id: str):
    await websocket.accept()
    call_info = call_session_service.get_session(call_id)
    if call_info is None:
        await websocket.close(code=1011, reason="Call ID not found.")
        return
    
    await call_runtime_service.send_to_app(call_info, {"type": "call_connected"})
    stt_lang = call_info["stt_lang"]
    target_lang = call_info["target_lang"]
    voice_preset = call_info.get("voice_preset", "alloy")
    loop = asyncio.get_running_loop()
    db_id = call_info.get("db_id")

    # --- Prefetch Greeting TTS ---
    greeting_text = GREETINGS.get(target_lang, GREETINGS["English"])
    user_greeting = call_info.get("greeting_text")

    async def resolve_greeting_text():
        final_text = greeting_text
        if user_greeting:
            if call_info.get("ai_mediation", True):
                translated = await ai_service.translate_text(
                    user_greeting,
                    target_lang,
                )
                if translated:
                    final_text = translated
            else:
                final_text = user_greeting
        return final_text

    greeting_text_task = asyncio.create_task(resolve_greeting_text())

    # --- Async Deepgram Setup ---
    deepgram_socket = config.deepgram_client.listen.live.v("1")
    deepgram_ready = asyncio.Event()

    async def setup_deepgram():
        try:
            options = LiveOptions(model="nova-2", language=stt_lang, encoding="mulaw", sample_rate=8000, smart_format=True)
            
            async def handle_deepgram_transcript(transcript):
                if len(transcript) > 0:
                    if call_info.get("ai_mediation", True):
                        history = call_info.get("conversation_history", [])
                        result = await ai_service.translate_and_refine(transcript, "Korean", history)
                        korean_translation = result.get("translated")
                        refined_translation = result.get("refined")
                    else:
                        korean_translation = transcript
                        refined_translation = None

                    if korean_translation:
                        final_text = refined_translation or korean_translation
                        call_runtime_service.append_conversation_history(call_info, "Other", final_text)
                        call_runtime_service.append_log(
                            call_info,
                            original=transcript,
                            translated=korean_translation,
                            is_user=False,
                        )

                        await call_runtime_service.send_to_app(call_info, {
                            "type": "translation",
                            "original": transcript,
                            "translated": korean_translation,
                            "refined": refined_translation
                        })

                        # 추천 답변 생성은 번역 전달을 블로킹하지 않도록 별도 태스크로 실행
                        async def _send_suggestions(text_for_suggestion):
                            suggestions = await ai_service.generate_reply_suggestions(text_for_suggestion)
                            if suggestions:
                                await call_runtime_service.send_to_app(
                                    call_info,
                                    {"type": "suggestions_update", "suggestions": suggestions},
                                )

                        asyncio.create_task(_send_suggestions(refined_translation or korean_translation))
            
            def on_deepgram_transcript_sync(self, result, **kwargs):
                transcript = result.channel.alternatives[0].transcript
                if transcript:
                    asyncio.run_coroutine_threadsafe(handle_deepgram_transcript(transcript), loop)

            deepgram_socket.on(LiveTranscriptionEvents.Transcript, on_deepgram_transcript_sync)
            
            if await loop.run_in_executor(None, lambda: deepgram_socket.start(options)) is False:
                print(f"[Twilio:{call_id}] Deepgram failed to start.")
                return
            
            deepgram_ready.set()
        except Exception as e:
            print(f"[Twilio:{call_id}] Deepgram connection failed: {e}")

    deepgram_setup_task = asyncio.create_task(setup_deepgram())

    async def process_twilio_media():
        try:
            while True:
                msg = await websocket.receive_text()
                data = json.loads(msg)
                if data['event'] == 'start':
                    call_session_service.set_stream_sid(call_id, data['start']['streamSid'])
                    if db_id: asyncio.create_task(db_service.update_call_status(db_id, "connected"))

                    final_greeting_text = await greeting_text_task
                    await call_runtime_service.send_to_app(
                        call_info,
                        {"type": "translation", "original": "System", "translated": f"(Automated Greeting: {final_greeting_text})"},
                    )

                    async for chunk in ai_service.text_to_speech_multilingual_stream(
                        final_greeting_text,
                        voice_preset,
                    ):
                        if chunk and call_info["stream_sid"]:
                            payload = base64.b64encode(chunk).decode('utf-8')
                            await websocket.send_json(
                                {
                                    "event": "media",
                                    "streamSid": call_info["stream_sid"],
                                    "media": {"payload": payload},
                                }
                            )
                elif data['event'] == 'media':
                    if not deepgram_ready.is_set(): await deepgram_ready.wait()
                    deepgram_socket.send(base64.b64decode(data['media']['payload']))
                elif data['event'] == 'stop':
                    break
        except WebSocketDisconnect:
            print(f"[Twilio:{call_id}] Twilio disconnected.")
        finally:
            await call_runtime_service.send_to_app(call_info, {"type": "call_ended"})
            await call_runtime_service.send_hang_up(call_info)
            if db_id:
                end_time = datetime.now(timezone.utc).isoformat()
                await db_service.save_conversation_log(db_id, call_info["full_logs"])
                await db_service.update_call_status(db_id, "completed", end_time)
            try: deepgram_socket.finish()
            except: pass
            call_session_service.delete_session(call_id)

    async def process_app_messages():
        try:
            while True:
                user_text = await call_runtime_service.next_user_text(call_info)
                if user_text == "HANG_UP":
                    if call_info.get("twilio_call_sid"):
                        try: config.twilio_client.calls(call_info["twilio_call_sid"]).update(status="completed")
                        except: pass
                    break
                
                translated_text = await ai_service.translate_text(user_text, target_lang) if call_info.get("ai_mediation", True) else user_text
                if translated_text:
                    call_runtime_service.append_log(
                        call_info,
                        original=user_text,
                        translated=translated_text,
                        is_user=True,
                    )
                    await call_runtime_service.send_to_app(
                        call_info,
                        {"type": "user_text", "original": user_text, "translated": translated_text},
                    )
                    # 오디오 청크가 도착하는 즉시 Twilio로 전송 (전체 완성까지 기다리지 않음)
                    async for chunk in ai_service.text_to_speech_multilingual_stream(translated_text, voice_preset):
                        if chunk and call_info["stream_sid"]:
                            payload = base64.b64encode(chunk).decode('utf-8')
                            await websocket.send_json({"event": "media", "streamSid": call_info["stream_sid"], "media": {"payload": payload}})
        except asyncio.CancelledError: pass

    await asyncio.gather(process_twilio_media(), process_app_messages())
