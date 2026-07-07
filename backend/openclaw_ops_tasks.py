import argparse
import os
import shlex
import shutil
from pathlib import Path
from typing import List


def _env(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


def _state_root() -> Path:
    return Path(_env("OPENCLAW_STATE_DIR", "/data/openclaw-ops"))


def cmd_status() -> str:
    service = _env("RAILWAY_SERVICE_NAME", "openclaw-ops")
    environment = _env("RAILWAY_ENVIRONMENT_NAME", _env("RAILWAY_ENVIRONMENT", "unknown"))
    public_domain = _env("RAILWAY_PUBLIC_DOMAIN", "not-set")
    runtime_command = _env("OPENCLAW_RUNTIME_COMMAND", "not-configured")
    runtime_binary = shlex.split(runtime_command)[0] if runtime_command != "not-configured" else ""
    runtime_installed = bool(runtime_binary and shutil.which(runtime_binary))
    state_dir = _state_root()
    return "\n".join(
        [
            f"service={service}",
            f"environment={environment}",
            f"domain={public_domain}",
            f"runtime_command={runtime_command}",
            f"runtime_installed={'yes' if runtime_installed else 'no'}",
            f"state_dir={state_dir}",
            f"cwd={Path.cwd()}",
            f"pythonpath={_env('PYTHONPATH', 'not-set')}",
            f"script_file={Path(__file__)}",
        ]
    )


def cmd_health() -> str:
    runtime_command = _env("OPENCLAW_RUNTIME_COMMAND")
    runtime_binary = shlex.split(runtime_command)[0] if runtime_command else ""
    checks = {
        "TELEGRAM_BOT_TOKEN": bool(_env("TELEGRAM_BOT_TOKEN")),
        "TELEGRAM_WEBHOOK_SECRET": bool(_env("TELEGRAM_WEBHOOK_SECRET")),
        "TELEGRAM_ALLOWED_CHAT_IDS": bool(_env("TELEGRAM_ALLOWED_CHAT_IDS")),
        "OPENCLAW_RUNTIME_COMMAND": bool(runtime_command),
        "OPENCLAW_RUNTIME_BINARY": bool(runtime_binary and shutil.which(runtime_binary)),
    }
    lines = [f"{name}={'ok' if present else 'missing'}" for name, present in checks.items()]
    overall = "ok" if all(checks.values()) else "degraded"
    return "\n".join([f"status={overall}", *lines])


def cmd_logs() -> str:
    log_path = _env("OPENCLAW_OPS_LOG_PATH", str(_state_root() / "openclaw-ops.log"))
    path = Path(log_path)
    if not path.exists():
        return f"log_file_missing={path}"

    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    tail = lines[-20:]
    return "\n".join(tail) if tail else "(log file is empty)"


def cmd_git_status() -> str:
    git_dir = _env("OPENCLAW_GIT_DIR", "/app")
    return _run_git(["status", "--short"], git_dir)


def cmd_git_rev() -> str:
    git_dir = _env("OPENCLAW_GIT_DIR", "/app")
    return _run_git(["rev-parse", "HEAD"], git_dir)


def _run_git(args: List[str], git_dir: str) -> str:
    result = shutil.which("git")
    if not result:
        return "git_missing"

    import subprocess

    completed = subprocess.run(
        ["git", "-C", git_dir, *args],
        check=False,
        capture_output=True,
        text=True,
    )
    output = (completed.stdout or completed.stderr).strip()
    if completed.returncode != 0:
        return f"git_command_failed={completed.returncode}\n{output}"
    return output or "(no output)"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("task", choices=("status", "health", "logs", "git_status", "git_rev"))
    args = parser.parse_args()

    print(run_task(args.task))
    return 0


def run_task(task: str) -> str:
    if task == "status":
        return cmd_status()
    if task == "health":
        return cmd_health()
    if task == "logs":
        return cmd_logs()
    if task == "git_status":
        return cmd_git_status()
    if task == "git_rev":
        return cmd_git_rev()
    raise ValueError(f"Unsupported task: {task}")


if __name__ == "__main__":
    raise SystemExit(main())
