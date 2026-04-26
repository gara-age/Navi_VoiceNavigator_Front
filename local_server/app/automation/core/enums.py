from __future__ import annotations

from enum import Enum


class RiskLevel(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class UiState(str, Enum):
    IDLE = "idle"
    INPUT_READY = "input_ready"
    SUGGESTION_OPEN = "suggestion_open"
    DIALOG_BLOCKING = "dialog_blocking"
    RESULTS_READY = "results_ready"
    ERROR_VISIBLE = "error_visible"


class TaskType(str, Enum):
    KEYWORD_SEARCH = "keyword_search"
    SEARCH_AND_OPEN_RESULT = "search_and_open_result"
    PAIRED_LOOKUP = "paired_lookup"
    FORM_FILL = "form_fill"
    SELECT_FROM_LIST = "select_from_list"
    FILTER_RESULTS = "filter_results"
    AUTHENTICATE = "authenticate"
    DOWNLOAD_RESOURCE = "download_resource"
    READ_RESULT_SUMMARY = "read_result_summary"


class ActionKind(str, Enum):
    OPEN_PRIMARY_ENTRY = "open_primary_entry"
    FILL_SLOT = "fill_slot"
    CHOOSE_SUGGESTION = "choose_suggestion"
    SUBMIT_PRIMARY = "submit_primary"
    SWITCH_TAB = "switch_tab"
    SELECT_LIST_ITEM = "select_list_item"
    DISMISS_DIALOG = "dismiss_dialog"
    READ_RESULTS = "read_results"
    WAIT_FOR_STATE = "wait_for_state"
    RETRY_FOCUS = "retry_focus"


class ExecutionMode(str, Enum):
    NOOP = "noop"
    CANDIDATE_CLICK = "candidate_click"
    CANDIDATE_FILL = "candidate_fill"
    KEYBOARD_PRESS = "keyboard_press"
    READ_REGION = "read_region"
    WAIT_STATE = "wait_state"
