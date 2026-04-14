from __future__ import annotations

import json
import sys
from dataclasses import replace
from pathlib import Path

from local_server.app.automation.browser.playwright_runner import PlaywrightRunner
from local_server.app.automation.core.schemas import TaskRequest
from local_server.app.core.config import AppConfig


def _ensure_stdout_encoding() -> None:
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    except Exception:
        pass


def emit_progress(payload: dict) -> None:
    print(
        json.dumps(
            {
                "kind": "progress",
                "payload": payload,
            },
            ensure_ascii=False,
        ),
        flush=True,
    )


def run(task_path: str) -> dict:
    task_file = Path(task_path)
    if not task_file.exists():
        raise FileNotFoundError("task_file_not_found")

    raw_task = json.loads(task_file.read_text(encoding="utf-8"))
    task_request = TaskRequest.model_validate(raw_task)

    config = replace(AppConfig.from_env(), browser_headless=False)
    runner = PlaywrightRunner(config=config)
    return runner.run_pattern_task(
        task_request=task_request.model_dump(mode="json"),
        progress_callback=emit_progress,
        scenario_name="pattern_agent_task",
    )


def main() -> None:
    _ensure_stdout_encoding()
    if len(sys.argv) < 2:
        result = {
            "status": "error",
            "scenario": "pattern_agent_task",
            "reason": "task_path_missing",
            "steps": [],
        }
    else:
        try:
            result = run(sys.argv[1])
        except Exception as exc:
            result = {
                "status": "error",
                "scenario": "pattern_agent_task",
                "reason": str(exc),
                "steps": [],
            }

    print(
        json.dumps(
            {
                "kind": "result",
                "payload": result,
            },
            ensure_ascii=False,
        ),
        flush=True,
    )


if __name__ == "__main__":
    main()
