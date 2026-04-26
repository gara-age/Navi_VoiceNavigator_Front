from __future__ import annotations

from typing import Any, Callable
from urllib.parse import urlparse

from local_server.app.automation.core.enums import ActionKind, ExecutionMode, RiskLevel, TaskType, UiState
from local_server.app.automation.core.policies import AutomationPolicy, DEFAULT_POLICY
from local_server.app.automation.core.schemas import (
    ActionStep,
    BoundAction,
    ExecutionObservation,
    HostBias,
    Intent,
    TaskRequest,
)
from local_server.app.automation.engine.binder import PatternBinder
from local_server.app.automation.engine.planner import PatternPlanner
from local_server.app.automation.engine.recovery import RecoveryOrchestrator
from local_server.app.automation.engine.snapshot_builder import build_page_snapshot
from local_server.app.automation.llm.intent_parser import HeuristicIntentParser

ProgressCallback = Callable[[dict[str, Any]], None]


class PatternExecutor:
    """Pattern-centric deterministic automation executor."""

    def __init__(
        self,
        *,
        intent_parser: HeuristicIntentParser | None = None,
        planner: PatternPlanner | None = None,
        binder: PatternBinder | None = None,
        recovery: RecoveryOrchestrator | None = None,
        policy: AutomationPolicy | None = None,
    ) -> None:
        self.policy = policy or DEFAULT_POLICY
        self.intent_parser = intent_parser or HeuristicIntentParser()
        self.planner = planner or PatternPlanner()
        self.binder = binder or PatternBinder(policy=self.policy)
        self.recovery = recovery or RecoveryOrchestrator(self.binder, self.policy)
        self._last_locator: Any | None = None

    def execute_task(
        self,
        page: Any,
        task_request: dict[str, Any] | TaskRequest,
        progress_callback: ProgressCallback | None = None,
    ) -> dict[str, Any]:
        request = task_request if isinstance(task_request, TaskRequest) else TaskRequest.model_validate(task_request)
        intent = self.intent_parser.resolve(request)
        host_bias = request.host_bias or HostBias()

        if intent.risk_level == RiskLevel.HIGH:
            return {
                "status": "error",
                "reason": "manual_confirmation_required",
                "steps": [],
                "observations": [],
                "intent": intent.model_dump(mode="json"),
            }

        steps: list[dict[str, Any]] = []
        observations: list[dict[str, Any]] = []
        next_step = 1

        if request.site:
            self._emit(progress_callback, next_step, "navigate", "processing", f"Opening {request.site}")
            page.goto(request.site, wait_until="domcontentloaded")
            page.wait_for_timeout(800)
            snapshot = build_page_snapshot(page)
            steps.append(
                {
                    "step": next_step,
                    "action": "navigate",
                    "status": "success",
                    "detail": f"Opened {request.site}",
                }
            )
            observations.append(
                ExecutionObservation(
                    step=next_step,
                    action="navigate",
                    status="success",
                    detail=f"Opened {request.site}",
                    state_before=snapshot.state.value,
                    state_after=snapshot.state.value,
                ).model_dump(mode="json")
            )
            self._emit(progress_callback, next_step, "navigate", "success", f"Opened {request.site}", popup_state="success")
            next_step += 1

        actions = self.planner.build_plan(intent)

        for index, action in enumerate(actions, start=next_step):
            if action.kind == ActionKind.SUBMIT_PRIMARY:
                current_snapshot = build_page_snapshot(page)
                if self._should_skip_submit(request, intent, current_snapshot, page.url):
                    observation = ExecutionObservation(
                        step=index,
                        action=action.kind.value,
                        status="success",
                        detail="Skipped submit_primary because results are already visible",
                        state_before=current_snapshot.state.value,
                        state_after=current_snapshot.state.value,
                        recovery_notes=["results_already_visible"],
                    )
                    observations.append(observation.model_dump(mode="json"))
                    steps.append(
                        {
                            "step": index,
                            "action": action.kind.value,
                            "status": observation.status,
                            "detail": observation.detail,
                        }
                    )
                    self._emit(
                        progress_callback,
                        index,
                        action.kind.value,
                        observation.status,
                        observation.detail,
                        popup_state="success",
                    )
                    continue

            self._emit(progress_callback, index, action.kind.value, "processing", f"Executing {action.kind.value}")
            outcome = self._execute_action(page, index, action, host_bias)
            observation = outcome["observation"]
            observations.append(observation.model_dump(mode="json"))
            steps.append(
                {
                    "step": index,
                    "action": action.kind.value,
                    "status": observation.status,
                    "detail": observation.detail,
                }
            )
            self._emit(
                progress_callback,
                index,
                action.kind.value,
                observation.status,
                observation.detail,
                popup_state="success" if observation.status == "success" else "error",
            )
            if observation.status != "success":
                return {
                    "status": "error",
                    "reason": observation.detail,
                    "steps": steps,
                    "observations": observations,
                    "intent": intent.model_dump(mode="json"),
                }

        final_snapshot = build_page_snapshot(page)
        summary = self._build_summary(observations, final_snapshot)
        return {
            "status": "success",
            "goal": request.user_request or intent.task_type.value,
            "summary": summary,
            "url": page.url,
            "title": final_snapshot.title,
            "steps": steps,
            "observations": observations,
            "intent": intent.model_dump(mode="json"),
            "snapshot": {
                "state": final_snapshot.state.value,
                "summary": final_snapshot.summary,
            },
        }

    def _execute_action(
        self,
        page: Any,
        step_no: int,
        action: ActionStep,
        host_bias: HostBias,
    ) -> dict[str, Any]:
        recovery_notes: list[str] = []

        for _attempt in range(self.policy.max_local_retries + 1):
            snapshot_before = build_page_snapshot(page)
            bound = self.binder.bind(snapshot_before, action, host_bias)

            if self._is_acceptable(action, bound):
                observation = self._perform_bound_action(
                    page,
                    step_no,
                    action,
                    bound,
                    snapshot_before,
                    recovery_notes=recovery_notes,
                )
                return {"observation": observation}

            decision = self.recovery.attempt(snapshot_before, action, bound, host_bias)
            if not decision.pre_actions:
                break

            recovery_notes.extend(decision.notes)
            last_recovery_observation: ExecutionObservation | None = None
            for recovery_action in decision.pre_actions:
                last_recovery_observation = self._perform_bound_action(
                    page,
                    step_no,
                    recovery_action.action,
                    recovery_action,
                    snapshot_before,
                    recovery_notes=["local_recovery"],
                )

            if not decision.rebind:
                if last_recovery_observation is not None:
                    return {"observation": last_recovery_observation}
                break

        failure_snapshot = build_page_snapshot(page)
        final_bound = self.binder.bind(failure_snapshot, action, host_bias)
        if not action.required:
            return {
                "observation": ExecutionObservation(
                    step=step_no,
                    action=action.kind.value,
                    status="success",
                    detail=f"Skipped optional {action.kind.value} because confidence was low",
                    state_before=failure_snapshot.state.value,
                    state_after=failure_snapshot.state.value,
                    selected_candidate=final_bound.selected_candidate,
                    top_candidates=final_bound.top_candidates,
                    recovery_notes=recovery_notes + final_bound.notes + ["optional_low_confidence_skip"],
                )
            }
        return {
            "observation": ExecutionObservation(
                step=step_no,
                action=action.kind.value,
                status="error",
                detail=f"binding_confidence_low:{action.kind.value}",
                state_before=failure_snapshot.state.value,
                state_after=failure_snapshot.state.value,
                selected_candidate=final_bound.selected_candidate,
                top_candidates=final_bound.top_candidates,
                recovery_notes=recovery_notes + final_bound.notes,
            )
        }

    def _is_acceptable(self, action: ActionStep, bound: BoundAction) -> bool:
        if bound.mode == ExecutionMode.NOOP:
            return not action.required
        if bound.mode in {ExecutionMode.WAIT_STATE, ExecutionMode.KEYBOARD_PRESS}:
            return bound.confidence >= self.policy.cautious_threshold
        if bound.mode == ExecutionMode.READ_REGION:
            return bound.confidence >= self.policy.cautious_threshold
        if action.kind == ActionKind.CHOOSE_SUGGESTION:
            return bound.confidence >= self.policy.cautious_threshold
        threshold = self.policy.auto_execute_threshold if action.required else self.policy.cautious_threshold
        return bound.confidence >= threshold

    def _perform_bound_action(
        self,
        page: Any,
        step_no: int,
        action: ActionStep,
        bound: BoundAction,
        snapshot_before,
        *,
        recovery_notes: list[str],
    ) -> ExecutionObservation:
        extracted_text: str | None = None

        if bound.mode == ExecutionMode.NOOP:
            detail = f"Skipped optional {action.kind.value}"
        elif bound.mode == ExecutionMode.WAIT_STATE:
            self._wait_for_state(page, action.target_state)
            detail = f"Reached state {action.target_state.value if action.target_state else 'unknown'}"
        elif bound.mode == ExecutionMode.KEYBOARD_PRESS:
            if bound.selected_candidate is not None:
                locator = self._locator_for_candidate(page, bound)
                try:
                    locator.click()
                except Exception:
                    pass
                locator.press(bound.keyboard_key or "Enter")
                self._last_locator = locator
            else:
                self._press_key(page, bound.keyboard_key or "Enter")
            detail = f"Pressed {bound.keyboard_key or 'Enter'}"
        elif bound.mode == ExecutionMode.CANDIDATE_FILL:
            locator = self._locator_for_candidate(page, bound)
            value = "" if action.value is None else str(action.value)
            locator.click()
            locator.fill(value)
            self._last_locator = locator
            detail = f"Filled {action.slot or 'field'}"
        elif bound.mode == ExecutionMode.CANDIDATE_CLICK:
            locator = self._locator_for_candidate(page, bound)
            locator.click()
            self._last_locator = locator
            detail = f"Clicked {action.kind.value}"
        elif bound.mode == ExecutionMode.READ_REGION:
            locator = (
                page.locator("body").first
                if bound.region_id == "__body__"
                else page.locator(f'[data-vn-region-id="{bound.region_id}"]').first
            )
            extracted_text = locator.inner_text(timeout=int(self.policy.default_timeout_ms)).strip()
            if len(extracted_text) > self.policy.max_result_chars:
                extracted_text = extracted_text[: self.policy.max_result_chars]
            detail = f"Read results from {bound.region_id}"
        else:
            detail = f"unsupported_bound_mode:{bound.mode.value}"

        if action.kind == ActionKind.FILL_SLOT:
            page.wait_for_timeout(self.policy.suggestion_wait_ms)
        elif action.kind == ActionKind.SUBMIT_PRIMARY and (action.label or "").strip().lower() == "search":
            self._wait_for_search_transition(page, snapshot_before.url)
        else:
            page.wait_for_timeout(300)

        snapshot_after = build_page_snapshot(page)
        return ExecutionObservation(
            step=step_no,
            action=action.kind.value,
            status="success",
            detail=detail,
            state_before=snapshot_before.state.value,
            state_after=snapshot_after.state.value,
            selected_candidate=bound.selected_candidate,
            top_candidates=bound.top_candidates,
            extracted_text=extracted_text,
            recovery_notes=recovery_notes + bound.notes,
        )

    def _locator_for_candidate(self, page: Any, bound: BoundAction):
        if bound.selected_candidate is None:
            raise RuntimeError("candidate_locator_missing")
        return page.locator(f'[data-vn-candidate-id="{bound.selected_candidate.candidate_id}"]').first

    def _wait_for_state(self, page: Any, target_state, timeout_ms: int | None = None) -> None:
        timeout = timeout_ms or self.policy.default_timeout_ms
        elapsed = 0
        while elapsed <= timeout:
            snapshot = build_page_snapshot(page)
            if snapshot.state == target_state:
                return
            page.wait_for_timeout(self.policy.wait_poll_ms)
            elapsed += self.policy.wait_poll_ms
        raise RuntimeError(f"wait_for_state_timeout:{target_state.value if target_state else 'unknown'}")

    def _wait_for_search_transition(self, page: Any, previous_url: str, timeout_ms: int | None = None) -> None:
        timeout = timeout_ms or self.policy.default_timeout_ms
        elapsed = 0
        while elapsed <= timeout:
            snapshot = build_page_snapshot(page)
            current_url = getattr(page, "url", "") or ""
            if current_url != previous_url:
                return
            if snapshot.state != UiState.SUGGESTION_OPEN:
                return
            page.wait_for_timeout(self.policy.wait_poll_ms)
            elapsed += self.policy.wait_poll_ms

    def _press_key(self, page: Any, key: str) -> None:
        if self._last_locator is not None:
            try:
                self._last_locator.press(key)
                return
            except Exception:
                self._last_locator = None
        page.keyboard.press(key)

    def _build_summary(self, observations: list[dict[str, Any]], snapshot) -> str:
        for item in reversed(observations):
            extracted = item.get("extracted_text")
            if isinstance(extracted, str) and extracted.strip():
                return extracted
        return f"Completed task on {snapshot.title or snapshot.url}"

    def _should_skip_submit(
        self,
        request: TaskRequest,
        intent: Intent,
        snapshot,
        current_url: str,
    ) -> bool:
        if snapshot.state == UiState.RESULTS_READY:
            return True
        current = urlparse(current_url or "")
        origin = urlparse(request.site or "")
        host_changed = bool(current.netloc and origin.netloc and current.netloc.lower() != origin.netloc.lower())
        path_changed = bool((current.path or "/") != (origin.path or "/"))
        has_query = bool(current.query)

        result_signal = bool(snapshot.result_regions)
        if intent.task_type == TaskType.SEARCH_AND_OPEN_RESULT:
            result_signal = result_signal or self._has_search_result_candidates(snapshot, intent)
        title_corpus = f"{snapshot.title} {current_url}".lower()
        slot_values = [str(value).strip().lower() for value in intent.slots.values() if str(value).strip()]
        query_in_title = any(value in title_corpus for value in slot_values)

        if snapshot.state == UiState.SUGGESTION_OPEN:
            return result_signal and (host_changed or path_changed or has_query or query_in_title)

        return (host_changed or path_changed or has_query) and (result_signal or query_in_title)

    def _has_search_result_candidates(self, snapshot, intent: Intent) -> bool:
        values = [str(value).strip().lower() for value in intent.slots.values() if str(value).strip()]
        if not values:
            return False

        for element in snapshot.elements:
            if not element.visible or not element.enabled or not element.interactable:
                continue
            role = (element.role or "").lower()
            tag = (element.tag or "").lower()
            if snapshot.state == UiState.SUGGESTION_OPEN and role == "option":
                continue
            if role not in {"link", "option"} and tag != "a":
                continue
            corpus = " ".join(
                filter(
                    None,
                    [
                        element.name,
                        element.text,
                        element.placeholder,
                        element.parent_context,
                    ],
                )
            ).lower()
            if any(value in corpus for value in values):
                return True
        return False

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
