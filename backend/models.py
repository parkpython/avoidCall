import re
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


_E164_PHONE_NUMBER = re.compile(r"^\+[1-9]\d{7,14}$")
_ALLOWED_LANGUAGES = frozenset(
    {"English", "Japanese", "Chinese", "Spanish", "Dutch"}
)
_ALLOWED_VOICES = frozenset({"alloy", "echo", "shimmer"})
_CONTROL_CHARS = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")


class StrictRequestModel(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    @classmethod
    def _reject_control_chars(cls, value: str) -> str:
        if _CONTROL_CHARS.search(value):
            raise ValueError("Control characters are not allowed.")
        return value


class CallRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    user_id: str = Field(min_length=1, max_length=128)
    target_number: str = Field(min_length=9, max_length=16)
    language: str = Field(max_length=32)
    greeting_text: Optional[str] = Field(default=None, max_length=500)
    ai_mediation: bool = True  # AI 번역 사용 여부 (기본값 True)
    voice_preset: str = Field(default="alloy", max_length=32)

    @field_validator("target_number")
    @classmethod
    def validate_target_number(cls, value: str) -> str:
        if not _E164_PHONE_NUMBER.fullmatch(value):
            raise ValueError("target_number must be an E.164 phone number.")
        return value

    @field_validator("language")
    @classmethod
    def validate_language(cls, value: str) -> str:
        if value not in _ALLOWED_LANGUAGES:
            raise ValueError("Unsupported language.")
        return value

    @field_validator("voice_preset")
    @classmethod
    def validate_voice_preset(cls, value: str) -> str:
        normalized = value.lower()
        if normalized not in _ALLOWED_VOICES:
            raise ValueError("Unsupported voice preset.")
        return normalized

    @field_validator("greeting_text")
    @classmethod
    def validate_greeting_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = StrictRequestModel._reject_control_chars(value)
        return value or None


class PrefetchRequest(StrictRequestModel):
    text: str = Field(min_length=1, max_length=500)
    language: str = Field(max_length=32)
    voice_preset: str = Field(default="alloy", max_length=32)

    @field_validator("text")
    @classmethod
    def validate_text(cls, value: str) -> str:
        return cls._reject_control_chars(value)

    @field_validator("language")
    @classmethod
    def validate_language(cls, value: str) -> str:
        if value not in _ALLOWED_LANGUAGES:
            raise ValueError("Unsupported language.")
        return value

    @field_validator("voice_preset")
    @classmethod
    def validate_voice_preset(cls, value: str) -> str:
        normalized = value.lower()
        if normalized not in _ALLOWED_VOICES:
            raise ValueError("Unsupported voice preset.")
        return normalized


class PreviewRequest(StrictRequestModel):
    text: str = Field(min_length=1, max_length=500)
    voice_preset: str = Field(default="alloy", max_length=32)

    @field_validator("text")
    @classmethod
    def validate_text(cls, value: str) -> str:
        return cls._reject_control_chars(value)

    @field_validator("voice_preset")
    @classmethod
    def validate_voice_preset(cls, value: str) -> str:
        normalized = value.lower()
        if normalized not in _ALLOWED_VOICES:
            raise ValueError("Unsupported voice preset.")
        return normalized
