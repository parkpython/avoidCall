import asyncio
import traceback
from datetime import datetime, timezone
from supabase_client import supabase

async def create_call_log(device_id, target_number, language):
    """통화 시작 시 로그를 생성하고 ID를 반환합니다."""
    if not supabase: return None
    try:
        data = {
            "device_id": device_id,
            "target_number": target_number,
            "language": language,
            "status": "dialing"
        }
        print(f"🛠️ [Supabase] Creating call log: {data}")
        loop = asyncio.get_running_loop()
        res = await loop.run_in_executor(
            None, 
            lambda: supabase.table("call_logs").insert(data).execute()
        )
        if res.data:
            db_id = res.data[0]['id']
            print(f"✅ [Supabase] Call Log Created. DB_ID: {db_id}")
            return db_id
    except Exception as e:
        print(f"⚠️ [Supabase] Failed to create call log: {e}")
        traceback.print_exc()
    return None

async def update_call_status(db_id, status, ended_at=None):
    """통화 상태를 업데이트합니다 (connected, completed 등)."""
    if not supabase or not db_id: return
    try:
        data = {"status": status}
        if ended_at:
            data["ended_at"] = ended_at
            
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(
            None,
            lambda: supabase.table("call_logs").update(data).eq("id", db_id).execute()
        )
    except Exception as e:
        print(f"⚠️ [Supabase] Failed to update status to {status}: {e}")

async def save_conversation_log(db_id, logs):
    """통화 종료 후 대화 내용을 한 번에 저장합니다."""
    if not supabase or not db_id: return
    try:
        # call_logs 테이블에 transcript 컬럼(JSONB)이 있다고 가정합니다.
        data = {"transcript": logs}
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(None, lambda: supabase.table("call_logs").update(data).eq("id", db_id).execute())
        print(f"✅ [Supabase] Saved conversation log for {db_id}")
    except Exception as e:
        print(f"⚠️ [Supabase] Failed to save conversation log: {e}")