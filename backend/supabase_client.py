import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()


def _env_flag(name: str, default: bool = False) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


APP_MODE = os.getenv("APP_MODE", os.getenv("ENVIRONMENT", "development")).strip().lower()
LOCAL_TEST_MODE = APP_MODE in {"local", "local_test", "test"} or _env_flag(
    "LOCAL_TEST_MODE",
    default=False,
)
SUPABASE_URL = os.getenv("SUPABASE_URL")
# [Fix] 백엔드에서는 RLS를 우회하기 위해 Service Role Key를 우선 사용합니다.
# .env 파일에 SUPABASE_SERVICE_ROLE_KEY를 추가하거나 SUPABASE_KEY에 Service Role Key를 넣으세요.
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY")

if LOCAL_TEST_MODE:
    print("ℹ️ [Supabase] Local test mode: skipping Supabase client initialization.")
    supabase = None
elif not SUPABASE_URL or not SUPABASE_KEY:
    print("❌ [Supabase] Warning: SUPABASE_URL or SUPABASE_KEY not found in environment variables.")
    supabase = None
else:
    print(f"✅ [Supabase] Initializing client with URL: {SUPABASE_URL}")

    # Initialize the Supabase client
    try:
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("✅ [Supabase] Client initialized successfully.")
    except Exception as e:
        print(f"❌ [Supabase] Client initialization failed: {e}")
        supabase = None
