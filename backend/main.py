import os

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse

import config
from routers import http_routes, websocket_routes
from security import client_identity_from_request, enforce_rate_limit


def _csv_env(name: str) -> list[str]:
    return [
        item.strip()
        for item in os.getenv(name, "").split(",")
        if item.strip()
    ]


def _int_env(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, str(default)))
    except ValueError:
        return default


_ENVIRONMENT = os.getenv("ENVIRONMENT", "development").lower()
_PRODUCTION = _ENVIRONMENT == "production"
_MAX_REQUEST_BODY_BYTES = _int_env("MAX_REQUEST_BODY_BYTES", 64 * 1024)
_GLOBAL_RATE_LIMIT_EXEMPT_PATHS = {"/healthz"}

app = FastAPI(
    docs_url=None if _PRODUCTION else "/docs",
    redoc_url=None if _PRODUCTION else "/redoc",
    openapi_url=None if _PRODUCTION else "/openapi.json",
)

allowed_hosts = _csv_env("ALLOWED_HOSTS")
if allowed_hosts:
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=allowed_hosts)

allowed_origins = _csv_env("CORS_ALLOWED_ORIGINS")
if allowed_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins,
        allow_credentials=False,
        allow_methods=["POST", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type"],
    )


@app.middleware("http")
async def reject_large_requests(request: Request, call_next):
    content_length = request.headers.get("content-length")
    try:
        request_size = int(content_length) if content_length else 0
    except ValueError:
        request_size = _MAX_REQUEST_BODY_BYTES + 1

    if request_size > _MAX_REQUEST_BODY_BYTES:
        return JSONResponse(
            status_code=413,
            content={"detail": "Request body too large."},
        )
    return await call_next(request)


@app.middleware("http")
async def enforce_global_http_rate_limit(request: Request, call_next):
    if (
        request.url.path not in _GLOBAL_RATE_LIMIT_EXEMPT_PATHS
        and config.GLOBAL_HTTP_RATE_LIMIT_PER_IP_PER_MINUTE > 0
    ):
        try:
            enforce_rate_limit(
                identity=client_identity_from_request(request),
                action="http",
                limit=config.GLOBAL_HTTP_RATE_LIMIT_PER_IP_PER_MINUTE,
                window_seconds=60,
            )
        except HTTPException as exc:
            return JSONResponse(
                status_code=exc.status_code,
                content={"detail": exc.detail},
            )

    return await call_next(request)


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Referrer-Policy", "no-referrer")
    response.headers.setdefault(
        "Permissions-Policy",
        "camera=(), microphone=(), geolocation=()",
    )
    if _PRODUCTION:
        response.headers.setdefault(
            "Strict-Transport-Security",
            "max-age=31536000; includeSubDomains",
        )
    return response


@app.get("/")
async def root():
    return {
        "status": "ok",
        "service": "avoid-call-backend",
        "mode": _ENVIRONMENT,
        "local_test_mode": config.LOCAL_TEST_MODE,
        "local_outbound_calls": config.LOCAL_OUTBOUND_CALLS,
        "endpoints": ["/healthz", "/call", "/preview-voice", "/prefetch", "/ws/app/{call_id}"],
    }


@app.get("/healthz")
async def healthz():
    return {
        "status": "ok",
        "service": "avoid-call-backend",
        "local_test_mode": config.LOCAL_TEST_MODE,
        "local_outbound_calls": config.LOCAL_OUTBOUND_CALLS,
    }


# Include Routers
app.include_router(http_routes.router)
app.include_router(websocket_routes.router)
