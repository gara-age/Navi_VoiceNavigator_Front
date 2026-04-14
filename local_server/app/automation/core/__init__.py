"""Core contracts for the pattern-centric automation engine."""

from local_server.app.automation.core.enums import (
    ActionKind,
    ExecutionMode,
    RiskLevel,
    TaskType,
    UiState,
)
from local_server.app.automation.core.policies import AutomationPolicy, DEFAULT_POLICY
from local_server.app.automation.core.schemas import (
    ActionStep,
    BoundAction,
    CandidateMatch,
    ElementSnapshot,
    ExecutionObservation,
    HostBias,
    Intent,
    PageSnapshot,
    RecoveryPatch,
    RegionSnapshot,
    TaskRequest,
)
from local_server.app.automation.core.task_registry import TASK_REGISTRY, build_task_plan

__all__ = [
    "ActionKind",
    "ActionStep",
    "AutomationPolicy",
    "BoundAction",
    "CandidateMatch",
    "DEFAULT_POLICY",
    "ElementSnapshot",
    "ExecutionMode",
    "ExecutionObservation",
    "HostBias",
    "Intent",
    "PageSnapshot",
    "RecoveryPatch",
    "RegionSnapshot",
    "RiskLevel",
    "TASK_REGISTRY",
    "TaskRequest",
    "TaskType",
    "UiState",
    "build_task_plan",
]
