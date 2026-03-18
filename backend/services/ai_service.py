import json
import base64
import websockets
from config import groq_client, openai_client, OPENAI_API_KEY
# The 'convert_pcm_to_mulaw' and related libraries are no longer needed
# as OpenAI's Realtime API can output µ-law directly.

# --- Global Caches ---
TTS_CACHE = {}
MP3_CACHE = {}
TRANSLATION_CACHE = {}  # (text, target_lang) -> translated_text

# Realtime API와 TTS API 모두 지원하는 voice (프론트엔드와 동기화)
_ALLOWED_VOICES = frozenset({"alloy", "echo", "shimmer"})


def _normalize_voice(voice):
    """유효하지 않은 voice는 'alloy'로 폴백."""
    if not voice or not isinstance(voice, str):
        return "alloy"
    v = voice.strip().lower()
    return v if v in _ALLOWED_VOICES else "alloy"


async def translate_text(text, target_lang, use_cache=True):
    if not text or len(text.strip()) < 1: return None
    
    if use_cache:
        cache_key = (text, target_lang)
        if cache_key in TRANSLATION_CACHE:
            return TRANSLATION_CACHE[cache_key]

    try:
        # [Groq] 번역 모델 변경 (gpt-4o-mini -> llama3-8b-8192)
        response = await groq_client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": f"You are a professional interpreter. Translate the following text into {target_lang}. Output ONLY the translated text. Do not include any explanations or notes. If the text is meaningless or random characters, return the original text."},
                {"role": "user", "content": text}
            ],
            max_tokens=256,
            temperature=0.1
        )
        result = response.choices[0].message.content.strip()
        
        if use_cache and result:
            TRANSLATION_CACHE[(text, target_lang)] = result
            
        return result
    except Exception as e:
        print(f"Translation Error: {e}")
        return None

async def translate_and_refine(text, target_lang, context_history=[]):
    """
    번역과 보정을 수행하되, 원본과 너무 동떨어진 보정은 거부합니다.
    context_history: 이전 대화 내용 리스트 (최근 2개 정도)
    """
    if not text or len(text.strip()) < 1: return {"translated": "", "refined": None}
    
    # [전략 2] 이전 대화 맥락을 프롬프트에 녹임
    recent_context = "\n".join([f"- {msg}" for msg in context_history[-2:]])
    
    try:
        response = await groq_client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": f"""You are a conservative interpreter.
Target Language: {target_lang}

Rules:
1. Translate the 'Current Input' to {target_lang}. If the input is meaningless, random characters, or noise, return the original input in 'translated'.
2. [STRICT] Do NOT provide explanations, notes, or apologies (e.g., "I cannot translate..."). NEVER output a sentence describing the input.
3. IF the input is garbled/noisy BUT the meaning is clear from 'Context', provide a 'refined' version.
4. [CRITICAL] Do NOT hallucinate. If the input is too ambiguous or just noise, return 'refined': null.
5. If 'refined' changes the meaning significantly from the phonetic sound of the input, discard it.

Output JSON: {{ "translated": "...", "refined": "..." or null }}"""},
                
                {"role": "user", "content": f"""Context:
{recent_context}

