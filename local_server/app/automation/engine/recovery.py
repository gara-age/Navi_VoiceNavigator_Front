from __future__ import annotations

from dataclasses import dataclass, field

from local_server.app.automation.core.enums import ActionKind, ExecutionMode, UiState
from local_server.app.automation.core.policies import AutomationPolicy, DEFAULT_POLICY
from local_server.app.automation.core.schemas import ActionStep, BoundAction, HostBias, PageSnapshot
from local_server.app.automation.engine.binder import PatternBinder


@dataclass(slots=True)
class RecoveryDecision:
    pre_actions: list[BoundAction] = field(default_factory=list)
    rebind: bool = False
    notes: list[str] = field(default_factory=list)


class RecoveryOrchestrator:
    """Local deterministic recovery before asking an LLM for a patch."""

    def __init__(
        self,
        binder: PatternBinder | None = None,
        policy: AutomationPolicy | None = None,
    ) -> None:
        self.binder = binder or PatternBinder(policy=policy)
        self.policy = policy or DEFAULT_POLICY

    def attempt(
        self,
        snapshot: PageSnapshot,
        action: ActionStep,
        bound: BoundAction,
        host_bias: HostBias | None = None,
    ) -> RecoveryDecision:
        bias = host_bias or HostBias()

        if bound.mode in {ExecutionMode.WAIT_STATE, ExecutionMode.KEYBOARD_PRESS}:
            return RecoveryDecision()

        if snapshot.state == UiState.DIALOG_BLOCKING and action.kind != ActionKind.DISMISS_DIALOG:
            dismiss_action = ActionStep(
                id=f"{action.id}__dismiss_dialog",
                kind=ActionKind.DISMISS_DIALOG,
                required=False,
            )
            dismiss_bound = self.binder.bind(snapshot, dismiss_action, bias)
            if dismiss_bound.confidence >= self.policy.cautious_threshold:
                return RecoveryDecision(
                    pre_actions=[dismiss_bound],
                    rebind=True,
                    notes=["dismiss_dialog_before_retry"],
                )

        if action.kind == ActionKind.FILL_SLOT and snapshot.state == UiState.IDLE:
            open_action = ActionStep(
                id=f"{action.id}__open_entry",
                kind=ActionKind.OPEN_PRIMARY_ENTRY,
                required=False,
            )
            open_bound = self.binder.bind(snapshot, open_action, bias)
            if open_bound.mode == ExecutionMode.CANDIDATE_CLICK and open_bound.confidence >= self.policy.cautious_threshold:
                return RecoveryDecision(
                    pre_actions=[open_bound],
                    rebind=True,
                    notes=["open_primary_entry_before_retry"],
                )

        if self._needs_paired_lookup_entry_recovery(snapshot, action):
            open_action = ActionStep(
                id=f"{action.id}__open_entry",
                kind=ActionKind.OPEN_PRIMARY_ENTRY,
                label="route",
                required=False,
            )
            open_bound = self.binder.bind(snapshot, open_action, bias)
            if open_bound.mode == ExecutionMode.CANDIDATE_CLICK and open_bound.confidence >= self.policy.cautious_threshold:
                return RecoveryDecision(
                    pre_actions=[open_bound],
                    rebind=True,
                    notes=["open_primary_entry_before_retry"],
                )

        if action.kind == ActionKind.SELECT_LIST_ITEM and snapshot.state == UiState.SUGGESTION_OPEN:
            submit_action = ActionStep(
                id=f"{action.id}__submit_search",
                kind=ActionKind.SUBMIT_PRIMARY,
                label="search",
                required=False,
            )
            submit_bound = self.binder.bind(snapshot, submit_action, bias)
            if submit_bound.mode in {ExecutionMode.CANDIDATE_CLICK, ExecutionMode.KEYBOARD_PRESS} and (
                submit_bound.confidence >= self.policy.cautious_threshold
            ):
                return RecoveryDecision(
                    pre_actions=[submit_bound],
                    rebind=True,
                    notes=["submit_search_before_retry"],
                )

        if action.kind in {ActionKind.CHOOSE_SUGGESTION, ActionKind.SUBMIT_PRIMARY} and bound.mode == ExecutionMode.NOOP:
            fallback = self.binder.bind(snapshot, action.model_copy(update={"required": False}), bias)
            if fallback.mode == ExecutionMode.KEYBOARD_PRESS:
                return RecoveryDecision(
                    pre_actions=[fallback],
                    rebind=False,
                    notes=["keyboard_fallback"],
                )

        return RecoveryDecision()

    def _needs_paired_lookup_entry_recovery(
        self,
        snapshot: PageSnapshot,
        action: ActionStep,
    ) -> bool:
        if action.kind != ActionKind.FILL_SLOT or action.slot not in {"source", "target"}:
            return False
        if snapshot.state not in {UiState.IDLE, UiState.INPUT_READY, UiState.SUGGESTION_OPEN}:
            return False

        paired_inputs = 0
        for element in snapshot.elements:
            if not element.visible or not element.enabled or not element.interactable:
                continue
            if self.binder._is_text_entry_candidate(element):
                paired_inputs += 1

        return paired_inputs < 2
