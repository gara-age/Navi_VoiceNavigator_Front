from __future__ import annotations

from typing import Any
from urllib.parse import urlparse

from pydantic import BaseModel, ConfigDict, Field, model_validator

from local_server.app.automation.core.enums import (
    ActionKind,
    ExecutionMode,
    RiskLevel,
    TaskType,
    UiState,
)


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class Intent(StrictModel):
    task_type: TaskType
    slots: dict[str, Any] = Field(default_factory=dict)
    risk_level: RiskLevel = RiskLevel.LOW
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    domain_hint: str | None = None


class TaskRequest(StrictModel):
    site: str = ""
    user_request: str = ""
    intent: Intent | None = None
    host_bias: "HostBias | None" = None
    metadata: dict[str, Any] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_payload(self) -> "TaskRequest":
        self.site = _normalize_site_url(self.site)
        if self.intent is None and not self.user_request:
            raise ValueError("task_request_requires_intent_or_user_request")
        return self


def _normalize_site_url(value: str) -> str:
    site = (value or "").strip()
    if not site:
        return ""

    parsed = urlparse(site)
    if parsed.scheme:
        return site

    if site.startswith("//"):
        return f"https:{site}"

    return f"https://{site}"


class ElementSnapshot(StrictModel):
    id: str
    role: str
    tag: str = ""
    input_type: str = ""
    name: str = ""
    text: str = ""
    placeholder: str = ""
    locator_hint: str = ""
    html_name: str = ""
    parent_context: str = ""
    visible: bool = True
    enabled: bool = True
    interactable: bool = True
    clickable: bool = False
    editable: bool = False
    expanded: str | None = None
    haspopup: str | None = None
    controls: str | None = None
    landmarks: list[str] = Field(default_factory=list)


class RegionSnapshot(StrictModel):
    id: str
    kind: str
    name: str = ""
    text_preview: str = ""
    visible: bool = True


class PageSnapshot(StrictModel):
    url: str
    title: str = ""
    state: UiState
    elements: list[ElementSnapshot] = Field(default_factory=list)
    dialogs: list[RegionSnapshot] = Field(default_factory=list)
    panels: list[RegionSnapshot] = Field(default_factory=list)
    result_regions: list[RegionSnapshot] = Field(default_factory=list)
    relation_groups: dict[str, list[dict[str, Any]]] = Field(default_factory=dict)
    summary: dict[str, Any] = Field(default_factory=dict)


class ActionStep(StrictModel):
    id: str
    kind: ActionKind
    slot: str | None = None
    value: Any | None = None
    label: str | None = None
    target_state: UiState | None = None
    required: bool = True

    @model_validator(mode="after")
    def validate_for_kind(self) -> "ActionStep":
        if self.kind == ActionKind.FILL_SLOT:
            if not self.slot:
                raise ValueError("fill_slot_requires_slot")
            if self.value is None:
                raise ValueError("fill_slot_requires_value")
        if self.kind in {ActionKind.CHOOSE_SUGGESTION, ActionKind.RETRY_FOCUS} and not self.slot:
            raise ValueError(f"{self.kind.value}_requires_slot")
        if self.kind == ActionKind.SWITCH_TAB and not self.label:
            raise ValueError("switch_tab_requires_label")
        if self.kind == ActionKind.WAIT_FOR_STATE and self.target_state is None:
            raise ValueError("wait_for_state_requires_target_state")
        return self


class CandidateMatch(StrictModel):
    candidate_id: str
    score: float = Field(ge=0.0, le=1.0)
    role: str = ""
    label: str = ""
    locator_hint: str = ""
    notes: list[str] = Field(default_factory=list)


class BoundAction(StrictModel):
    action: ActionStep
    mode: ExecutionMode
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    selected_candidate: CandidateMatch | None = None
    top_candidates: list[CandidateMatch] = Field(default_factory=list)
    region_id: str | None = None
    keyboard_key: str | None = None
    notes: list[str] = Field(default_factory=list)


class RecoveryPatch(StrictModel):
    patch_type: str = Field(pattern="^(replace_action|insert_after|delete_optional)$")
    target_index: int = Field(ge=0)
    replacement_action: ActionStep | None = None
    reason: str

    @model_validator(mode="after")
    def validate_patch(self) -> "RecoveryPatch":
        if self.patch_type in {"replace_action", "insert_after"} and self.replacement_action is None:
            raise ValueError("replacement_action_required")
        return self


class ExecutionObservation(StrictModel):
    step: int
    action: str
    status: str
    detail: str
    state_before: str
    state_after: str
    selected_candidate: CandidateMatch | None = None
    top_candidates: list[CandidateMatch] = Field(default_factory=list)
    extracted_text: str | None = None
    recovery_notes: list[str] = Field(default_factory=list)


class HostBias(StrictModel):
    host: str = "default"
    prefer_panel_ui: float = Field(default=1.0, ge=0.5, le=2.0)
    autocomplete_confirm_weight: float = Field(default=1.0, ge=0.5, le=2.0)
    timeout_multiplier: float = Field(default=1.0, ge=0.5, le=3.0)
    preferred_result_landmarks: list[str] = Field(default_factory=list)
    primary_action_label_preferences: list[str] = Field(default_factory=list)
