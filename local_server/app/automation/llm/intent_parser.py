from __future__ import annotations

import re

from local_server.app.automation.core.enums import RiskLevel, TaskType
from local_server.app.automation.core.schemas import Intent, TaskRequest


class HeuristicIntentParser:
    """Fallback parser until a dedicated LLM-backed intent service is wired in."""

    _paired_lookup_patterns = [
        re.compile(
            r"(?P<source>.+?)에서\s+(?P<target>.+?)(?=\s+(?:가는?\s+)?(?:경로|길)\b|\s+(?:알려줘|찾아줘|보여줘)|$)",
            re.IGNORECASE,
        ),
        re.compile(
            r"from\s+(?P<source>.+?)\s+to\s+(?P<target>.+?)(?=\s*$|\s+(?:route|directions|search|find|show|look\s+up)\b)",
            re.IGNORECASE,
        ),
    ]

    _search_keywords = [
        "search",
        "find",
        "look up",
        "검색",
        "찾아",
        "찾기",
    ]

    _open_keywords = [
        "open",
        "go to",
        "visit",
        "enter",
        "접속",
        "들어가",
        "열어",
    ]

    _search_cleanup_tokens = [
        "search for",
        "search",
        "find",
        "look up",
        "검색해줘",
        "검색",
        "찾아줘",
        "찾아",
        "찾기",
    ]

    def resolve(self, task_request: TaskRequest) -> Intent:
        if task_request.intent is not None:
            return task_request.intent
        return self.parse_user_request(task_request.user_request)

    def parse_user_request(self, user_request: str) -> Intent:
        text = re.sub(r"\s+", " ", user_request or "").strip()
        if not text:
            raise ValueError("user_request_missing")

        for pattern in self._paired_lookup_patterns:
            match = pattern.search(text)
            if match:
                source = match.group("source").strip(" ,")
                target = match.group("target").strip(" ,")
                if source and target:
                    return Intent(
                        task_type=TaskType.PAIRED_LOOKUP,
                        slots={"source": source, "target": target},
                        risk_level=RiskLevel.LOW,
                        confidence=0.82,
                    )

        normalized = text.lower()
        if any(keyword in normalized for keyword in self._search_keywords) and any(
            keyword in normalized for keyword in self._open_keywords
        ):
            query = self._extract_query_for_open(text)
            return Intent(
                task_type=TaskType.SEARCH_AND_OPEN_RESULT,
                slots={
                    "query": query,
                    "target_hint": query,
                },
                risk_level=RiskLevel.LOW,
                confidence=0.72,
            )

        if any(keyword in normalized for keyword in self._search_keywords):
            query = self._extract_query(text)
            return Intent(
                task_type=TaskType.KEYWORD_SEARCH,
                slots={"query": query},
                risk_level=RiskLevel.LOW,
                confidence=0.64,
            )

        return Intent(
            task_type=TaskType.KEYWORD_SEARCH,
            slots={"query": text},
            risk_level=RiskLevel.LOW,
            confidence=0.42,
        )

    def _extract_query(self, text: str) -> str:
        normalized = text
        for token in self._search_cleanup_tokens:
            normalized = re.sub(re.escape(token), " ", normalized, flags=re.IGNORECASE)
        normalized = re.sub(r"\s+", " ", normalized).strip()
        return normalized or text

    def _extract_query_for_open(self, text: str) -> str:
        normalized = text
        cleanup_patterns = [
            r"^\s*(구글|google|네이버|naver|유튜브|youtube)에서\s+",
            r"\s*검색해서\s*들어가(?:줘|주세요|주라)?",
            r"\s*검색하고\s*들어가(?:줘|주세요|주라)?",
            r"\s*검색 후\s*들어가(?:줘|주세요|주라)?",
            r"\s*검색해서\s*접속(?:해줘|해주세요)?",
            r"\s*검색하고\s*접속(?:해줘|해주세요)?",
            r"\s*search\s+for\s+",
            r"\s*and\s+open\b",
            r"\s*and\s+go\s+to\b",
            r"\s*open\b",
            r"\s+it$",
        ]
        for pattern in cleanup_patterns:
            normalized = re.sub(pattern, " ", normalized, flags=re.IGNORECASE)
        normalized = re.sub(r"\s+", " ", normalized).strip(" ,")
        return normalized or self._extract_query(text)
