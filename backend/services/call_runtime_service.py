from typing import Any


SessionData = dict[str, Any]


async def send_to_app(session: SessionData, message: Any) -> None:
    await session["to_app_queue"].put(message)


async def send_hang_up(session: SessionData) -> None:
    await send_to_app(session, "HANG_UP")
    await queue_user_text(session, "HANG_UP")


async def queue_user_text(session: SessionData, text: str, message_id: str | None = None) -> None:
    await session["from_app_queue"].put((text, message_id))


async def next_app_message(session: SessionData) -> Any:
    return await session["to_app_queue"].get()


async def next_user_text(session: SessionData) -> tuple[str, str | None]:
    return await session["from_app_queue"].get()


def append_conversation_history(session: SessionData, speaker: str, text: str) -> None:
    history = session["conversation_history"]
    history.append(f"{speaker}: {text}")
    if len(history) > 5:
        history.pop(0)


def append_log(
    session: SessionData,
    *,
    original: str,
    translated: str,
    is_user: bool,
) -> None:
    session["full_logs"].append(
        {
            "original": original,
            "translated": translated,
            "is_user": is_user,
        }
    )
