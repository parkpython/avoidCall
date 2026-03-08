import json
import asyncio
import base64
from datetime import datetime, timezone
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

import config
from config import GREETINGS
from services import ai_service, db_service
from state_manager import active_calls

from deepgram import LiveOptions, LiveTranscriptionEvents

router = APIRouter()

# 1. WebSocket for the Frontend App
@router.websocket("/ws/app/{call_id}")
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
            await call_info["from_app_queue"].put("HANG_UP")

    async def send_to_app():
        try:
            while True:
                message = await call_info["to_app_queue"].get()
                if message == "HANG_UP": break
                await websocket.send_json(message)
        except WebSocketDisconnect:
            print(f"[App:{call_id}] App disconnected while sending.")
        except RuntimeError:
            pass

    await asyncio.gather(listen_to_app(), send_to_app())

# 2. WebSocket for Twilio Media Stream
@router.websocket("/ws/twilio/{call_id}")
async def websocket_twilio_endpoint(websocket: WebSocket, call_id: str):
    await websocket.accept()
    if call_id not in active_calls:
        await websocket.close(code=1011, reason="Call ID not found.")
        return

    call_info = active_calls[call_id]
    
    await call_info["to_app_queue"].put({"type": "call_connected"})
    stt_lang = call_info["stt_lang"]
    target_lang = call_info["target_lang"]
    voice_preset = call_info.get("voice_preset", "alloy")
    loop = asyncio.get_running_loop()
    db_id = call_info.get("db_id")

    # --- Prefetch Greeting TTS ---
    greeting_text = GREETINGS.get(target_lang, GREETINGS["English"])
    user_greeting = call_info.get("greeting_text")
    
    async def prepare_greeting():
        final_text = greeting_text
        if user_greeting:
            if call_info.get("ai_mediation", True):
                translated = await ai_service.translate_text(user_greeting, target_lang)
                if translated: final_text = translated
            else:
                final_text = user_greeting
        
        audio = await ai_service.text_to_speech_multilingual(final_text, voice_preset)
        return final_text, audio

    greeting_task = asyncio.create_task(prepare_greeting())

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
                        call_info["conversation_history"].append(f"Other: {final_text}")
                        if len(call_info["conversation_history"]) > 5: call_info["conversation_history"].pop(0)

                        call_info["full_logs"].append({
                            "original": transcript,
                            "translated": korean_translation,
                            "is_user": False
                        })

                        await call_info["to_app_queue"].put({
                            "type": "translation",
                            "original": transcript,
                            "translated": korean_translation,
                            "refined": refined_translation
                        })

                        # 추천 답변 생성은 번역 전달을 블로킹하지 않도록 별도 태스크로 실행
                        async def _send_suggestions(text_for_suggestion):
                            suggestions = await ai_service.generate_reply_suggestions(text_for_suggestion)
                            if suggestions:
                                await call_info["to_app_queue"].put({"type": "suggestions_update", "suggestions": suggestions})

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
                    call_info["stream_sid"] = data['start']['streamSid']
                    if db_id: asyncio.create_task(db_service.update_call_status(db_id, "connected"))

                    final_greeting_text, greeting_audio = await greeting_task
                    await call_info["to_app_queue"].put({"type": "translation", "original": "System", "translated": f"(Automated Greeting: {final_greeting_text})"})

                    if greeting_audio:
                        payload = base64.b64encode(greeting_audio).decode('utf-8')
                        await websocket.send_json({"event": "media", "streamSid": call_info["stream_sid"], "media": {"payload": payload}})
                elif data['event'] == 'media':
                    if not deepgram_ready.is_set(): await deepgram_ready.wait()
                    deepgram_socket.send(base64.b64decode(data['media']['payload']))
                elif data['event'] == 'stop':
                    break
        except WebSocketDisconnect:
            print(f"[Twilio:{call_id}] Twilio disconnected.")
        finally:
            await call_info["to_app_queue"].put({"type": "call_ended"})
            await call_info["to_app_queue"].put("HANG_UP")
            await call_info["from_app_queue"].put("HANG_UP")
            if db_id:
                end_time = datetime.now(timezone.utc).isoformat()
                await db_service.save_conversation_log(db_id, call_info["full_logs"])
                await db_service.update_call_status(db_id, "completed", end_time)
            try: deepgram_socket.finish()
            except: pass
            if call_id in active_calls: del active_calls[call_id]

    async def process_app_messages():
        try:
            while True:
                user_text = await call_info["from_app_queue"].get()
                if user_text == "HANG_UP":
                    if call_info.get("twilio_call_sid"):
                        try: config.twilio_client.calls(call_info["twilio_call_sid"]).update(status="completed")
                        except: pass
                    break
                
                translated_text = await ai_service.translate_text(user_text, target_lang) if call_info.get("ai_mediation", True) else user_text
                if translated_text:
                    call_info["full_logs"].append({
                        "original": user_text,
                        "translated": translated_text,
                        "is_user": True
                    })
                    await call_info["to_app_queue"].put({"type": "user_text", "original": user_text, "translated": translated_text})
                    # 오디오 청크가 도착하는 즉시 Twilio로 전송 (전체 완성까지 기다리지 않음)
                    async for chunk in ai_service.text_to_speech_multilingual_stream(translated_text, voice_preset):
                        if chunk and call_info["stream_sid"]:
                            payload = base64.b64encode(chunk).decode('utf-8')
                            await websocket.send_json({"event": "media", "streamSid": call_info["stream_sid"], "media": {"payload": payload}})
        except asyncio.CancelledError: pass

    await asyncio.gather(process_twilio_media(), process_app_messages())