Current Input: {text}"""}
            ],
            response_format={"type": "json_object"},
            temperature=0.0 # [전략 1] 창의성 0으로 설정 (매우 중요!)
        )
        
        result = json.loads(response.choices[0].message.content)
        translated = result.get("translated", "")
        refined = result.get("refined")

        # [전략 3] 안전장치: 원본 길이와 너무 차이가 나면 의심 (예: '으어' -> '안녕하세요 반갑습니다')
        if refined:
            # 원본 길이 대비 4배 이상 길어지면 환각일 가능성 높음 (영어/한국어 차이 고려해도 과함)
            if len(refined) > len(text) * 4: 
                refined = None
            
        return {"translated": translated, "refined": refined}

    except Exception as e:
        print(f"Refinement Error: {e}")
        # JSON 파싱 실패 시 기본 번역만 반환
        basic = await translate_text(text, target_lang)
        return {"translated": basic, "refined": None}

_TTS_INSTRUCTION = (
    "You are a strict text-to-speech engine. "
    "Your ONLY job is to read the user's text aloud, word-for-word, exactly as given. "
    "Do NOT answer, explain, add greetings, or generate any content of your own. "
    "Just speak the text verbatim."
)
_TTS_URI = "wss://api.openai.com/v1/realtime?model=gpt-4o-mini-realtime-preview"

async def text_to_speech_multilingual_stream(text, voice="alloy"):
    """
    OpenAI Realtime API에서 오디오 청크를 받는 즉시 yield하는 async generator.
    모든 청크를 수신한 후에는 TTS_CACHE에 조립 결과를 저장한다.
    캐시 히트 시에는 저장된 전체 오디오를 단일 청크로 즉시 yield한다.
    """
    if not text or not str(text).strip():
        return
    voice = _normalize_voice(voice)
    cache_key = (text, f"{voice}-ulaw")
    if cache_key in TTS_CACHE:
        yield TTS_CACHE[cache_key]
        return

    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "OpenAI-Beta": "realtime=v1"
    }

    try:
        async with websockets.connect(_TTS_URI, additional_headers=headers) as websocket:
            await websocket.send(json.dumps({
                "type": "session.update",
                "session": {
                    "voice": voice,
                    "output_audio_format": "g711_ulaw",
                    "turn_detection": None,
                    "instructions": _TTS_INSTRUCTION
                }
            }))
            await websocket.send(json.dumps({
                "type": "conversation.item.create",
                "item": {
                    "type": "message",
                    "role": "user",
                    "content": [{"type": "input_text", "text": text}]
                }
            }))
            await websocket.send(json.dumps({
                "type": "response.create",
                "response": {
                    "modalities": ["audio", "text"], # OpenAI 규격: audio 단독 지정 불가, text 반드시 포함
                    "instructions": _TTS_INSTRUCTION
                }
            }))

            collected = []
            while True:
                message = json.loads(await websocket.recv())
                msg_type = message.get("type")

                if msg_type == "response.audio.delta":
                    chunk = base64.b64decode(message["delta"])
                    collected.append(chunk)
                    yield chunk  # 청크 도착 즉시 호출자에게 전달

                elif msg_type in ["response.audio.done", "response.done"]:
                    break

                elif msg_type == "error":
                    err = message.get("error", {})
                    err_msg = err.get("message", err) if isinstance(err, dict) else err
                    print(f"OpenAI Realtime TTS Error: {err_msg}")
                    return

        if collected:
            TTS_CACHE[cache_key] = b"".join(collected)

    except Exception as e:
        print(f"TTS Realtime API Error: {e}")
        return


async def text_to_speech_multilingual(text, voice="alloy", use_cache=True):
    """
    전체 오디오가 필요한 경우(인사말 프리패치 등) 사용.
    내부적으로 스트리밍 제너레이터를 소비하여 단일 bytes로 반환한다.
    """
    if not text or not str(text).strip():
        return None
    voice = _normalize_voice(voice)
    cache_key = (text, f"{voice}-ulaw")
    if use_cache and cache_key in TTS_CACHE:
        return TTS_CACHE[cache_key]

    chunks = [chunk async for chunk in text_to_speech_multilingual_stream(text, voice)]
    return b"".join(chunks) or None


async def text_to_speech_mp3(text, voice="alloy"):
    """미리듣기용 MP3 오디오 생성."""
    if not text or not str(text).strip():
        return None
    voice = _normalize_voice(voice)
    if (text, voice) in MP3_CACHE:
        return MP3_CACHE[(text, voice)]

    try:
        response = await openai_client.audio.speech.create(
            model="tts-1", voice=voice, input=text, response_format="mp3"
        )
        audio = response.content
        if audio:
            MP3_CACHE[(text, voice)] = audio
        return audio
    except Exception as e:
        print(f"TTS MP3 Error: {e}")
        return None

async def generate_reply_suggestions(text):
    """GPT-4o-mini를 사용하여 짧은 한국어 답변 3개를 생성합니다."""
    if not text: return []
    try:
        # [Groq] 추천 답변 모델 변경 (gpt-4o-mini -> llama3-8b-8192)
        response = await groq_client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": "Analyze the input and provide 3 short, natural Korean reply suggestions. Output JSON object with key 'suggestions' containing a list of strings."},
                {"role": "user", "content": text}
            ],
            response_format={"type": "json_object"},
            temperature=0.3
        )
        content = response.choices[0].message.content
        data = json.loads(content)
        return data.get("suggestions", [])
    except Exception as e:
        print(f"Suggestion Error: {e}")
        return []