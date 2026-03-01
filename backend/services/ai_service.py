import json
from config import groq_client, openai_client
from utils.audio import convert_pcm_to_mulaw

# --- Global Caches ---
TTS_CACHE = {}
MP3_CACHE = {}
TRANSLATION_CACHE = {} # (text, target_lang) -> translated_text

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
                {"role": "system", "content": f"You are a professional interpreter. Translate the following text into {target_lang}. Output ONLY the translated text. Do not include any explanations or notes."},
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
1. Translate the 'Current Input' to {target_lang}.
2. IF the input is garbled/noisy BUT the meaning is clear from 'Context', provide a 'refined' version.
3. [CRITICAL] Do NOT hallucinate. If the input is too ambiguous or just noise, return 'refined': null.
4. If 'refined' changes the meaning significantly from the phonetic sound of the input, discard it.

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

async def text_to_speech_multilingual(text, voice="alloy", use_cache=True):
    if use_cache:
        if (text, voice) in TTS_CACHE:
            return TTS_CACHE[(text, voice)]

    try:
        response = await openai_client.audio.speech.create(
            model="tts-1", voice=voice, input=text, response_format="pcm"
        )
        pcm_24k = response.content
        pcm_8k = b"".join(pcm_24k[i:i+2] for i in range(0, len(pcm_24k), 6) if i + 2 <= len(pcm_24k))
        audio = convert_pcm_to_mulaw(pcm_8k)
        
        if use_cache and audio:
            TTS_CACHE[(text, voice)] = audio
            
        return audio
    except Exception as e:
        print(f"TTS Error: {e}"); return None

async def text_to_speech_mp3(text, voice="alloy"):
    # MP3 캐시는 미리듣기용이므로 별도 관리
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
        print(f"TTS MP3 Error: {e}"); return None

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