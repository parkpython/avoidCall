import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("❌ [Supabase] Warning: SUPABASE_URL or SUPABASE_KEY not found in environment variables.")
else:
    print(f"✅ [Supabase] Initializing client with URL: {SUPABASE_URL}")

# Initialize the Supabase client
try:
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    print("✅ [Supabase] Client initialized successfully.")
except Exception as e:
    print(f"❌ [Supabase] Client initialization failed: {e}")
    supabase = None
