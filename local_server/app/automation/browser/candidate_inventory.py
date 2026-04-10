from __future__ import annotations

import json
import re
from typing import Any


INTERACTIVE_ROLES = {
    "button",
    "link",
    "textbox",
    "searchbox",
    "combobox",
    "listbox",
    "option",
    "checkbox",
    "radio",
    "switch",
    "tab",
    "tabpanel",
    "dialog",
    "menuitem",
}

TEXT_OPTIONAL_TAGS = {
    "input",
    "button",
}

TEXT_OPTIONAL_ROLES = {
    "combobox",
    "listbox",
    "option",
    "dialog",
}


def collect_raw_candidates(page: Any) -> list[dict[str, Any]]:
    """Collect broadly interactive DOM candidates without dumping full HTML."""
    return page.evaluate(
        """() => {
            const interactiveRoles = new Set([
              'button', 'link', 'textbox', 'searchbox', 'combobox', 'listbox',
              'option', 'checkbox', 'radio', 'switch', 'tab', 'tabpanel',
              'dialog', 'menuitem'
            ]);
            const traditionalTags = new Set([
              'input', 'button', 'a', 'textarea', 'select',
              'option', 'label', 'summary', 'details'
            ]);
            const excludedTags = new Set([
              'script', 'style', 'template', 'meta', 'link', 'noscript'
            ]);
            const ariaHintAttrs = [
              'aria-expanded',
              'aria-controls',
              'aria-haspopup',
              'aria-activedescendant'
            ];

            const normalizeText = (value) =>
              (value || '').replace(/\\s+/g, ' ').trim();

            const isContentEditable = (element) =>
              (element.getAttribute('contenteditable') || '').toLowerCase() === 'true';

            const hasInteractiveSignal = (element) => {
              const tag = (element.tagName || '').toLowerCase();
              const role = (element.getAttribute('role') || '').toLowerCase();
              const tabindex = element.getAttribute('tabindex');
              const tabIndexValue = tabindex === null ? null : Number(tabindex);
              return (
                traditionalTags.has(tag) ||
                interactiveRoles.has(role) ||
                isContentEditable(element) ||
                (tabIndexValue !== null && Number.isFinite(tabIndexValue) && tabIndexValue >= 0) ||
                ariaHintAttrs.some((attr) => element.hasAttribute(attr)) ||
                typeof element.onclick === 'function' ||
                typeof element.onfocus === 'function' ||
                element.hasAttribute('onclick') ||
                element.hasAttribute('onfocus')
              );
            };

            const isHidden = (element, style, rect) => {
              if (excludedTags.has((element.tagName || '').toLowerCase())) {
                return true;
              }
              if (element.hidden) {
                return true;
              }
              if ((element.getAttribute('aria-hidden') || '').toLowerCase() === 'true') {
                return true;
              }
              if (style.display === 'none' || style.visibility === 'hidden') {
                return true;
              }
              if (Number(style.opacity || '1') === 0) {
                return true;
              }
              if (rect.width <= 0 || rect.height <= 0) {
                return true;
              }
              return false;
            };

            const isCoveredAtCenter = (element, rect) => {
              const centerX = rect.left + (rect.width / 2);
              const centerY = rect.top + (rect.height / 2);
              if (
                !Number.isFinite(centerX) ||
                !Number.isFinite(centerY) ||
                centerX < 0 ||
                centerY < 0 ||
                centerX > window.innerWidth ||
                centerY > window.innerHeight
              ) {
                return false;
              }

              const topElement = document.elementFromPoint(centerX, centerY);
              if (!topElement) {
                return false;
              }
              return topElement !== element && !element.contains(topElement) && !topElement.contains(element);
            };

            const hasInteractiveBlocker = (element, style) => {
              if (style.pointerEvents === 'none') {
                return true;
              }
              if (element.closest('[inert]')) {
                return true;
              }
              return false;
            };

            const isMeaninglessWrapper = (element, tag, text, role, clickable) => {
              if (tag !== 'div' && tag !== 'span') {
                return false;
              }
              if (role) {
                return false;
              }
              if (clickable) {
                return false;
              }
              if (text) {
                return false;
              }
              return !element.getAttribute('aria-label') && !element.getAttribute('title');
            };

            const buildLocatorHint = (element, tag) => {
              const id = element.id ? `#${element.id}` : '';
              const className = normalizeText(element.className || '')
                .split(' ')
                .filter(Boolean)
                .slice(0, 2)
                .map((item) => `.${item}`)
                .join('');
              const name = element.getAttribute('name');
              const type = element.getAttribute('type');
              if (id) {
                return `${tag}${id}`;
              }
              if (name) {
                return `${tag}[name="${name}"]`;
              }
              if (type) {
                return `${tag}[type="${type}"]${className}`;
              }
              return `${tag}${className || ''}`;
            };

            const elements = Array.from(document.querySelectorAll('*'));
            const raw = [];
            let sequence = 1;

            for (const element of elements) {
              const tag = (element.tagName || '').toLowerCase();
              const role = (element.getAttribute('role') || '').toLowerCase() || null;
              const rect = element.getBoundingClientRect();
              const style = window.getComputedStyle(element);
              const clickable = (
                tag === 'button' ||
                tag === 'a' ||
                role === 'button' ||
                role === 'link' ||
                typeof element.onclick === 'function' ||
                element.hasAttribute('onclick')
              );
              const editable = (
                tag === 'input' ||
                tag === 'textarea' ||
                tag === 'select' ||
                role === 'textbox' ||
                role === 'searchbox' ||
                role === 'combobox' ||
                isContentEditable(element)
              );
              const text = normalizeText(element.innerText || element.textContent || '');
              const ariaLabel = normalizeText(element.getAttribute('aria-label'));
              const placeholder = normalizeText(element.getAttribute('placeholder'));
              const title = normalizeText(element.getAttribute('title'));
              const visible = !isHidden(element, style, rect);
              const enabled = !element.hasAttribute('disabled') && element.getAttribute('aria-disabled') !== 'true';
              const pointerEvents = style.pointerEvents || null;
              const inert = !!element.closest('[inert]');
              const coveredByOverlay = isCoveredAtCenter(element, rect);
              const interactable = !hasInteractiveBlocker(element, style) && visible && enabled && !coveredByOverlay;
              const tabindexAttr = element.getAttribute('tabindex');
              const tabindex = tabindexAttr === null ? null : Number(tabindexAttr);

              if (!hasInteractiveSignal(element)) {
                continue;
              }
              if (isMeaninglessWrapper(element, tag, text, role, clickable)) {
                continue;
              }

              const candidateId = `cand_${String(sequence).padStart(4, '0')}`;
              element.setAttribute('data-vn-candidate-id', candidateId);

              raw.push({
                candidate_id: candidateId,
                tag,
                text,
                visible,
                enabled,
                locator_hint: buildLocatorHint(element, tag),
                role,
                aria_label: ariaLabel || null,
                placeholder: placeholder || null,
                title: title || null,
                name: element.getAttribute('name'),
                type: element.getAttribute('type'),
                clickable,
                editable,
                interactable,
                tabindex: Number.isFinite(tabindex) ? tabindex : null,
                bounding_box: {
                  x: Math.round(rect.x),
                  y: Math.round(rect.y),
                  width: Math.round(rect.width),
                  height: Math.round(rect.height),
                },
                parent_context: normalizeText(
                  element.closest('form, section, article, nav, aside, dialog, [role="dialog"]')?.getAttribute('aria-label') ||
                  element.closest('form, section, article, nav, aside, dialog, [role="dialog"]')?.getAttribute('id') ||
                  ''
                ) || null,
                element_id: element.id || null,
                for_id: element.getAttribute('for'),
                controls: element.getAttribute('aria-controls'),
                labelledby: element.getAttribute('aria-labelledby'),
                expanded: element.getAttribute('aria-expanded'),
                haspopup: element.getAttribute('aria-haspopup'),
                activedescendant: element.getAttribute('aria-activedescendant'),
                pointer_events: pointerEvents,
                inert,
                covered_by_overlay: coveredByOverlay,
              });
              sequence += 1;
            }

            return raw;
        }"""
    )


