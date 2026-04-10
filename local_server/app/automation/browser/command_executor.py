from __future__ import annotations

from typing import Any, Callable

from local_server.app.automation.browser.target_resolver import (
    TargetResolutionError,
    TargetResolver,
)
from local_server.app.automation.browser.candidate_inventory import (
    build_recovery_candidate_summary,
)

ProgressCallback = Callable[[dict[str, Any]], None]


class CommandExecutor:
    """Execute a structured browser plan step by step.

    This executor is designed as the next-stage replacement for the current
    scenario-specific Playwright methods. Existing hardcoded scenarios can
    gradually migrate by generating a JSON plan and delegating execution here.
    """

    def __init__(self, target_resolver: TargetResolver | None = None) -> None:
        self.target_resolver = target_resolver or TargetResolver()
        self._last_locator: Any | None = None

    def execute_plan(
        self,
        page: Any,
        plan: dict[str, Any],
        progress_callback: ProgressCallback | None = None,
    ) -> dict[str, Any]:
        steps = plan.get("steps") or []
        completed_steps: list[dict[str, Any]] = []
        observations: list[dict[str, Any]] = []

        for step in steps:
            step_no = int(step.get("step", len(completed_steps) + 1))
            action = step.get("type", "unknown")
            description = self._describe_step(step)

            self._emit(
                progress_callback,
                step_no,
                action,
                "processing",
                description,
            )

            try:
                observation = self.execute_step(page, step)
                observations.append(observation)
                completed_steps.append(
                    {
                        "step": step_no,
                        "action": action,
                        "status": "success",
                        "detail": observation.get("summary", description),
                    }
                )
                self._emit(
                    progress_callback,
                    step_no,
                    action,
                    "success",
                    observation.get("summary", description),
                    popup_state="success",
                )
            except Exception as exc:
                failure = self._build_step_error(
                    page,
                    step,
                    exc,
                    completed_steps=completed_steps,
                    observations=observations,
                )
                completed_steps.append(
                    {
                        "step": step_no,
                        "action": action,
                        "status": "error",
                        "detail": str(exc),
                    }
                )
                failure["steps"] = completed_steps
                failure["observations"] = observations
                return failure

        return {
            "status": "success",
            "goal": plan.get("goal", ""),
            "steps": completed_steps,
            "observations": observations,
        }

    def execute_step(self, page: Any, step: dict[str, Any]) -> dict[str, Any]:
        action = step["type"]
        args = step.get("args") or {}

        if action == "navigate":
            url = args["url"]
            page.goto(url, wait_until=args.get("wait_until", "domcontentloaded"))
            return {
                "action": action,
                "summary": f"{url}로 이동했습니다.",
                "url": page.url,
            }

        if action == "click":
            locator = self._resolve_target(page, step)
            self._click_in_current_tab(page, locator)
            return {
                "action": action,
                "summary": f"{step.get('target', {}).get('description', '대상')}을 클릭했습니다.",
            }

        if action == "fill":
            locator = self._resolve_target(page, step)
            text = args["text"]
            locator.fill(text)
            return {
                "action": action,
                "summary": f"{step.get('target', {}).get('description', '입력창')}에 값을 입력했습니다.",
                "text": text,
            }

        if action == "wait_for":
            locator = self._resolve_target(page, step)
            locator.wait_for(
                state=args.get("state", "visible"),
                timeout=int(args.get("timeout_ms", 5000)),
            )
            return {
                "action": action,
                "summary": f"{step.get('target', {}).get('description', '대상')}이 준비되었습니다.",
            }

        if action == "extract":
            locator = self._resolve_target(page, step)
            text = locator.inner_text(timeout=int(args.get("timeout_ms", 1200))).strip()
            return {
                "action": action,
                "summary": f"{step.get('target', {}).get('description', '대상')}의 텍스트를 추출했습니다.",
                "text": text,
                "fields": args.get("fields", []),
            }

        if action == "press":
            locator = self._resolve_target(page, step)
            locator.press(args["key"])
            return {
                "action": action,
                "summary": f"{args['key']} 키를 입력했습니다.",
            }

        if action == "finish":
            return {
                "action": action,
                "summary": args.get("message", "작업을 종료합니다."),
            }

        raise RuntimeError(f"unsupported_action:{action}")

    def _resolve_target(self, page: Any, step: dict[str, Any]) -> Any:
        target = step.get("target") or {}
        if target.get("reuse_previous_target") and self._last_locator is not None:
            return self._last_locator

        try:
            resolved = self.target_resolver.resolve_with_metadata(
                page,
                target,
                timeout_ms=int((step.get("args") or {}).get("timeout_ms", 8000)),
            )
        except TargetResolutionError:
            raise

        self._last_locator = resolved.locator
        return resolved.locator

    def _emit(
        self,
        progress_callback: ProgressCallback | None,
        step: int,
        action: str,
        status: str,
        detail: str,
        popup_state: str = "processing",
    ) -> None:
        if progress_callback is None:
            return
        progress_callback(
            {
                "step": step,
                "action": action,
                "status": status,
                "detail": detail,
                "popup_state": popup_state,
            }
        )

    def _click_in_current_tab(self, page: Any, locator: Any) -> None:
        try:
            tag_name = locator.evaluate(
                """element => (element.tagName || '').toLowerCase()"""
            )
        except Exception:
            tag_name = ""

        if tag_name == "a":
            try:
                locator.evaluate(
                    """element => {
                        element.setAttribute('target', '_self');
                        element.removeAttribute('rel');
                    }"""
                )
            except Exception:
                pass

        locator.click()

    def _describe_step(self, step: dict[str, Any]) -> str:
        action = step.get("type", "unknown")
        target = step.get("target") or {}
        description = target.get("description")
        if description:
            return f"{description} 단계 실행 중입니다."
        return f"{action} 단계를 실행 중입니다."

    def _build_step_error(
        self,
        page: Any,
        step: dict[str, Any],
        exc: Exception,
        *,
        completed_steps: list[dict[str, Any]],
        observations: list[dict[str, Any]],
    ) -> dict[str, Any]:
        reason = str(exc)
        failure = {
            "status": "error",
            "reason": reason,
            "failed_step": step,
            "steps": completed_steps,
            "observations": observations,
        }
        if self._is_recoverable_target_error(exc):
            target_exc = exc if isinstance(exc, TargetResolutionError) else None
            failure["reason"] = target_exc.reason_code if target_exc else "target_not_found"
            failure["recovery"] = {
                "reason_code": target_exc.reason_code if target_exc else "target_not_found",
                "debug_snapshot": target_exc.debug_snapshot if target_exc else "",
                "candidate_summary": build_recovery_candidate_summary(
                    page,
                    step.get("target") or {},
                ),
            }
            failure["detail"] = reason
        return failure

    def _is_recoverable_target_error(self, exc: Exception) -> bool:
        return isinstance(exc, TargetResolutionError)
