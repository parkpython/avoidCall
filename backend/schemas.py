from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime
import uuid

# --- User Schemas ---
class UserBase(BaseModel):
    email: EmailStr

class UserLogin(UserBase):
    password: str

class UserSignup(UserBase):
    password: str

class UserProfile(UserBase):
    id: uuid.UUID
    credits: float
    created_at: datetime

    class Config:
        from_attributes = True

# --- Call Log Schemas ---
class CallLogCreate(BaseModel):
    call_uuid: str
    device_id: str
    target_number: str

class CallLogUpdate(BaseModel):
    duration_seconds: int
    cost: float
    twilio_sid: Optional[str] = None
