from __future__ import annotations

from typing import Any

from pydantic import Field

from local_server.app.automation.core.enums import ActionKind, RiskLevel, TaskType, UiState
from local_server.app.automation.core.schemas import ActionStep, Intent, StrictModel


class ActionTemplate(StrictModel):
    kind: ActionKind
    slot: str | None = None
    label: str | None = None
    target_state: UiState | None = None
    required: bool = True
    copy_slot_value: bool = False


class TaskDefinition(StrictModel):
    task_type: TaskType
    required_slots: list[str]
    optional_slots: list[str] = Field(default_factory=list)
    default_risk_level: RiskLevel
    template: list[ActionTemplate]


TASK_REGISTRY: dict[TaskType, TaskDefinition] = {
    TaskType.KEYWORD_SEARCH: TaskDefinition(
        task_type=TaskType.KEYWORD_SEARCH,
        required_slots=["query"],
        default_risk_level=RiskLevel.LOW,
        template=[
            ActionTemplate(kind=ActionKind.OPEN_PRIMARY_ENTRY, label="search", required=False),
            ActionTemplate(kind=ActionKind.FILL_SLOT, slot="query", copy_slot_value=True),
            ActionTemplate(kind=ActionKind.CHOOSE_SUGGESTION, slot="query", copy_slot_value=True, required=False),
            ActionTemplate(kind=ActionKind.SUBMIT_PRIMARY, label="search"),
            ActionTemplate(kind=ActionKind.READ_RESULTS),
        ],
    ),
    TaskType.SEARCH_AND_OPEN_RESULT: TaskDefinition(
        task_type=TaskType.SEARCH_AND_OPEN_RESULT,
        required_slots=["query"],
        optional_slots=["target_hint"],
        default_risk_level=RiskLevel.LOW,
        template=[
            ActionTemplate(kind=ActionKind.OPEN_PRIMARY_ENTRY, label="search", required=False),
            ActionTemplate(kind=ActionKind.FILL_SLOT, slot="query", copy_slot_value=True),
            ActionTemplate(kind=ActionKind.CHOOSE_SUGGESTION, slot="query", copy_slot_value=True, required=False),
            ActionTemplate(kind=ActionKind.SUBMIT_PRIMARY, label="search"),
            ActionTemplate(kind=ActionKind.SELECT_LIST_ITEM, slot="target_hint", copy_slot_value=True),
        ],
    ),
    TaskType.PAIRED_LOOKUP: TaskDefinition(
        task_type=TaskType.PAIRED_LOOKUP,
        required_slots=["source", "target"],
        default_risk_level=RiskLevel.LOW,
        template=[
            ActionTemplate(kind=ActionKind.OPEN_PRIMARY_ENTRY, label="route", required=False),
            ActionTemplate(kind=ActionKind.FILL_SLOT, slot="source", copy_slot_value=True),
            ActionTemplate(kind=ActionKind.CHOOSE_SUGGESTION, slot="source", copy_slot_value=True),
            ActionTemplate(kind=ActionKind.FILL_SLOT, slot="target", copy_slot_value=True),
            ActionTemplate(kind=ActionKind.CHOOSE_SUGGESTION, slot="target", copy_slot_value=True),
            ActionTemplate(kind=ActionKind.SUBMIT_PRIMARY, label="route"),
            ActionTemplate(kind=ActionKind.READ_RESULTS),
        ],
    ),
    TaskType.FORM_FILL: TaskDefinition(
        task_type=TaskType.FORM_FILL,
        required_slots=["fields"],
        optional_slots=["submit"],
        default_risk_level=RiskLevel.MEDIUM,
        template=[],
    ),
}


def build_task_plan(intent: Intent) -> list[ActionStep]:
    definition = TASK_REGISTRY.get(intent.task_type)
    if definition is None:
        raise ValueError(f"unsupported_task_type:{intent.task_type.value}")

    if intent.task_type == TaskType.FORM_FILL:
        return _build_form_fill_plan(intent)
    if intent.task_type == TaskType.SEARCH_AND_OPEN_RESULT:
        return _build_search_and_open_plan(intent, definition)

    missing = [slot for slot in definition.required_slots if slot not in intent.slots]
    if missing:
        joined = ",".join(missing)
        raise ValueError(f"missing_required_slots:{joined}")

    plan: list[ActionStep] = []
    for index, template in enumerate(definition.template, start=1):
        value: Any | None = None
        if template.copy_slot_value and template.slot is not None:
            value = intent.slots.get(template.slot)
        plan.append(
            ActionStep(
                id=f"{intent.task_type.value}_{index}",
                kind=template.kind,
                slot=template.slot,
                value=value,
                label=template.label,
                target_state=template.target_state,
                required=template.required,
            )
        )
    return plan


def _build_search_and_open_plan(intent: Intent, definition: TaskDefinition) -> list[ActionStep]:
    if "query" not in intent.slots:
        raise ValueError("missing_required_slots:query")

    target_hint = intent.slots.get("target_hint") or intent.slots.get("query")
    if target_hint:
        intent = intent.model_copy(
            update={
                "slots": {
                    **intent.slots,
                    "target_hint": target_hint,
                }
            }
        )

    plan: list[ActionStep] = []
    for index, template in enumerate(definition.template, start=1):
        value: Any | None = None
        if template.copy_slot_value and template.slot is not None:
            value = intent.slots.get(template.slot)
        plan.append(
            ActionStep(
                id=f"{intent.task_type.value}_{index}",
                kind=template.kind,
                slot=template.slot,
                value=value,
                label=template.label,
                target_state=template.target_state,
                required=template.required,
            )
        )
    return plan


def _build_form_fill_plan(intent: Intent) -> list[ActionStep]:
    fields = intent.slots.get("fields")
    if not isinstance(fields, dict) or not fields:
        raise ValueError("form_fill_requires_non_empty_fields_dict")

    plan: list[ActionStep] = []
    for index, (field_name, field_value) in enumerate(fields.items(), start=1):
        plan.append(
            ActionStep(
                id=f"{intent.task_type.value}_{index}",
                kind=ActionKind.FILL_SLOT,
                slot=f"field:{field_name}",
                value=field_value,
            )
        )

    if intent.slots.get("submit", True):
        plan.append(
            ActionStep(
                id=f"{intent.task_type.value}_{len(plan) + 1}",
                kind=ActionKind.SUBMIT_PRIMARY,
                required=False,
            )
        )
    return plan
