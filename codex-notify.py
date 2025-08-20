#!/usr/bin/env python3

import json
import subprocess
import sys

def notify(title: str, message: str) -> None:
    # json.dumps to safely quote/escape for AppleScript
    subprocess.run([
        "osascript", "-e",
        f'display notification {json.dumps(message or "")} with title {json.dumps(title or "Codex")}'
    ])


def main() -> int:
    if len(sys.argv) != 2:
        notify("Codex: Notify Error", "Invalid usage. Expected one JSON argument.")
        return 1

    try:
        notification = json.loads(sys.argv[1])
    except json.JSONDecodeError:
        notify("Codex: Notify Error", "Invalid JSON payload for notification.")
        return 1

    match notification_type := notification.get("type"):
        case "agent-turn-complete":
            assistant_message = notification.get("last-assistant-message")
            if assistant_message:
                title = f"Codex: {assistant_message}"
            else:
                title = "Codex: Turn Complete!"
            input_messages = notification.get("input_messages", [])
            message = " ".join(input_messages)
            title += message
        case _:
            notify("Codex: Notify Error", f"Unsupported notification type: {notification_type}")
            return 0

    notify(title, message)

    return 0


if __name__ == "__main__":
    sys.exit(main())
