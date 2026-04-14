from __future__ import annotations

import unittest

from local_server.app.automation.core.enums import ActionKind, TaskType, UiState
from local_server.app.automation.core.enums import ExecutionMode
from local_server.app.automation.core.schemas import BoundAction, ElementSnapshot, HostBias, Intent, PageSnapshot, RegionSnapshot, TaskRequest
from local_server.app.automation.engine.binder import PatternBinder
from local_server.app.automation.engine.pattern_executor import PatternExecutor
from local_server.app.automation.engine.planner import PatternPlanner
from local_server.app.automation.engine.snapshot_builder import detect_ui_state
from local_server.app.automation.llm.intent_parser import HeuristicIntentParser


class PatternEngineTests(unittest.TestCase):
    def setUp(self) -> None:
        self.planner = PatternPlanner()
        self.binder = PatternBinder()
        self.executor = PatternExecutor()

    def test_paired_lookup_plan_uses_slot_values(self) -> None:
        intent = Intent(
            task_type=TaskType.PAIRED_LOOKUP,
            slots={"source": "송내역", "target": "서울역"},
            confidence=0.9,
        )

        plan = self.planner.build_plan(intent)

        self.assertEqual(plan[0].kind, ActionKind.OPEN_PRIMARY_ENTRY)
        self.assertEqual(plan[0].label, "route")
        self.assertEqual(plan[1].kind, ActionKind.FILL_SLOT)
        self.assertEqual(plan[1].value, "송내역")
        self.assertEqual(plan[2].kind, ActionKind.CHOOSE_SUGGESTION)
        self.assertEqual(plan[2].value, "송내역")
        self.assertEqual(plan[3].value, "서울역")

    def test_form_fill_expands_fields(self) -> None:
        intent = Intent(
            task_type=TaskType.FORM_FILL,
            slots={"fields": {"email": "a@example.com", "name": "Tester"}, "submit": False},
            confidence=0.9,
        )

        plan = self.planner.build_plan(intent)

        self.assertEqual(len(plan), 2)
        self.assertTrue(all(step.kind == ActionKind.FILL_SLOT for step in plan))
        self.assertEqual(plan[0].slot, "field:email")

    def test_detect_state_prefers_suggestion_open(self) -> None:
        snapshot = PageSnapshot(
            url="https://example.com",
            title="Example",
            state=UiState.IDLE,
            elements=[
                ElementSnapshot(id="1", role="combobox", editable=True, interactable=True),
                ElementSnapshot(id="2", role="option", text="서울역", interactable=True),
            ],
            relation_groups={},
        )

        state = detect_ui_state(snapshot)

        self.assertEqual(state, UiState.SUGGESTION_OPEN)

    def test_detect_state_does_not_treat_issue_report_as_error(self) -> None:
        snapshot = PageSnapshot(
            url="https://example.com",
            title="Example",
            state=UiState.IDLE,
            elements=[
                ElementSnapshot(
                    id="issue",
                    role="button",
                    text="오류신고",
                    interactable=True,
                    clickable=True,
                ),
                ElementSnapshot(
                    id="search",
                    role="combobox",
                    editable=True,
                    interactable=True,
                ),
            ],
            relation_groups={},
        )

        self.assertEqual(detect_ui_state(snapshot), UiState.INPUT_READY)

    def test_binder_selects_source_input(self) -> None:
        snapshot = PageSnapshot(
            url="https://example.com",
            title="Example",
            state=UiState.INPUT_READY,
            elements=[
                ElementSnapshot(
                    id="source",
                    role="combobox",
                    placeholder="출발지 입력",
                    editable=True,
                    interactable=True,
                ),
                ElementSnapshot(
                    id="target",
                    role="combobox",
                    placeholder="도착지 입력",
                    editable=True,
                    interactable=True,
                ),
            ],
            relation_groups={},
        )
        intent = Intent(
            task_type=TaskType.PAIRED_LOOKUP,
            slots={"source": "송내역", "target": "서울역"},
            confidence=0.9,
        )
        plan = self.planner.build_plan(intent)

        bound = self.binder.bind(snapshot, plan[1], HostBias())

        self.assertEqual(bound.selected_candidate.candidate_id, "source")
        self.assertGreaterEqual(bound.confidence, 0.8)

    def test_binder_does_not_skip_route_entry_without_source_target_inputs(self) -> None:
        snapshot = PageSnapshot(
            url="https://map.naver.com",
            title="네이버지도",
            state=UiState.INPUT_READY,
            elements=[
                ElementSnapshot(
                    id="search",
                    role="combobox",
                    placeholder="",
                    controls="home-search-input",
                    editable=True,
                    interactable=True,
                ),
                ElementSnapshot(
                    id="route",
                    role="button",
                    text="길찾기",
                    clickable=True,
                    interactable=True,
                ),
            ],
            relation_groups={},
        )
        intent = Intent(
            task_type=TaskType.PAIRED_LOOKUP,
            slots={"source": "송내역", "target": "서울역"},
            confidence=0.9,
        )
        action = self.planner.build_plan(intent)[0]

        bound = self.binder.bind(snapshot, action, HostBias())

        self.assertEqual(bound.mode.value, "candidate_click")
        self.assertEqual(bound.selected_candidate.candidate_id, "route")

    def test_binder_uses_paired_input_order_when_labels_are_missing(self) -> None:
        snapshot = PageSnapshot(
            url="https://map.naver.com",
            title="네이버지도",
            state=UiState.INPUT_READY,
            elements=[
                ElementSnapshot(
                    id="panel_text",
                    role="div",
                    text="출발지 입력 도착지 입력",
                    interactable=True,
                ),
                ElementSnapshot(
                    id="source_input",
                    role="combobox",
                    editable=True,
                    interactable=True,
                ),
                ElementSnapshot(
                    id="target_input",
                    role="combobox",
                    editable=True,
                    interactable=True,
                ),
            ],
            relation_groups={},
        )
        intent = Intent(
            task_type=TaskType.PAIRED_LOOKUP,
            slots={"source": "송내역", "target": "서울역"},
            confidence=0.9,
        )
        plan = self.planner.build_plan(intent)

        source_bound = self.binder.bind(snapshot, plan[1], HostBias())
        target_bound = self.binder.bind(snapshot, plan[3], HostBias())

        self.assertEqual(source_bound.selected_candidate.candidate_id, "source_input")
        self.assertEqual(target_bound.selected_candidate.candidate_id, "target_input")
        self.assertGreaterEqual(source_bound.confidence, 0.8)
        self.assertGreaterEqual(target_bound.confidence, 0.8)

    def test_binder_falls_back_to_enter_for_submit(self) -> None:
        snapshot = PageSnapshot(
            url="https://example.com",
            title="Example",
            state=UiState.INPUT_READY,
            elements=[
                ElementSnapshot(id="query", role="searchbox", editable=True, interactable=True),
            ],
            relation_groups={},
        )
        intent = Intent(task_type=TaskType.KEYWORD_SEARCH, slots={"query": "테스트"}, confidence=0.8)
        action = self.planner.build_plan(intent)[3]

        bound = self.binder.bind(snapshot, action, HostBias())

        self.assertEqual(bound.keyboard_key, "Enter")
        self.assertEqual(bound.mode.value, "keyboard_press")

    def test_choose_suggestion_uses_cautious_threshold(self) -> None:
        action = self.planner.build_plan(
            Intent(task_type=TaskType.PAIRED_LOOKUP, slots={"source": "송내역", "target": "서울역"}, confidence=0.9)
        )[2]
        bound = BoundAction(
            action=action,
            mode=ExecutionMode.CANDIDATE_CLICK,
            confidence=0.68,
        )

        self.assertTrue(self.executor._is_acceptable(action, bound))

    def test_choose_suggestion_prefers_option_over_listbox(self) -> None:
        snapshot = PageSnapshot(
            url="https://www.youtube.com",
            title="YouTube",
            state=UiState.SUGGESTION_OPEN,
            elements=[
                ElementSnapshot(
                    id="listbox",
                    role="listbox",
                    text="고양이 영상 고양이 영상 물고기",
                    interactable=True,
                ),
                ElementSnapshot(
                    id="option",
                    role="option",
                    text="고양이 영상",
                    interactable=True,
                ),
            ],
            relation_groups={},
        )
        action = self.planner.build_plan(
            Intent(task_type=TaskType.KEYWORD_SEARCH, slots={"query": "고양이 영상"}, confidence=0.9)
        )[2]

        bound = self.binder.bind(snapshot, action, HostBias())

        self.assertEqual(bound.selected_candidate.candidate_id, "option")

    def test_submit_primary_avoids_clear_button(self) -> None:
        snapshot = PageSnapshot(
            url="https://www.youtube.com",
            title="YouTube",
            state=UiState.INPUT_READY,
            elements=[
                ElementSnapshot(
                    id="clear",
                    role="button",
                    text="검색어 삭제",
                    locator_hint="button.ytSearchboxComponentClearButton",
                    interactable=True,
                    clickable=True,
                ),
                ElementSnapshot(
                    id="search",
                    role="button",
                    text="Search",
                    locator_hint="button.ytSearchboxComponentSearchButton",
                    interactable=True,
                    clickable=True,
                ),
            ],
            relation_groups={},
        )
        action = self.planner.build_plan(
            Intent(task_type=TaskType.KEYWORD_SEARCH, slots={"query": "고양이 영상"}, confidence=0.9)
        )[3]

        bound = self.binder.bind(snapshot, action, HostBias())

        self.assertEqual(bound.selected_candidate.candidate_id, "search")

    def test_submit_primary_is_skipped_when_results_page_is_already_visible(self) -> None:
        request = TaskRequest.model_validate(
            {
                "site": "https://www.naver.com",
                "intent": {
                    "task_type": "keyword_search",
                    "slots": {"query": "오늘 날씨"},
                    "risk_level": "low",
                    "confidence": 0.98,
                },
            }
        )
        intent = request.intent
        snapshot = PageSnapshot(
            url="https://search.naver.com/search.naver?query=%EC%98%A4%EB%8A%98+%EB%82%A0%EC%94%A8",
            title="오늘 날씨 : 네이버 검색",
            state=UiState.SUGGESTION_OPEN,
            elements=[],
            result_regions=[
                RegionSnapshot(
                    id="region_1",
                    kind="result_region",
                    name="오늘 날씨 검색 결과",
                    text_preview="오늘 날씨 검색 결과",
                )
            ],
            relation_groups={},
        )

        self.assertTrue(
            self.executor._should_skip_submit(
                request,
                intent,
                snapshot,
                "https://search.naver.com/search.naver?query=%EC%98%A4%EB%8A%98+%EB%82%A0%EC%94%A8",
            )
        )

    def test_intent_parser_extracts_paired_lookup_from_korean_request(self) -> None:
        parser = HeuristicIntentParser()

        intent = parser.parse_user_request("송내역에서 서울역 가는 경로 알려줘")

        self.assertEqual(intent.task_type, TaskType.PAIRED_LOOKUP)
        self.assertEqual(intent.slots["source"], "송내역")
        self.assertEqual(intent.slots["target"], "서울역")

    def test_intent_parser_keeps_full_english_target(self) -> None:
        parser = HeuristicIntentParser()

        intent = parser.parse_user_request("Find a route from Songnae Station to Seoul Station")

        self.assertEqual(intent.task_type, TaskType.PAIRED_LOOKUP)
        self.assertEqual(intent.slots["source"], "Songnae Station")
        self.assertEqual(intent.slots["target"], "Seoul Station")

    def test_results_state_detected_from_region(self) -> None:
        snapshot = PageSnapshot(
            url="https://example.com",
            title="Example",
            state=UiState.IDLE,
            elements=[],
            result_regions=[
                RegionSnapshot(
                    id="region_1",
                    kind="result_region",
                    name="경로 결과",
                    text_preview="서울역까지 52분 급행 1회 환승",
                )
            ],
            relation_groups={},
        )

        self.assertEqual(detect_ui_state(snapshot), UiState.RESULTS_READY)


if __name__ == "__main__":
    unittest.main()