def filter_visible_candidates(raw_candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    filtered: list[dict[str, Any]] = []
    for candidate in raw_candidates:
        visible = bool(candidate.get("visible"))
        enabled = bool(candidate.get("enabled"))
        box = candidate.get("bounding_box") or {}
        has_box = bool((box.get("width") or 0) > 0 and (box.get("height") or 0) > 0)
        interactable = bool(candidate.get("interactable"))
        semantic_interactable = bool(candidate.get("clickable") or candidate.get("editable"))
        role = (candidate.get("role") or "").strip().lower()
        tag = (candidate.get("tag") or "").strip().lower()
        has_text_signal = any(
            bool((candidate.get(key) or "").strip())
            for key in ("text", "aria_label", "placeholder", "title")
        )

        if not visible or not enabled:
            continue
        if not has_box and not semantic_interactable:
            continue
        if not interactable and semantic_interactable:
            continue
        if not has_text_signal and tag not in TEXT_OPTIONAL_TAGS and role not in TEXT_OPTIONAL_ROLES:
            continue
        filtered.append(candidate)
    return filtered


def structure_candidates(visible_candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    structured: list[dict[str, Any]] = []
    for candidate in visible_candidates:
        structured.append(
            {
                "candidate_id": candidate.get("candidate_id"),
                "tag": candidate.get("tag"),
                "text": candidate.get("text", ""),
                "visible": bool(candidate.get("visible")),
                "enabled": bool(candidate.get("enabled")),
                "locator_hint": candidate.get("locator_hint"),
                "role": candidate.get("role"),
                "aria_label": candidate.get("aria_label"),
                "placeholder": candidate.get("placeholder"),
                "title": candidate.get("title"),
                "name": candidate.get("name"),
                "type": candidate.get("type"),
                "clickable": bool(candidate.get("clickable")),
                "editable": bool(candidate.get("editable")),
                "interactable": bool(candidate.get("interactable")),
                "tabindex": candidate.get("tabindex"),
                "bounding_box": candidate.get("bounding_box"),
                "parent_context": candidate.get("parent_context"),
                "element_id": candidate.get("element_id"),
                "for_id": candidate.get("for_id"),
                "controls": candidate.get("controls"),
                "labelledby": candidate.get("labelledby"),
                "expanded": candidate.get("expanded"),
                "haspopup": candidate.get("haspopup"),
                "activedescendant": candidate.get("activedescendant"),
                "pointer_events": candidate.get("pointer_events"),
                "inert": bool(candidate.get("inert")),
                "covered_by_overlay": bool(candidate.get("covered_by_overlay")),
            }
        )
    return structured


def deduplicate_candidates(structured_candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    deduped: list[dict[str, Any]] = []
    seen: dict[str, dict[str, Any]] = {}

    for candidate in structured_candidates:
        box = candidate.get("bounding_box") or {}
        position_key = (
            f"{box.get('x', 0)}:{box.get('y', 0)}:{box.get('width', 0)}:{box.get('height', 0)}"
        )
        text_key = (candidate.get("text") or candidate.get("aria_label") or candidate.get("placeholder") or "").strip()
        role_key = (candidate.get("role") or candidate.get("tag") or "").strip()
        dedupe_key = f"{position_key}|{text_key}|{role_key}"
        previous = seen.get(dedupe_key)
        if previous is None:
            seen[dedupe_key] = candidate
            continue
        if _candidate_specificity_score(candidate) > _candidate_specificity_score(previous):
            seen[dedupe_key] = candidate

    deduped.extend(seen.values())
    deduped.sort(key=_candidate_sort_key)
    return deduped


def build_relation_groups(structured_candidates: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    by_id = {
        candidate.get("element_id"): candidate
        for candidate in structured_candidates
        if candidate.get("element_id")
    }
    by_controls: dict[str, list[dict[str, Any]]] = {}
    for candidate in structured_candidates:
        controls = candidate.get("controls")
        if controls:
            by_controls.setdefault(controls, []).append(candidate)

    combobox_groups: list[dict[str, Any]] = []
    label_input_groups: list[dict[str, Any]] = []
    dialog_groups: list[dict[str, Any]] = []
    tab_groups: list[dict[str, Any]] = []

    for candidate in structured_candidates:
        role = (candidate.get("role") or "").lower()
        tag = (candidate.get("tag") or "").lower()
        candidate_id = candidate.get("candidate_id")
        controls = candidate.get("controls")

        if role == "combobox":
            listbox = by_id.get(controls) if controls else None
            group = {
                "combobox_candidate_id": candidate_id,
                "listbox_candidate_id": listbox.get("candidate_id") if listbox else None,
                "option_candidate_ids": [
                    item.get("candidate_id")
                    for item in structured_candidates
                    if (item.get("role") or "").lower() == "option"
                ],
            }
            combobox_groups.append(group)

        if tag == "label" and candidate.get("for_id"):
            linked = by_id.get(candidate.get("for_id"))
            if linked:
                label_input_groups.append(
                    {
                        "label_candidate_id": candidate_id,
                        "input_candidate_id": linked.get("candidate_id"),
                    }
                )

        if role == "button" and controls:
            dialog = by_id.get(controls)
            if dialog and (dialog.get("role") or "").lower() == "dialog":
                dialog_groups.append(
                    {
                        "button_candidate_id": candidate_id,
                        "dialog_candidate_id": dialog.get("candidate_id"),
                    }
                )

        if role == "tab" and controls:
            panel = by_id.get(controls)
            if panel and (panel.get("role") or "").lower() == "tabpanel":
                tab_groups.append(
                    {
                        "tab_candidate_id": candidate_id,
                        "tabpanel_candidate_id": panel.get("candidate_id"),
                    }
                )

    return {
        "combobox_groups": combobox_groups,
        "label_input_groups": label_input_groups,
        "dialog_groups": dialog_groups,
        "tab_groups": tab_groups,
    }


def build_candidate_inventory(page: Any) -> dict[str, Any]:
    raw_candidates = collect_raw_candidates(page)
    visible_candidates = filter_visible_candidates(raw_candidates)
    structured_candidates = structure_candidates(visible_candidates)
    deduplicated_candidates = deduplicate_candidates(structured_candidates)
    relation_groups = build_relation_groups(deduplicated_candidates)
    return {
        "candidates": deduplicated_candidates,
        "relation_groups": relation_groups,
        "summary": {
            "raw_count": len(raw_candidates),
            "visible_count": len(visible_candidates),
            "deduplicated_count": len(deduplicated_candidates),
        },
    }


def summarize_candidate_inventory(inventory: dict[str, Any], limit: int = 8) -> str:
    summary = inventory.get("summary") or {}
    candidates = inventory.get("candidates") or []
    preview = []
    for candidate in candidates[:limit]:
        text = candidate.get("text") or candidate.get("aria_label") or candidate.get("placeholder") or "no_text"
        role = candidate.get("role") or candidate.get("tag") or "unknown"
        preview.append(f"{role}:{text}")
    return json.dumps(
        {
            "summary": {
                "raw_count": summary.get("raw_count", 0),
                "visible_count": summary.get("visible_count", 0),
                "deduplicated_count": summary.get("deduplicated_count", 0),
            },
            "preview": preview,
            "relation_groups": inventory.get("relation_groups") or {},
        },
        ensure_ascii=False,
    )


def score_candidate_against_target(candidate: dict[str, Any], target: dict[str, Any]) -> int:
    match = target.get("match") or {}
    fields = [
        candidate.get("text") or "",
        candidate.get("aria_label") or "",
        candidate.get("placeholder") or "",
        candidate.get("title") or "",
        candidate.get("name") or "",
    ]
    normalized_fields = [str(item).strip().lower() for item in fields if str(item).strip()]
    combined_text = " ".join(normalized_fields).strip()
    role = str(candidate.get("role") or "").strip().lower()
    tag = str(candidate.get("tag") or "").strip().lower()
    score = 0

    if not candidate.get("visible") or not candidate.get("enabled"):
        return -1
    if not candidate.get("interactable"):
        return -1

    expected_role = str(match.get("role") or "").strip().lower()
    if expected_role:
        if role == expected_role:
            score += 90
        elif tag == expected_role:
            score += 45
        else:
            return -1

    expected_tag = str(match.get("tag") or "").strip().lower()
    if expected_tag:
        if tag == expected_tag:
            score += 40
        else:
            return -1

    exact_name = _normalize_match_value(match.get("name") or match.get("text"))
    if exact_name:
        if exact_name in normalized_fields:
            score += 70
        elif exact_name == combined_text:
            score += 60
        elif exact_name in combined_text:
            score += 40
        else:
            return -1

    text_contains = _normalize_match_value(match.get("text_contains"))
    if text_contains:
        if text_contains in combined_text:
            score += 35
        else:
            return -1

    text_starts_with = _normalize_match_value(match.get("text_starts_with"))
    if text_starts_with:
        if any(field.startswith(text_starts_with) for field in normalized_fields):
            score += 45
        else:
            return -1

    attr_map = (
        ("placeholder_contains", candidate.get("placeholder"), 28),
        ("aria_label_contains", candidate.get("aria_label"), 28),
        ("title_contains", candidate.get("title"), 24),
        ("name_contains", candidate.get("name"), 20),
    )
    for match_key, candidate_value, weight in attr_map:
        expected_value = _normalize_match_value(match.get(match_key))
        if not expected_value:
            continue
        actual_value = _normalize_match_value(candidate_value)
        if expected_value in actual_value:
            score += weight
        else:
            return -1

    if candidate.get("clickable"):
        score += 10
    if candidate.get("editable"):
        score += 10
    if candidate.get("interactable"):
        score += 20
    if candidate.get("parent_context") and _normalize_match_value(target.get("description")):
        description = _normalize_match_value(target.get("description"))
        if description and description in _normalize_match_value(candidate.get("parent_context")):
            score += 8

    for fallback in target.get("fallbacks") or []:
        css = _normalize_match_value(fallback.get("css"))
        if css and css == _normalize_match_value(candidate.get("locator_hint")):
            score += 20

    return score + _candidate_specificity_score(candidate)


def select_inventory_candidates(page: Any, target: dict[str, Any]) -> list[dict[str, Any]]:
    inventory = build_candidate_inventory(page)
    ranked: list[dict[str, Any]] = []
    for candidate in inventory.get("candidates") or []:
        score = score_candidate_against_target(candidate, target)
        if score < 0:
            continue
        ranked.append(
            {
                "candidate": candidate,
                "score": score,
            }
        )

    ranked.sort(key=lambda item: item["score"], reverse=True)
    return ranked


def build_recovery_candidate_summary(
    page: Any,
    target: dict[str, Any],
    limit: int = 5,
) -> dict[str, Any]:
    inventory = build_candidate_inventory(page)
    ranked = select_inventory_candidates(page, target)
    top_candidates = [
        compact_candidate(item.get("candidate") or {})
        for item in ranked[:limit]
        if item.get("candidate")
    ]
    llm_summary = build_llm_candidate_summary(
        inventory=inventory,
        target=target,
        ranked=ranked,
        limit=limit,
    )
    return {
        "intent": classify_candidate_intent(target),
        "description": target.get("description"),
        "top_candidates": top_candidates,
        "summary": inventory.get("summary") or {},
        "llm_summary": llm_summary,
    }


def _candidate_specificity_score(candidate: dict[str, Any]) -> int:
    score = 0
    if candidate.get("clickable") or candidate.get("editable"):
        score += 30
    if candidate.get("interactable"):
        score += 20
    if candidate.get("role"):
        score += 20
    if candidate.get("aria_label") or candidate.get("placeholder") or candidate.get("title"):
        score += 15
    text = (candidate.get("text") or "").strip()
    if text:
        score += min(len(text), 20)
    if candidate.get("tag") in {"button", "input", "textarea", "select", "a"}:
        score += 10
    return score


def _candidate_sort_key(candidate: dict[str, Any]) -> tuple[int, int, int]:
    box = candidate.get("bounding_box") or {}
    return (
        int(box.get("y", 0)),
        int(box.get("x", 0)),
        -_candidate_specificity_score(candidate),
    )


def _normalize_match_value(value: Any) -> str:
    if value is None:
        return ""
    return re.sub(r"\s+", " ", str(value)).strip().lower()


def compact_candidate(candidate: dict[str, Any]) -> dict[str, Any]:
    return {
        "candidate_id": candidate.get("candidate_id"),
        "role": candidate.get("role"),
        "tag": candidate.get("tag"),
        "text": candidate.get("text"),
        "aria_label": candidate.get("aria_label"),
        "placeholder": candidate.get("placeholder"),
        "locator_hint": candidate.get("locator_hint"),
        "parent_context": candidate.get("parent_context"),
    }


def build_llm_candidate_summary(
    *,
    inventory: dict[str, Any],
    target: dict[str, Any],
    ranked: list[dict[str, Any]],
    limit: int = 5,
) -> dict[str, Any]:
    candidates = inventory.get("candidates") or []
    relation_groups = inventory.get("relation_groups") or {}
    intent = classify_candidate_intent(target)

    top_matches = [
        {
            **compact_candidate(item.get("candidate") or {}),
            "score": item.get("score"),
        }
        for item in ranked[:limit]
        if item.get("candidate")
    ]

    searchable_inputs = _collect_bucket(
        candidates,
        predicate=lambda candidate: (candidate.get("role") or "") in {"searchbox", "textbox", "combobox"}
        or (candidate.get("tag") or "") in {"input", "textarea", "select"},
        limit=3,
    )
    primary_buttons = _collect_bucket(
        candidates,
        predicate=lambda candidate: bool(candidate.get("clickable"))
        and ((candidate.get("role") or "") in {"button", "link"} or (candidate.get("tag") or "") in {"button", "a"}),
        limit=5,
    )
    dialog_candidates = _collect_bucket(
        candidates,
        predicate=lambda candidate: (candidate.get("role") or "") == "dialog",
        limit=2,
    )
    tab_candidates = _collect_bucket(
        candidates,
        predicate=lambda candidate: (candidate.get("role") or "") == "tab",
        limit=4,
    )

    return {
        "intent": intent,
        "target_description": target.get("description"),
        "top_matches": top_matches,
        "context_buckets": {
            "searchable_inputs": searchable_inputs,
            "primary_buttons": primary_buttons,
            "dialogs": dialog_candidates,
            "tabs": tab_candidates,
        },
        "relation_summary": {
            "combobox_group_count": len(relation_groups.get("combobox_groups") or []),
            "label_input_group_count": len(relation_groups.get("label_input_groups") or []),
            "dialog_group_count": len(relation_groups.get("dialog_groups") or []),
            "tab_group_count": len(relation_groups.get("tab_groups") or []),
        },
    }


def classify_candidate_intent(target: dict[str, Any]) -> str:
    match = target.get("match") or {}
    role = _normalize_match_value(match.get("role"))
    description = _normalize_match_value(target.get("description"))
    if role in {"textbox", "searchbox", "combobox"}:
        return "input_selection"
    if role == "button":
        return "button_selection"
    if role == "tab":
        return "tab_selection"
    if "검색" in description:
        return "search_selection"
    return "generic_target_selection"


def _collect_bucket(
    candidates: list[dict[str, Any]],
    *,
    predicate: Any,
    limit: int,
) -> list[dict[str, Any]]:
    collected = [compact_candidate(candidate) for candidate in candidates if predicate(candidate)]
    return collected[:limit]
