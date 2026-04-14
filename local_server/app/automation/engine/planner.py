from __future__ import annotations

from local_server.app.automation.core.schemas import ActionStep, Intent
from local_server.app.automation.core.task_registry import build_task_plan


class PatternPlanner:
    """Compile a structured intent into a task-ontology action sequence."""

    def build_plan(self, intent: Intent) -> list[ActionStep]:
        return build_task_plan(intent)
