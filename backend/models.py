from pydantic import BaseModel
from typing import Optional

class CallRequest(BaseModel):
    user_id: str  # 사용자 식별 ID (Device ID 또는 User ID)
    target_number: str
    language: str
    greeting_text: Optional[str] = None  # 사용자가 설정한 인삿말 (옵션)
    ai_mediation: bool = True  # AI 번역 사용 여부 (기본값 True)
    voice_preset: str = "alloy" # TTS 목소리 선택

class PrefetchRequest(BaseModel):
    text: str
    language: str
    voice_preset: str = "alloy"

class PreviewRequest(BaseModel):
    text: str
    voice_preset: str = "alloy"