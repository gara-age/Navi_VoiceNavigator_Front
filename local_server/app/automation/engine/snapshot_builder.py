from __future__ import annotations

import re
from typing import Any

from local_server.app.automation.browser.candidate_inventory import build_candidate_inventory
from local_server.app.automation.core.enums import UiState
from local_server.app.automation.core.policies import DEFAULT_POLICY
from local_server.app.automation.core.schemas import ElementSnapshot, PageSnapshot, RegionSnapshot


def build_page_snapshot(page: Any) -> PageSnapshot:
    inventory = build_candidate_inventory(page)
    elements = [_to_element_snapshot(candidate) for candidate in inventory.get("candidates") or []]
    regions = _collect_region_snapshots(page)
    snapshot = PageSnapshot(
        url=getattr(page, "url", "") or "",
        title=_safe_title(page),
        state=UiState.IDLE,
        elements=elements,
        dialogs=[region for region in regions if region.kind == "dialog"],
        panels=[region for region in regions if region.kind == "panel"],
        result_regions=[region for region in regions if region.kind == "result_region"],
        relation_groups=inventory.get("relation_groups") or {},
        summary=inventory.get("summary") or {},
    )
    return snapshot.model_copy(update={"state": detect_ui_state(snapshot)})


def detect_ui_state(snapshot: PageSnapshot) -> UiState:
    corpus = " ".join(
        filter(
            None,
            [
                *(element.text for element in snapshot.elements),
                *(element.name for element in snapshot.elements),
                *(element.placeholder for element in snapshot.elements),
                *(region.name for region in snapshot.dialogs),
                *(region.name for region in snapshot.result_regions),
                *(region.text_preview for region in snapshot.result_regions),
            ],
        )
    ).lower()

    if _looks_like_error_state(snapshot, corpus):
        return UiState.ERROR_VISIBLE

    if snapshot.dialogs:
        return UiState.DIALOG_BLOCKING

    editable_present = any(element.editable for element in snapshot.elements)
    suggestion_present = any(
        element.role in {"option", "listbox"}
        or (element.role == "combobox" and str(element.expanded or "").lower() == "true")
        or element.haspopup
        for element in snapshot.elements
    )
    if editable_present and suggestion_present:
        return UiState.SUGGESTION_OPEN

    if _looks_like_results_ready(snapshot):
        return UiState.RESULTS_READY

    if editable_present:
        return UiState.INPUT_READY

    return UiState.IDLE


def _looks_like_error_state(snapshot: PageSnapshot, corpus: str) -> bool:
    if any(keyword in corpus for keyword in DEFAULT_POLICY.error_keywords):
        return True

    dialog_corpus = " ".join(
        filter(
            None,
            [
                *(region.name for region in snapshot.dialogs),
                *(region.text_preview for region in snapshot.dialogs),
            ],
        )
    ).lower()
    if any(token in dialog_corpus for token in ("error", "failed", "실패", "오류")):
        return True

    return False


def _looks_like_results_ready(snapshot: PageSnapshot) -> bool:
    if not snapshot.result_regions:
        return False

    keywords = DEFAULT_POLICY.result_region_keywords
    for region in snapshot.result_regions:
        corpus = f"{region.name} {region.text_preview}".lower()
        if region.text_preview and len(region.text_preview.strip()) >= 12:
            return True
        if any(keyword in corpus for keyword in keywords):
            return True
    return False


def _safe_title(page: Any) -> str:
    try:
        return page.title()
    except Exception:
        return ""


def _to_element_snapshot(candidate: dict[str, Any]) -> ElementSnapshot:
    accessible_name = (
        candidate.get("aria_label")
        or candidate.get("text")
        or candidate.get("title")
        or candidate.get("placeholder")
        or ""
    )
    landmarks = []
    parent_context = str(candidate.get("parent_context") or "").strip()
    if parent_context:
        landmarks.append(parent_context)
    controls = candidate.get("controls")
    if controls:
        landmarks.append(str(controls))

    return ElementSnapshot(
        id=str(candidate.get("candidate_id") or ""),
        role=str(candidate.get("role") or candidate.get("tag") or "unknown"),
        tag=str(candidate.get("tag") or ""),
        input_type=str(candidate.get("type") or ""),
        name=accessible_name,
        text=str(candidate.get("text") or ""),
        placeholder=str(candidate.get("placeholder") or ""),
        locator_hint=str(candidate.get("locator_hint") or ""),
        html_name=str(candidate.get("name") or ""),
        parent_context=parent_context,
        visible=bool(candidate.get("visible")),
        enabled=bool(candidate.get("enabled")),
        interactable=bool(candidate.get("interactable")),
        clickable=bool(candidate.get("clickable")),
        editable=bool(candidate.get("editable")),
        expanded=candidate.get("expanded"),
        haspopup=candidate.get("haspopup"),
        controls=candidate.get("controls"),
        landmarks=landmarks,
    )


def _collect_region_snapshots(page: Any) -> list[RegionSnapshot]:
    raw_regions = page.evaluate(
        """() => {
            const regionConfigs = [
              { kind: 'dialog', selector: 'dialog,[role="dialog"]' },
              { kind: 'panel', selector: 'aside,[role="complementary"],[role="tabpanel"],section[aria-label],nav[aria-label],[role="region"]' },
              { kind: 'result_region', selector: 'main,[role="main"],section,article,[role="region"],[role="tabpanel"]' }
            ];

            const normalize = (value) => (value || '').replace(/\\s+/g, ' ').trim();
            const visible = (element) => {
              if (!element) return false;
              const rect = element.getBoundingClientRect();
              const style = window.getComputedStyle(element);
              if (element.hidden) return false;
              if (style.display === 'none' || style.visibility === 'hidden') return false;
              if (Number(style.opacity || '1') === 0) return false;
              return rect.width > 0 && rect.height > 0;
            };

            const labelFor = (element) => {
              const labelled = normalize(element.getAttribute('aria-label'));
              if (labelled) return labelled;
              const heading = element.querySelector('h1,h2,h3,h4,[role="heading"]');
              const headingText = normalize(heading ? (heading.innerText || heading.textContent) : '');
              if (headingText) return headingText;
              const id = normalize(element.getAttribute('id'));
              if (id) return id;
              return normalize((element.innerText || element.textContent || '').slice(0, 80));
            };

            const seen = new Set();
            const regions = [];
            let sequence = 1;

            for (const config of regionConfigs) {
              for (const element of document.querySelectorAll(config.selector)) {
                if (seen.has(element) || !visible(element)) {
                  continue;
                }
                seen.add(element);
                const regionId = `region_${String(sequence).padStart(4, '0')}`;
                element.setAttribute('data-vn-region-id', regionId);
                regions.push({
                  id: regionId,
                  kind: config.kind,
                  name: labelFor(element),
                  text_preview: normalize((element.innerText || element.textContent || '').slice(0, 280)),
                  visible: true,
                });
                sequence += 1;
              }
            }
            return regions;
        }"""
    )

    regions: list[RegionSnapshot] = []
    for raw in raw_regions or []:
        name = str(raw.get("name") or "")
        text_preview = _normalize_text(raw.get("text_preview"))
        if not name and not text_preview:
            continue
        regions.append(
            RegionSnapshot(
                id=str(raw.get("id") or ""),
                kind=str(raw.get("kind") or "panel"),
                name=name,
                text_preview=text_preview,
                visible=bool(raw.get("visible", True)),
            )
        )
    return regions


def _normalize_text(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()
