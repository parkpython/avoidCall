import json
import re
from config import groq_client, openai_client

try:
    import audioop
except ModuleNotFoundError:
    audioop = None

# --- Global Caches ---
TTS_CACHE = {}
MP3_CACHE = {}
TRANSLATION_CACHE = {}  # (text, target_lang) -> translated_text

# 통화 경로에서 현재 UI와 동기화된 voice만 허용
_ALLOWED_VOICES = frozenset({"alloy", "echo", "shimmer"})
_PHONE_TTS_SPEED = 1.18
_TTS_CHUNK_SIZE = 1600


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
    "You are a text-to-speech engine for relaying the user's written message during a phone call. "
    "Your only task is to speak the provided text exactly as written. "
    "Do not answer, interpret, summarize, paraphrase, translate, or generate any original content. "
    "Do not add greetings, filler words, reactions, confirmations, or emotional interjections unless they are explicitly present in the text. "
    "Do not omit, rewrite, soften, or intensify any part of the text. "
    "Speak only the provided text verbatim, with clear and natural phone-call delivery."
)


def _normalize_phone_tts_text(text: str) -> str:
    cleaned = re.sub(r"\s+", " ", text).strip()
    cleaned = cleaned.replace("...", ". ")
    cleaned = re.sub(r"[!?]{2,}", "!", cleaned)
    cleaned = re.sub(r"\.{2,}", ".", cleaned)
    cleaned = re.sub(r"[,]{2,}", ",", cleaned)
    cleaned = re.sub(r"([가-힣A-Za-z0-9])([/|])([가-힣A-Za-z0-9])", r"\1, \3", cleaned)
    return cleaned


def _segment_phone_tts_text(text: str) -> list[str]:
    normalized = _normalize_phone_tts_text(text)
    if not normalized:
        return []

    parts = re.split(r"(?<=[.!?。！？])\s+|(?<=,)\s+", normalized)
    segments: list[str] = []
    current = ""

    for raw_part in parts:
        part = raw_part.strip()
        if not part:
            continue

        candidate = part if not current else f"{current} {part}"
        if len(candidate) <= 90:
            current = candidate
            continue

        if current:
            segments.append(current)
        current = part

    if current:
        segments.append(current)

    return segments or [normalized]


def _pcm24khz_to_mulaw8khz(pcm_audio: bytes) -> bytes:
    """Convert 24kHz 16-bit PCM from OpenAI speech API into 8kHz μ-law for Twilio."""
    if audioop is None:
        raise RuntimeError("audioop is required for Twilio audio conversion.")
    downsampled, _ = audioop.ratecv(pcm_audio, 2, 1, 24000, 8000, None)
    return audioop.lin2ulaw(downsampled, 2)


async def _render_mulaw_tts(text, voice="alloy"):
    if not text or not str(text).strip():
        return b""

    voice = _normalize_voice(voice)
    cache_key = (text, f"{voice}-ulaw")
    if cache_key in TTS_CACHE:
        return TTS_CACHE[cache_key]

    response = await openai_client.audio.speech.create(
        model="gpt-4o-mini-tts",
        voice=voice,
        input=text,
        instructions=_TTS_INSTRUCTION,
        response_format="pcm",
        speed=_PHONE_TTS_SPEED,
    )

    pcm_audio = response.content
    if not pcm_audio:
        return b""

    mulaw_audio = _pcm24khz_to_mulaw8khz(pcm_audio)
    TTS_CACHE[cache_key] = mulaw_audio
    return mulaw_audio

async def text_to_speech_multilingual_stream(text, voice="alloy"):
    """
    Deterministic TTS path for Twilio playback.
    Generate μ-law audio once, cache it, then yield fixed-size chunks.
    """
    if not text or not str(text).strip():
        return
    voice = _normalize_voice(voice)
    try:
        for segment in _segment_phone_tts_text(str(text)):
            audio = await _render_mulaw_tts(segment, voice)
            for index in range(0, len(audio), _TTS_CHUNK_SIZE):
                yield audio[index:index + _TTS_CHUNK_SIZE]
    except Exception as e:
        print(f"TTS Speech API Error: {e}")
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
