from __future__ import annotations

import json
import sys
from dataclasses import replace
from pathlib import Path

from local_server.app.automation.browser.playwright_runner import PlaywrightRunner
from local_server.app.core.config import AppConfig


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


def _normalize_target(raw_step: dict) -> dict | None:
    target = raw_step.get("target")
    if isinstance(target, dict):
        return target

    element = raw_step.get("element")
    if isinstance(element, str) and element.strip():
        return {
            "description": raw_step.get("description", "직접 지정 요소"),
            "fallbacks": [{"css": element.strip()}],
            "frame_scope": "all_frames",
            "index": 0,
        }

    return None


def _normalize_step(raw_step: dict, index: int, site: str) -> dict:
    step_type = raw_step.get("type") or raw_step.get("action")
    if not isinstance(step_type, str) or not step_type.strip():
        raise ValueError(f"step_{index}_missing_action")

    step_type = step_type.strip()
    raw_args = raw_step.get("args") if isinstance(raw_step.get("args"), dict) else {}
    normalized: dict[str, object] = {
        "step": int(raw_step.get("step", index)),
        "type": step_type,
    }
    args: dict[str, object] = {}
    target = _normalize_target(raw_step)

    if step_type == "navigate":
        url = raw_step.get("url") or raw_args.get("url") or site
        if not isinstance(url, str) or not url.strip():
            raise ValueError(f"step_{index}_navigate_url_missing")
        args["url"] = url.strip()
        if isinstance(raw_args.get("wait_until"), str):
            args["wait_until"] = raw_args["wait_until"]
    elif step_type == "wait_for":
        if target is None:
            raise ValueError(f"step_{index}_wait_for_target_missing")
        args["timeout_ms"] = int(raw_step.get("timeout_ms", raw_args.get("timeout_ms", 5000)))
        args["state"] = raw_step.get("state") or raw_args.get("state") or "visible"
    elif step_type == "click":
        if target is None:
            raise ValueError(f"step_{index}_click_target_missing")
    elif step_type == "fill":
        if target is None:
            raise ValueError(f"step_{index}_fill_target_missing")
        text = raw_step.get("text") or raw_args.get("text")
        if not isinstance(text, str):
            raise ValueError(f"step_{index}_fill_text_missing")
        args["text"] = text
    elif step_type == "press":
        if target is None:
            raise ValueError(f"step_{index}_press_target_missing")
        key = raw_step.get("key") or raw_args.get("key")
        if not isinstance(key, str):
            raise ValueError(f"step_{index}_press_key_missing")
        args["key"] = key
    elif step_type == "extract":
        if target is None:
            raise ValueError(f"step_{index}_extract_target_missing")
        fields = raw_step.get("fields") or raw_args.get("fields") or []
        if isinstance(fields, list):
            args["fields"] = fields
    elif step_type == "finish":
        message = raw_step.get("message") or raw_args.get("message")
        if isinstance(message, str) and message.strip():
            args["message"] = message.strip()
    else:
        raise ValueError(f"unsupported_action:{step_type}")

    if target is not None:
        normalized["target"] = target
    if args:
        normalized["args"] = args
    return normalized


def normalize_plan(raw_plan: dict) -> dict:
    if not isinstance(raw_plan, dict):
        raise ValueError("plan_must_be_object")

    site = raw_plan.get("site")
    if site is None:
        site = ""
    if not isinstance(site, str):
        raise ValueError("site_must_be_string")

    raw_steps = raw_plan.get("steps")
    if not isinstance(raw_steps, list) or not raw_steps:
        raise ValueError("steps_must_be_non_empty_array")

    normalized_steps = [
        _normalize_step(raw_step, index + 1, site)
        for index, raw_step in enumerate(raw_steps)
        if isinstance(raw_step, dict)
    ]
    if not normalized_steps:
        raise ValueError("steps_must_contain_objects")

    return {
        "task_id": raw_plan.get("task_id", "custom_json_plan"),
        "goal": raw_plan.get("goal", "직접 입력한 JSON 시나리오를 실행합니다."),
        "site": site,
        "steps": normalized_steps,
    }


def run(plan_path: str) -> dict:
    plan_file = Path(plan_path)
    if not plan_file.exists():
        raise FileNotFoundError("plan_file_not_found")

    raw_plan = json.loads(plan_file.read_text(encoding="utf-8"))
    normalized_plan = normalize_plan(raw_plan)

    config = replace(AppConfig.from_env(), browser_headless=False)
    runner = PlaywrightRunner(config=config)
    return runner.run_agent_plan(
        plan=normalized_plan,
        progress_callback=emit_progress,
        scenario_name="custom_json_agent_plan",
        success_summary="직접 입력한 JSON 시나리오를 완료했습니다.",
    )


def main() -> None:
    if len(sys.argv) < 2:
        result = {
            "status": "error",
            "scenario": "custom_json_agent_plan",
            "reason": "plan_path_missing",
            "steps": [],
        }
    else:
        try:
            result = run(sys.argv[1])
        except Exception as exc:
            result = {
                "status": "error",
                "scenario": "custom_json_agent_plan",
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
