import asyncio
import hmac
import json
import os
import shlex
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple
from urllib import parse, request

from fastapi import FastAPI, HTTPException, Request

import openclaw_ops_tasks as task_runner


app = FastAPI(title="OpenClaw Ops")
_MAX_TELEGRAM_WEBHOOK_BYTES = 64 * 1024


def _state_root() -> Path:
    return Path(os.getenv("OPENCLAW_STATE_DIR", "/data/openclaw-ops"))


def _required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"{name} is required")
    return value


def _allowed_chat_ids() -> set[int]:
    raw = os.getenv("TELEGRAM_ALLOWED_CHAT_IDS", "").strip()
    if not raw:
        return set()

    allowed: Set[int] = set()
    for chunk in raw.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        allowed.add(int(chunk))
    return allowed


def _task_map() -> Dict[str, List[str]]:
    tasks: Dict[str, List[str]] = {}
    prefix = "OPENCLAW_TASK_"
    for key, value in os.environ.items():
        if not key.startswith(prefix):
            continue
        task_name = key[len(prefix):].strip().lower()
        command = shlex.split(value)
        if task_name and command:
            tasks[task_name] = command
    return tasks


def _log_event(event: str, **fields: Any) -> None:
    payload = {"event": event, "service": "openclaw-ops", **fields}
    line = json.dumps(payload, sort_keys=True)
    print(line, flush=True)

    log_path = Path(os.getenv("OPENCLAW_OPS_LOG_PATH", str(_state_root() / "openclaw-ops.log")))
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as fh:
        fh.write(f"{line}\n")


def _extract_message(update: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    for key in ("message", "edited_message"):
        candidate = update.get(key)
        if isinstance(candidate, dict):
            return candidate
    return None


async def _send_telegram_message(chat_id: int, text: str) -> None:
    token = _required_env("TELEGRAM_BOT_TOKEN")
    payload = parse.urlencode(
        {
            "chat_id": str(chat_id),
            "text": text[:4000],
        }
    ).encode()

    def _send() -> None:
        req = request.Request(
            f"https://api.telegram.org/bot{token}/sendMessage",
            data=payload,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            method="POST",
        )
        with request.urlopen(req, timeout=15) as response:
            response.read()

    await asyncio.to_thread(_send)


async def _run_task(task_name: str, command: List[str]) -> Tuple[int, str]:
    _log_event("telegram_task_direct_dispatch", task_name=task_name, command=command)
    output = await asyncio.to_thread(task_runner.run_task, task_name)
    return 0, output or "(no output)"


def _help_text(tasks: Dict[str, List[str]]) -> str:
    available = ", ".join(f"/task {name}" for name in sorted(tasks)) or "No tasks configured"
    return "\n".join(
        [
            "OpenClaw ops bot",
            "/health - service health",
            "/tasks - list configured tasks",
            "/task <name> - run a configured task",
            f"Configured tasks: {available}",
        ]
    )


@app.get("/healthz")
async def healthz() -> dict[str, Any]:
    tasks = _task_map()
    return {
        "status": "ok",
        "service": "openclaw-ops",
        "state_dir": str(_state_root()),
        "configured_tasks": sorted(tasks),
    }


@app.post("/telegram/webhook/{secret}")
async def telegram_webhook(secret: str, request: Request) -> dict[str, bool]:
    expected_secret = _required_env("TELEGRAM_WEBHOOK_SECRET")
    if not hmac.compare_digest(secret, expected_secret):
        _log_event("telegram_webhook_rejected", reason="invalid_secret")
        raise HTTPException(status_code=403, detail="Invalid webhook secret")

    body = await request.body()
    if len(body) > _MAX_TELEGRAM_WEBHOOK_BYTES:
        _log_event("telegram_webhook_rejected", reason="payload_too_large")
        raise HTTPException(status_code=413, detail="Payload too large")

    try:
        update = json.loads(body)
    except json.JSONDecodeError:
        _log_event("telegram_webhook_rejected", reason="invalid_json")
        raise HTTPException(status_code=400, detail="Invalid JSON") from None

    message = _extract_message(update)
    if not message:
        return {"ok": True}

    chat = message.get("chat") or {}
    chat_id = chat.get("id")
    text = (message.get("text") or "").strip()
    if not isinstance(chat_id, int) or not text:
        return {"ok": True}

    allowed_chat_ids = _allowed_chat_ids()
    if not allowed_chat_ids:
        _log_event("telegram_request_rejected", chat_id=chat_id, reason="missing_allowed_chat_ids")
        return {"ok": True}
    if chat_id not in allowed_chat_ids:
        _log_event("telegram_request_rejected", chat_id=chat_id, reason="chat_not_allowed")
        return {"ok": True}

    tasks = _task_map()
    _log_event("telegram_request_received", chat_id=chat_id, text=text, task_count=len(tasks))

    if text == "/health":
        await _send_telegram_message(chat_id, "openclaw-ops is healthy.")
        return {"ok": True}

    if text in {"/start", "/help", "/tasks"}:
        await _send_telegram_message(chat_id, _help_text(tasks))
        return {"ok": True}

    if not text.startswith("/task "):
        await _send_telegram_message(chat_id, "Use /task <name> or /tasks.")
        return {"ok": True}

    parts = text.split()
    if len(parts) != 2:
        await _send_telegram_message(chat_id, "Task name is required. Use /tasks.")
        return {"ok": True}

    task_name = parts[1].lower()
    command = tasks.get(task_name)

    if not command:
        _log_event("telegram_task_rejected", chat_id=chat_id, task_name=task_name, reason="unknown_task")
        await _send_telegram_message(chat_id, f"Unknown task: {task_name}")
        return {"ok": True}

    _log_event("telegram_task_started", chat_id=chat_id, task_name=task_name, command=command)
    await _send_telegram_message(chat_id, f"Running task `{task_name}`...")
    return_code, output = await _run_task(task_name, command)
    status = "completed" if return_code == 0 else f"failed ({return_code})"
    _log_event("telegram_task_finished", chat_id=chat_id, task_name=task_name, return_code=return_code)
    await _send_telegram_message(chat_id, f"Task {task_name} {status}\n\n{output}")
    return {"ok": True}


@app.get("/")
async def root() -> dict[str, str]:
    return {"service": "openclaw-ops"}
