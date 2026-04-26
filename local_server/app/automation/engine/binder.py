from __future__ import annotations

import re

from local_server.app.automation.core.enums import ActionKind, ExecutionMode, UiState
from local_server.app.automation.core.policies import AutomationPolicy, DEFAULT_POLICY
from local_server.app.automation.core.schemas import (
    ActionStep,
    BoundAction,
    CandidateMatch,
    ElementSnapshot,
    HostBias,
    PageSnapshot,
)

INPUT_LIKE_ROLES = {"textbox", "searchbox", "combobox"}
CLICKABLE_ROLES = {"button", "link", "tab", "menuitem", "option"}
SUGGESTION_ROLES = {"option", "listbox", "link", "button"}
NON_TEXT_INPUT_TYPES = {"range", "checkbox", "radio", "file", "hidden", "submit", "button", "reset", "image", "color"}
ROUTE_ENTRY_LABELS = {"route", "direction", "directions", "길찾기", "경로"}
NEGATIVE_SUBMIT_LABELS = {"clear", "delete", "remove", "mic", "voice", "삭제", "지우기", "음성"}

SLOT_ALIASES: dict[str, list[str]] = {
    "query": ["query", "search", "keyword", "검색", "찾기"],
    "source": ["source", "from", "origin", "departure", "출발", "출발지"],
    "target": ["target", "to", "destination", "arrival", "도착", "도착지"],
    "username": ["username", "user id", "email", "아이디", "이메일", "계정"],
    "password": ["password", "비밀번호", "암호", "passcode"],
}

ACTION_LABEL_ALIASES: dict[str, list[str]] = {
    "route": ["route", "direction", "directions", "길찾기", "경로"],
    "search": ["search", "find", "lookup", "검색", "찾기"],
}


