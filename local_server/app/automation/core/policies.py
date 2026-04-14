from __future__ import annotations

from pydantic import Field

from local_server.app.automation.core.schemas import StrictModel


class AutomationPolicy(StrictModel):
    auto_execute_threshold: float = Field(default=0.8, ge=0.0, le=1.0)
    cautious_threshold: float = Field(default=0.5, ge=0.0, le=1.0)
    max_local_retries: int = Field(default=2, ge=0)
    max_llm_patch_calls: int = Field(default=0, ge=0)
    default_timeout_ms: int = Field(default=5000, ge=100)
    wait_poll_ms: int = Field(default=250, ge=50)
    suggestion_wait_ms: int = Field(default=900, ge=100)
    max_result_chars: int = Field(default=700, ge=50)
    primary_action_labels: list[str] = Field(
        default_factory=lambda: [
            "search",
            "submit",
            "confirm",
            "apply",
            "route",
            "direction",
            "directions",
            "find",
            "길찾기",
            "검색",
            "확인",
            "적용",
        ]
    )
    dismiss_action_labels: list[str] = Field(
        default_factory=lambda: [
            "close",
            "dismiss",
            "cancel",
            "back",
            "닫기",
            "취소",
            "뒤로",
        ]
    )
    result_region_keywords: list[str] = Field(
        default_factory=lambda: [
            "result",
            "results",
            "summary",
            "route",
            "경로",
            "결과",
            "요약",
        ]
    )
    error_keywords: list[str] = Field(
        default_factory=lambda: [
            "error occurred",
            "failed",
            "something went wrong",
            "문제가 발생",
            "오류가 발생",
            "다시 시도",
            "잠시 후 다시",
            "실패",
        ]
    )


DEFAULT_POLICY = AutomationPolicy()
