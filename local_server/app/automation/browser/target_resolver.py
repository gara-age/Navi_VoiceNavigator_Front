from __future__ import annotations

import re
import time
from dataclasses import dataclass
from typing import Any


class TargetResolutionError(RuntimeError):
    def __init__(self, message: str, debug_snapshot: str = "") -> None:
        super().__init__(message)
        self.debug_snapshot = debug_snapshot


@dataclass(slots=True)
class ResolvedTarget:
    locator: Any
    score: int
    frame_url: str
    strategy: str


class TargetResolver:
    """Resolve a structured target spec into a Playwright locator.

    This is a generic replacement for scenario-specific lambda lists.
    The executor can reuse this resolver for search, route, shopping,
    and other future site flows.
    """

    def resolve(self, page: Any, target: dict[str, Any], timeout_ms: int = 8000) -> Any:
        resolved = self.resolve_with_metadata(page, target, timeout_ms=timeout_ms)
        return resolved.locator

    def resolve_with_metadata(
        self,
        page: Any,
        target: dict[str, Any],
        timeout_ms: int = 8000,
    ) -> ResolvedTarget:
        deadline = time.time() + (timeout_ms / 1000)
        last_error = ""

        while time.time() < deadline:
            candidates: list[ResolvedTarget] = []
            for frame in self._collect_frames(page, target.get("frame_scope", "all_frames")):
                candidates.extend(self._resolve_candidates_in_frame(frame, target))

            visible_candidates: list[ResolvedTarget] = []
            for candidate in candidates:
                try:
                    candidate.locator.wait_for(state="visible", timeout=250)
                    visible_candidates.append(candidate)
                except Exception as exc:
                    last_error = str(exc)

            if visible_candidates:
                visible_candidates.sort(key=lambda item: item.score, reverse=True)
                index = target.get("index", 0)
                if index < len(visible_candidates):
                    return visible_candidates[index]
                return visible_candidates[0]

            page.wait_for_timeout(300)

        raise TargetResolutionError(
            f"target_not_found:{target.get('description', 'unnamed_target')} | last_error={last_error or 'n/a'}",
            debug_snapshot=self._build_debug_snapshot(page),
        )

    def _collect_frames(self, page: Any, frame_scope: str) -> list[Any]:
        if frame_scope == "main_frame":
            return [page.main_frame]
        return list(page.frames)

    def _resolve_candidates_in_frame(self, frame: Any, target: dict[str, Any]) -> list[ResolvedTarget]:
        resolved: list[ResolvedTarget] = []
        match = target.get("match") or {}

        resolved.extend(self._match_role_and_name(frame, match))
        resolved.extend(self._match_text(frame, match))
        resolved.extend(self._match_attributes(frame, match))
        resolved.extend(self._match_fallbacks(frame, target.get("fallbacks") or []))

        deduped: list[ResolvedTarget] = []
        seen: set[str] = set()
        for item in resolved:
            key = f"{item.frame_url}|{item.strategy}"
            if key in seen:
                continue
            seen.add(key)
            deduped.append(item)
        return deduped

    def _match_role_and_name(self, frame: Any, match: dict[str, Any]) -> list[ResolvedTarget]:
        role = match.get("role")
        tag = match.get("tag")
        name = match.get("name") or match.get("text")
        text_contains = match.get("text_contains")
        text_starts_with = match.get("text_starts_with")
        if not role:
            return []

        candidates: list[ResolvedTarget] = []
        try:
            if name:
                locator = frame.get_by_role(role, name=name).first
                candidates.append(
                    ResolvedTarget(
                        locator=locator,
                        score=140,
                        frame_url=frame.url or "about:blank",
                        strategy=f"role={role}|name={name}",
                    )
                )
        except Exception:
            pass

        if text_starts_with:
            try:
                locator = frame.get_by_role(
                    role,
                    name=re.compile(rf"^{re.escape(text_starts_with)}"),
                ).first
                candidates.append(
                    ResolvedTarget(
                        locator=locator,
                        score=130,
                        frame_url=frame.url or "about:blank",
                        strategy=f"role={role}|name^={text_starts_with}",
                    )
                )
            except Exception:
                pass

        if text_contains:
            try:
                locator = frame.get_by_role(role, name=re.compile(re.escape(text_contains))).first
                candidates.append(
                    ResolvedTarget(
                        locator=locator,
                        score=120,
                        frame_url=frame.url or "about:blank",
                        strategy=f"role={role}|name~=/{text_contains}/",
                    )
                )
            except Exception:
                pass

        if tag:
            role_selector = f"{tag}[role='{role}']"
            try:
                if text_starts_with:
                    locator = frame.locator(role_selector).filter(
                        has_text=re.compile(rf"^{re.escape(text_starts_with)}"),
                    ).first
                    candidates.append(
                        ResolvedTarget(
                            locator=locator,
                            score=160,
                            frame_url=frame.url or "about:blank",
                            strategy=f"tag={tag}|role={role}|text^={text_starts_with}",
                        )
                    )
                elif name:
                    locator = frame.locator(role_selector).filter(
                        has_text=re.compile(re.escape(name)),
                    ).first
                    candidates.append(
                        ResolvedTarget(
                            locator=locator,
                            score=150,
                            frame_url=frame.url or "about:blank",
                            strategy=f"tag={tag}|role={role}|text={name}",
                        )
                    )
            except Exception:
                pass
        return candidates

    def _match_text(self, frame: Any, match: dict[str, Any]) -> list[ResolvedTarget]:
        candidates: list[ResolvedTarget] = []
        text = match.get("text")
        text_contains = match.get("text_contains")

        if text:
            try:
                locator = frame.get_by_text(text, exact=True).first
                candidates.append(
                    ResolvedTarget(
                        locator=locator,
                        score=110,
                        frame_url=frame.url or "about:blank",
                        strategy=f"text={text}",
                    )
                )
            except Exception:
                pass

        if text_contains:
            try:
                locator = frame.get_by_text(text_contains, exact=False).first
                candidates.append(
                    ResolvedTarget(
                        locator=locator,
                        score=90,
                        frame_url=frame.url or "about:blank",
                        strategy=f"text*={text_contains}",
                    )
                )
            except Exception:
                pass
        return candidates

    def _match_attributes(self, frame: Any, match: dict[str, Any]) -> list[ResolvedTarget]:
        candidates: list[ResolvedTarget] = []
        attr_map = [
            ("placeholder_contains", "placeholder", 85),
            ("aria_label_contains", "aria-label", 85),
            ("title_contains", "title", 80),
            ("name_contains", "name", 75),
        ]
        for match_key, attr_name, score in attr_map:
            value = match.get(match_key)
            if not value:
                continue
            try:
                locator = frame.locator(f"[{attr_name}*='{value}']").first
                candidates.append(
                    ResolvedTarget(
                        locator=locator,
                        score=score,
                        frame_url=frame.url or "about:blank",
                        strategy=f"{attr_name}*={value}",
                    )
                )
            except Exception:
                continue
        return candidates

    def _match_fallbacks(self, frame: Any, fallbacks: list[dict[str, Any]]) -> list[ResolvedTarget]:
        candidates: list[ResolvedTarget] = []
        for fallback in fallbacks:
            role = fallback.get("role")
            text = fallback.get("text")
            css = fallback.get("css")
            xpath = fallback.get("xpath")
            exact = fallback.get("exact", True)

            try:
                if role and text:
                    locator = frame.get_by_role(role, name=text if exact else re.compile(re.escape(text))).first
                    candidates.append(
                        ResolvedTarget(
                            locator=locator,
                            score=70 if exact else 65,
                            frame_url=frame.url or "about:blank",
                            strategy=f"fallback-role={role}|text={text}",
                        )
                    )
                    continue

                if text:
                    locator = frame.get_by_text(text, exact=exact).first
                    candidates.append(
                        ResolvedTarget(
                            locator=locator,
                            score=60 if exact else 55,
                            frame_url=frame.url or "about:blank",
                            strategy=f"fallback-text={text}",
                        )
                    )
                    continue

                if css:
                    locator = frame.locator(css).first
                    candidates.append(
                        ResolvedTarget(
                            locator=locator,
                            score=50,
                            frame_url=frame.url or "about:blank",
                            strategy=f"fallback-css={css}",
                        )
                    )
                    continue

                if xpath:
                    locator = frame.locator(f"xpath={xpath}").first
                    candidates.append(
                        ResolvedTarget(
                            locator=locator,
                            score=45,
                            frame_url=frame.url or "about:blank",
                            strategy=f"fallback-xpath={xpath}",
                        )
                    )
            except Exception:
                continue

        return candidates

    def _build_debug_snapshot(self, page: Any) -> str:
        snapshots: list[str] = []
        for index, frame in enumerate(page.frames):
            try:
                frame_name = frame.name or f"frame_{index}"
                frame_url = frame.url or "about:blank"
                texts = frame.locator(
                    "button, a, input, [role='button'], [role='tab'], [role='combobox']"
                ).all_inner_texts()
                normalized = [
                    re.sub(r"\s+", " ", text).strip()
                    for text in texts
                    if re.sub(r"\s+", " ", text).strip()
                ]
                snapshots.append(f"{frame_name}@{frame_url} => {', '.join(normalized[:8]) or 'no_text'}")
            except Exception:
                continue
        return " | ".join(snapshots[:6]) if snapshots else "no_frame_debug"
