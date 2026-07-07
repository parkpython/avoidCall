import asyncio
import os
import time
from collections import defaultdict, deque
from dataclasses import dataclass
from typing import Deque
from urllib.parse import parse_qsl

from fastapi import Header, HTTPException, Request, WebSocket, status
from twilio.request_validator import RequestValidator

import config
from supabase_client import supabase


@dataclass(frozen=True)
class AuthenticatedUser:
    user_id: str
    access_token: str


_RATE_BUCKETS: dict[tuple[str, str], Deque[float]] = defaultdict(deque)
_AUTH_SUBPROTOCOL_PREFIX = "supabase-auth."


def _env_flag(name: str, default: bool = False) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _extract_bearer_token(authorization: str | None) -> str | None:
    if not authorization:
        return None
    scheme, _, token = authorization.strip().partition(" ")
    if scheme.lower() != "bearer" or not token:
        return None
    return token.strip()


def _extract_websocket_protocol_token(websocket: WebSocket) -> str | None:
    raw_protocols = websocket.headers.get("sec-websocket-protocol", "")
    for protocol in raw_protocols.split(","):
        protocol = protocol.strip()
        if protocol.startswith(_AUTH_SUBPROTOCOL_PREFIX):
            return protocol[len(_AUTH_SUBPROTOCOL_PREFIX):]
    return None


def auth_is_disabled_for_local_dev() -> bool:
    environment = os.getenv("ENVIRONMENT", "development").strip().lower()
    if config.LOCAL_TEST_MODE:
        return True
    return environment != "production" and _env_flag(
        "ALLOW_UNAUTHENTICATED_REQUESTS",
        default=False,
    )


async def authenticate_access_token(access_token: str) -> AuthenticatedUser:
    if auth_is_disabled_for_local_dev():
        return AuthenticatedUser(user_id="local-dev", access_token=access_token)

    if supabase is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication service is not configured.",
        )

    loop = asyncio.get_running_loop()
    try:
        response = await loop.run_in_executor(
            None,
            lambda: supabase.auth.get_user(access_token),
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token.",
        ) from None

    user = getattr(response, "user", None)
    user_id = getattr(user, "id", None)
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token.",
        )

    return AuthenticatedUser(user_id=str(user_id), access_token=access_token)


async def require_authenticated_user(
    authorization: str | None = Header(default=None),
) -> AuthenticatedUser:
    token = _extract_bearer_token(authorization)
    if not token and not auth_is_disabled_for_local_dev():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token.",
        )
    return await authenticate_access_token(token or "")


async def require_authenticated_websocket(
    websocket: WebSocket,
) -> AuthenticatedUser | None:
    token = _extract_bearer_token(websocket.headers.get("authorization"))
    token = token or _extract_websocket_protocol_token(websocket)
    token = token or websocket.query_params.get("access_token")

    if not token and not auth_is_disabled_for_local_dev():
        await websocket.close(
            code=status.WS_1008_POLICY_VIOLATION,
            reason="Authentication required.",
        )
        return None

    try:
        return await authenticate_access_token(token or "")
    except HTTPException:
        await websocket.close(
            code=status.WS_1008_POLICY_VIOLATION,
            reason="Authentication failed.",
        )
        return None


def require_matching_user(
    authenticated_user: AuthenticatedUser,
    claimed_user_id: str,
) -> None:
    if auth_is_disabled_for_local_dev():
        return

    if authenticated_user.user_id != claimed_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Authenticated user does not match request user.",
        )


def enforce_rate_limit(
    *,
    identity: str,
    action: str,
    limit: int,
    window_seconds: int,
) -> None:
    now = time.monotonic()
    bucket = _RATE_BUCKETS[(action, identity)]
    cutoff = now - window_seconds

    while bucket and bucket[0] <= cutoff:
        bucket.popleft()

    if len(bucket) >= limit:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please try again shortly.",
        )

    bucket.append(now)


def twilio_signature_validation_enabled() -> bool:
    if config.LOCAL_TEST_MODE and not config.LOCAL_OUTBOUND_CALLS:
        return False
    return _env_flag("VERIFY_TWILIO_SIGNATURES", default=True)


def _twilio_request_url(request: Request) -> str:
    if config.SERVER_DOMAIN:
        query = f"?{request.url.query}" if request.url.query else ""
        return f"https://{config.SERVER_DOMAIN}{request.url.path}{query}"
    return str(request.url)


async def require_valid_twilio_request(request: Request) -> None:
    if not twilio_signature_validation_enabled():
        return

    signature = request.headers.get("X-Twilio-Signature")
    if not signature:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Missing Twilio signature.",
        )

    if not config.TWILIO_AUTH_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Twilio signature validation is not configured.",
        )

    body = await request.body()
    params: dict[str, str] = {}
    content_type = request.headers.get("content-type", "")
    if "application/x-www-form-urlencoded" in content_type:
        params = dict(parse_qsl(body.decode("utf-8"), keep_blank_values=True))

    validator = RequestValidator(config.TWILIO_AUTH_TOKEN)
    if not validator.validate(_twilio_request_url(request), params, signature):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid Twilio signature.",
        )