class PatternBinder:
    """Bind action DSL steps to the best currently visible UI affordance."""

    def __init__(self, policy: AutomationPolicy | None = None) -> None:
        self.policy = policy or DEFAULT_POLICY

    def bind(
        self,
        snapshot: PageSnapshot,
        action: ActionStep,
        host_bias: HostBias | None = None,
    ) -> BoundAction:
        bias = host_bias or HostBias()

        if action.kind == ActionKind.WAIT_FOR_STATE:
            return BoundAction(
                action=action,
                mode=ExecutionMode.WAIT_STATE,
                confidence=1.0,
                notes=[f"wait_for:{action.target_state.value if action.target_state else 'unknown'}"],
            )

        if action.kind == ActionKind.OPEN_PRIMARY_ENTRY and self._can_skip_primary_entry(snapshot, action):
            return BoundAction(
                action=action,
                mode=ExecutionMode.NOOP,
                confidence=1.0,
                notes=["primary entry already available"],
            )

        if action.kind == ActionKind.READ_RESULTS:
            region_bound = self._bind_result_region(snapshot, action, bias)
            if region_bound is not None:
                return region_bound

        if (
            action.kind == ActionKind.SUBMIT_PRIMARY
            and _normalize_text(action.label) == "search"
            and snapshot.state == UiState.SUGGESTION_OPEN
        ):
            query_action = ActionStep(
                id=f"{action.id}__query_focus",
                kind=ActionKind.RETRY_FOCUS,
                slot="query",
                required=False,
            )
            query_matches = self._rank_element_candidates(snapshot, query_action, bias)
            selected = query_matches[0] if query_matches else None
            return BoundAction(
                action=action,
                mode=ExecutionMode.KEYBOARD_PRESS,
                confidence=0.92,
                keyboard_key="Enter",
                selected_candidate=selected,
                top_candidates=query_matches[:3],
                notes=["search_submit_enter_when_suggestion_open"],
            )

        matches = self._rank_element_candidates(snapshot, action, bias)
        if matches:
            best = matches[0]
            return BoundAction(
                action=action,
                mode=_mode_for_action(action.kind),
                confidence=best.score,
                selected_candidate=best,
                top_candidates=matches[:3],
            )

        return self._fallback(snapshot, action)

    def _can_skip_primary_entry(self, snapshot: PageSnapshot, action: ActionStep) -> bool:
        label = _normalize_text(action.label)
        if label in ROUTE_ENTRY_LABELS:
            return self._has_slot_ready_inputs(snapshot, {"source", "target"})
        return snapshot.state in {UiState.INPUT_READY, UiState.SUGGESTION_OPEN, UiState.RESULTS_READY}

    def _has_slot_ready_inputs(self, snapshot: PageSnapshot, slots: set[str]) -> bool:
        matched_slots = set()
        for slot in slots:
            aliases = self._slot_aliases(slot)
            for element in snapshot.elements:
                if not self._is_text_entry_candidate(element):
                    continue
                corpus = _element_corpus(element)
                if any(alias in corpus for alias in aliases):
                    matched_slots.add(slot)
                    break
        return matched_slots == slots

    def _bind_result_region(
        self,
        snapshot: PageSnapshot,
        action: ActionStep,
        host_bias: HostBias,
    ) -> BoundAction | None:
        scored_regions: list[tuple[float, str, str, list[str]]] = []
        preferred = {_normalize_text(item) for item in host_bias.preferred_result_landmarks}
        for region in snapshot.result_regions:
            corpus = _normalize_text(f"{region.name} {region.text_preview}")
            score = 0.25
            notes: list[str] = []
            if region.text_preview:
                score += 0.35
                notes.append("has_visible_text")
            if any(label in corpus for label in self.policy.result_region_keywords):
                score += 0.25
                notes.append("result_keyword_match")
            if preferred and any(label in corpus for label in preferred):
                score += 0.15
                notes.append("host_bias_landmark_match")
            scored_regions.append((min(score, 1.0), region.id, region.name or region.text_preview, notes))

        if not scored_regions:
            page_corpus = _normalize_text(
                " ".join(
                    filter(
                        None,
                        [
                            snapshot.title,
                            *(element.text for element in snapshot.elements),
                            *(element.name for element in snapshot.elements),
                            *(element.placeholder for element in snapshot.elements),
                        ],
                    )
                )
            )
            route_indicators = ("길찾기", "route", "경로")
            summary_indicators = ("출발", "도착", "요금", "시간", "대중교통", "자동차", "도보", "자전거")
            if any(token in page_corpus for token in route_indicators) and any(
                token in page_corpus for token in summary_indicators
            ):
                top = CandidateMatch(
                    candidate_id="__body__",
                    score=0.6,
                    role="region",
                    label="body_fallback",
                    notes=["body_result_fallback"],
                )
                return BoundAction(
                    action=action,
                    mode=ExecutionMode.READ_REGION,
                    confidence=top.score,
                    region_id=top.candidate_id,
                    selected_candidate=top,
                    top_candidates=[top],
                    notes=["body_result_fallback"],
                )
            return None

        scored_regions.sort(key=lambda item: item[0], reverse=True)
        top_candidates = [
            CandidateMatch(
                candidate_id=region_id,
                score=score,
                role="region",
                label=label,
                notes=notes,
            )
            for score, region_id, label, notes in scored_regions[:3]
        ]
        top = top_candidates[0]
        return BoundAction(
            action=action,
            mode=ExecutionMode.READ_REGION,
            confidence=top.score,
            region_id=top.candidate_id,
            selected_candidate=top,
            top_candidates=top_candidates,
        )

    def _rank_element_candidates(
        self,
        snapshot: PageSnapshot,
        action: ActionStep,
        host_bias: HostBias,
    ) -> list[CandidateMatch]:
        ranked: list[CandidateMatch] = []
        for element in snapshot.elements:
            score, notes = self._score_element(snapshot, action, element, host_bias)
            if score <= 0:
                continue
            ranked.append(
                CandidateMatch(
                    candidate_id=element.id,
                    score=min(score, 1.0),
                    role=element.role,
                    label=_element_label(element),
                    locator_hint=element.locator_hint,
                    notes=notes,
                )
            )

        ranked.sort(key=lambda item: item.score, reverse=True)
        return ranked

    def _score_element(
        self,
        snapshot: PageSnapshot,
        action: ActionStep,
        element: ElementSnapshot,
        host_bias: HostBias,
    ) -> tuple[float, list[str]]:
        if not element.visible or not element.enabled:
            return 0.0, []
        if not element.interactable and action.kind != ActionKind.READ_RESULTS:
            return 0.0, []

        corpus = _element_corpus(element)
        content_corpus = _content_corpus(element)
        notes: list[str] = []
        score = 0.0

        if action.kind in {ActionKind.FILL_SLOT, ActionKind.RETRY_FOCUS}:
            if self._is_non_text_input(element):
                return 0.0, []
            if element.role in INPUT_LIKE_ROLES or element.tag in {"input", "textarea", "select"}:
                score += 0.42
                notes.append("input_like_role")
            if element.editable:
                score += 0.28
                notes.append("editable")
            if element.role == "combobox":
                score += 0.06 * host_bias.autocomplete_confirm_weight
                notes.append("combobox_bonus")
            alias_bonus = self._alias_bonus(action.slot, corpus, element.parent_context)
            score += alias_bonus
            if alias_bonus:
                notes.append("slot_alias_match")
            positional_bonus = self._paired_input_position_bonus(snapshot, action, element)
            score += positional_bonus
            if positional_bonus:
                notes.append("paired_input_position_bonus")

        elif action.kind == ActionKind.CHOOSE_SUGGESTION:
            if element.role == "option" or element.tag in {"li", "option"}:
                score += 0.42
                notes.append("suggestion_option_role")
            elif element.role == "listbox":
                score += 0.24
                notes.append("suggestion_listbox_role")
            elif element.role in SUGGESTION_ROLES:
                score += 0.18
                notes.append("suggestion_aux_role")
            if action.value is not None:
                value_score = self._value_bonus(action.value, content_corpus or corpus)
                score += value_score * host_bias.autocomplete_confirm_weight
                if value_score:
                    notes.append("value_match")
            alias_bonus = self._alias_bonus(action.slot, corpus, element.parent_context)
            score += alias_bonus * 0.4
            if alias_bonus:
                notes.append("slot_context_match")
            if snapshot.state == UiState.SUGGESTION_OPEN:
                score += 0.08
                notes.append("state_suggestion_open")

        elif action.kind in {
            ActionKind.OPEN_PRIMARY_ENTRY,
            ActionKind.SUBMIT_PRIMARY,
            ActionKind.SWITCH_TAB,
            ActionKind.SELECT_LIST_ITEM,
        }:
            if element.role in CLICKABLE_ROLES or element.tag in {"button", "a"}:
                score += 0.4
                notes.append("semantic_clickable")
            elif element.clickable:
                score += 0.18
                notes.append("generic_clickable")
            label_bonus = self._primary_label_bonus(content_corpus, host_bias)
            score += label_bonus
            if label_bonus:
                notes.append("primary_label_match")
            explicit_label_bonus = self._action_label_bonus(action.label, content_corpus)
            score += explicit_label_bonus
            if explicit_label_bonus:
                notes.append("explicit_label_match")
            if action.kind == ActionKind.SELECT_LIST_ITEM:
                value_bonus = self._value_bonus(action.value, content_corpus or corpus)
                score += value_bonus
                if value_bonus:
                    notes.append("list_value_match")
                if element.role in {"link", "option"} or element.tag == "a":
                    score += 0.08
                    notes.append("result_link_bonus")
            if host_bias.prefer_panel_ui > 1.0 and any(
                token in _normalize_text(element.parent_context) for token in ("panel", "tab", "route", "길찾기")
            ):
                score += min(0.15, 0.08 * host_bias.prefer_panel_ui)
                notes.append("panel_bias")
            if element.tag in {"div", "span"} and element.role not in CLICKABLE_ROLES and len(content_corpus) > 40:
                score -= 0.25
                notes.append("generic_container_penalty")
            if action.kind == ActionKind.SUBMIT_PRIMARY:
                locator_corpus = _normalize_text(element.locator_hint)
                if "선택됨" in content_corpus or "selected" in content_corpus:
                    score -= 0.18
                    notes.append("selected_tab_penalty")
                if any(token in locator_corpus for token in ("search", "submit", "confirm", "apply")):
                    score += 0.18
                    notes.append("submit_locator_bonus")
                if any(token in content_corpus for token in NEGATIVE_SUBMIT_LABELS):
                    score -= 0.45
                    notes.append("negative_submit_label_penalty")

        elif action.kind == ActionKind.DISMISS_DIALOG:
            if element.clickable or element.tag in {"button", "a"}:
                score += 0.35
                notes.append("dismiss_clickable")
            if any(label in content_corpus for label in self.policy.dismiss_action_labels):
                score += 0.42
                notes.append("dismiss_label_match")
            if snapshot.dialogs:
                score += 0.1
                notes.append("dialog_present")

        return min(score, 1.0), notes

    def _fallback(self, snapshot: PageSnapshot, action: ActionStep) -> BoundAction:
        if action.kind in {ActionKind.CHOOSE_SUGGESTION, ActionKind.SUBMIT_PRIMARY}:
            return BoundAction(
                action=action,
                mode=ExecutionMode.KEYBOARD_PRESS,
                confidence=0.55,
                keyboard_key="Enter",
                notes=["enter_fallback"],
            )

        if action.kind == ActionKind.DISMISS_DIALOG and snapshot.state == UiState.DIALOG_BLOCKING:
            return BoundAction(
                action=action,
                mode=ExecutionMode.KEYBOARD_PRESS,
                confidence=0.55,
                keyboard_key="Escape",
                notes=["escape_fallback"],
            )

        if not action.required:
            return BoundAction(
                action=action,
                mode=ExecutionMode.NOOP,
                confidence=0.4,
                notes=["optional_action_skipped"],
            )

        return BoundAction(
            action=action,
            mode=ExecutionMode.NOOP,
            confidence=0.0,
            notes=["no_binding_found"],
        )

    def _alias_bonus(self, slot: str | None, corpus: str, parent_context: str) -> float:
        if not slot:
            return 0.0
        aliases = self._slot_aliases(slot)
        if not aliases:
            return 0.0
        parent = _normalize_text(parent_context)
        score = 0.0
        if any(alias in corpus for alias in aliases):
            score += 0.28
        if parent and any(alias in parent for alias in aliases):
            score += 0.12
        return score

    def _value_bonus(self, value: object, corpus: str) -> float:
        text = _normalize_text(value)
        if not text:
            return 0.0
        if corpus == text:
            return 0.48
        if text in corpus:
            return 0.36
        if all(token in corpus for token in text.split() if token):
            return 0.22
        return 0.0

    def _primary_label_bonus(self, corpus: str, host_bias: HostBias) -> float:
        labels = list(self.policy.primary_action_labels)
        labels.extend(host_bias.primary_action_label_preferences)
        if any(_normalize_text(label) in corpus for label in labels if label):
            return 0.34
        return 0.0

    def _action_label_bonus(self, label: str | None, corpus: str) -> float:
        if not label:
            return 0.0
        normalized = _normalize_text(label)
        aliases = ACTION_LABEL_ALIASES.get(normalized, [normalized])
        if any(_normalize_text(alias) in corpus for alias in aliases if alias):
            return 0.3
        return 0.0

    def _slot_aliases(self, slot: str) -> list[str]:
        normalized = slot.split(":", 1)[-1].strip().lower()
        aliases = list(SLOT_ALIASES.get(normalized, []))
        if normalized not in aliases:
            aliases.append(normalized)
        for token in re.split(r"[_\-\s]+", normalized):
            if token and token not in aliases:
                aliases.append(token)
        return [_normalize_text(alias) for alias in aliases if alias]

    def _paired_input_position_bonus(
        self,
        snapshot: PageSnapshot,
        action: ActionStep,
        element: ElementSnapshot,
    ) -> float:
        if action.slot not in {"source", "target"}:
            return 0.0

        page_corpus = _normalize_text(
            " ".join(
                filter(
                    None,
                    [
                        *(item.text for item in snapshot.elements),
                        *(item.name for item in snapshot.elements),
                        *(item.placeholder for item in snapshot.elements),
                        *(region.name for region in snapshot.panels),
                        *(region.text_preview for region in snapshot.panels),
                    ],
                )
            )
        )
        if not any(token in page_corpus for token in ("출발", "도착", "source", "destination", "origin", "arrival")):
            return 0.0

        ordered_inputs = [
            candidate
            for candidate in snapshot.elements
            if candidate.visible
            and candidate.enabled
            and candidate.interactable
            and self._is_text_entry_candidate(candidate)
        ]
        if len(ordered_inputs) < 2:
            return 0.0

        source_candidate = ordered_inputs[0]
        target_candidate = ordered_inputs[1]
        if action.slot == "source" and element.id == source_candidate.id:
            return 0.2
        if action.slot == "target" and element.id == target_candidate.id:
            return 0.2
        return 0.0

    def _is_text_entry_candidate(self, element: ElementSnapshot) -> bool:
        if self._is_non_text_input(element):
            return False
        return bool(
            element.editable
            or element.role in INPUT_LIKE_ROLES
            or element.tag in {"input", "textarea", "select"}
        )

    def _is_non_text_input(self, element: ElementSnapshot) -> bool:
        input_type = _normalize_text(element.input_type)
        if input_type in NON_TEXT_INPUT_TYPES:
            return True

        locator_corpus = _normalize_text(element.locator_hint)
        label_corpus = _normalize_text(
            " ".join(
                filter(
                    None,
                    [
                        element.name,
                        element.text,
                        element.placeholder,
                    ],
                )
            )
        )
        if 'type="range"' in locator_corpus:
            return True
        if "slider" in label_corpus or "slider" in locator_corpus:
            return True
        return False


def _mode_for_action(kind: ActionKind) -> ExecutionMode:
    if kind == ActionKind.FILL_SLOT:
        return ExecutionMode.CANDIDATE_FILL
    if kind == ActionKind.READ_RESULTS:
        return ExecutionMode.READ_REGION
    return ExecutionMode.CANDIDATE_CLICK


def _element_corpus(element: ElementSnapshot) -> str:
    return _normalize_text(
        " ".join(
            filter(
                None,
                [
                    element.role,
                    element.tag,
                    element.name,
                    element.text,
                    element.placeholder,
                    element.html_name,
                    element.parent_context,
                    *element.landmarks,
                ],
            )
        )
    )


def _content_corpus(element: ElementSnapshot) -> str:
    return _normalize_text(
        " ".join(
            filter(
                None,
                [
                    element.name,
                    element.text,
                    element.placeholder,
                    element.html_name,
                    element.parent_context,
                ],
            )
        )
    )


def _element_label(element: ElementSnapshot) -> str:
    return element.name or element.text or element.placeholder or element.locator_hint or element.id


def _normalize_text(value: object) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip().lower()
