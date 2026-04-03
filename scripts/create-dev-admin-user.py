#!/usr/bin/env python3
from __future__ import annotations

import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from supabase import Client, create_client


ROOT_DIR = Path(__file__).resolve().parents[1]


def load_local_env() -> None:
    load_dotenv(ROOT_DIR / "backend" / ".env")
    load_dotenv(ROOT_DIR / ".env")


def require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def create_supabase_admin_client() -> Client:
    supabase_url = require_env("SUPABASE_URL")
    service_role_key = require_env("SUPABASE_SERVICE_ROLE_KEY")
    return create_client(supabase_url, service_role_key)


def response_data(response: Any) -> Any:
    if hasattr(response, "data"):
        return response.data
    return response


def response_users(response: Any) -> list[Any]:
    if hasattr(response, "users"):
        return list(response.users or [])
    if isinstance(response, dict):
        users = response.get("users")
        if isinstance(users, list):
            return users
    return []


def response_user(response: Any) -> Any | None:
    if hasattr(response, "user"):
        return response.user
    if hasattr(response, "data"):
        data = response.data
        if hasattr(data, "user"):
            return data.user
        if read_attr(data, "id") is not None:
            return data
    if isinstance(response, dict):
        if isinstance(response.get("user"), dict):
            return response["user"]
        data = response.get("data")
        if isinstance(data, dict) and data.get("id") is not None:
            return data
    return None


def read_attr(item: Any, key: str, default: Any = None) -> Any:
    if isinstance(item, dict):
        return item.get(key, default)
    return getattr(item, key, default)


def find_user_by_email(client: Client, email: str) -> Any | None:
    page = 1
    while True:
        try:
            result = client.auth.admin.list_users(page=page, per_page=200)
        except TypeError:
            result = client.auth.admin.list_users()

        users = response_users(result)
        if not users:
            return None

        for user in users:
            if str(read_attr(user, "email", "")).lower() == email.lower():
                return user

        if len(users) < 200:
            return None
        page += 1


def ensure_auth_user(client: Client, email: str, password: str, name: str) -> Any:
    existing_user = find_user_by_email(client, email)

    if existing_user is None:
        created = client.auth.admin.create_user(
            build_user_attributes(email=email, password=password, name=name)
        )
        created_user = response_user(created)
        if created_user is None:
            raise SystemExit("Supabase admin create_user response did not include a user.")
        return created_user

    user_id = read_attr(existing_user, "id")
    if not user_id:
        raise SystemExit("Found existing user but could not read its id.")

    updated = client.auth.admin.update_user_by_id(
        user_id,
        build_user_attributes(email=email, password=password, name=name),
    )
    updated_user = response_user(updated)
    if updated_user is None:
        raise SystemExit("Supabase admin update_user_by_id response did not include a user.")
    return updated_user


def build_user_attributes(email: str, password: str, name: str) -> dict[str, Any]:
    return {
        "email": email,
        "password": password,
        "email_confirm": True,
        "user_metadata": {"name": name},
    }


def ensure_profile(client: Client, user_id: str, email: str) -> None:
    client.table("profiles").upsert(
        {
            "id": user_id,
            "email": email,
        },
        on_conflict="id",
    ).execute()


def ensure_plan_exists(client: Client, plan_id: str) -> None:
    result = (
        client.table("subscription_plans")
        .select("plan_id")
        .eq("plan_id", plan_id)
        .limit(1)
        .execute()
    )
    rows = response_data(result) or []
    if not rows:
        raise SystemExit(
            f"subscription_plans does not contain plan_id='{plan_id}'."
        )


def ensure_active_subscription(client: Client, user_id: str, plan_id: str) -> None:
    now = datetime.now(timezone.utc)
    end = now + timedelta(days=3650)
    seed_subscription_id = f"dev-seed-{user_id}"

    existing_result = (
        client.table("user_subscriptions")
        .select("id, status, current_period_end")
        .eq("user_id", user_id)
        .order("current_period_end", desc=True)
        .limit(1)
        .execute()
    )
    existing_rows = response_data(existing_result) or []
    existing_row = existing_rows[0] if existing_rows else None

    payload = {
        "user_id": user_id,
        "plan_id": plan_id,
        "stripe_subscription_id": seed_subscription_id,
        "status": "active",
        "current_period_start": now.isoformat(),
        "current_period_end": end.isoformat(),
        "cancel_at_period_end": False,
        "provider": "dev_seed",
        "provider_product_id": plan_id,
        "provider_transaction_id": seed_subscription_id,
        "original_transaction_id": seed_subscription_id,
        "environment": "development",
        "verification_status": "seeded",
        "entitlement_source": "dev_script",
        "raw": {
            "seeded_by": "scripts/create-dev-admin-user.py",
            "seeded_at": now.isoformat(),
        },
    }

    if existing_row and read_attr(existing_row, "id") is not None:
        (
            client.table("user_subscriptions")
            .update(payload)
            .eq("id", read_attr(existing_row, "id"))
            .execute()
        )
        return

    client.table("user_subscriptions").insert(payload).execute()


def main() -> None:
    load_local_env()

    email = require_env("DEV_ADMIN_EMAIL")
    password = require_env("DEV_ADMIN_PASSWORD")
    name = os.getenv("DEV_ADMIN_NAME", "Development Admin").strip() or "Development Admin"
    plan_id = os.getenv("DEV_ADMIN_PLAN_ID", "starter").strip() or "starter"

    client = create_supabase_admin_client()
    user = ensure_auth_user(client, email=email, password=password, name=name)

    user_id = read_attr(user, "id")
    if not user_id:
        raise SystemExit("Supabase admin response did not include a user id.")

    ensure_profile(client, user_id=user_id, email=email)
    ensure_plan_exists(client, plan_id=plan_id)
    ensure_active_subscription(client, user_id=user_id, plan_id=plan_id)

    print("Dev admin user is ready.")
    print(f"email={email}")
    print(f"user_id={user_id}")
    print(f"plan_id={plan_id}")
    print("The user can now sign in immediately with password auth.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
