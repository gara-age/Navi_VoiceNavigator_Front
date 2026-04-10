from __future__ import annotations

import os
import subprocess
import time
from dataclasses import replace
from pathlib import Path
from typing import Callable
from urllib.error import URLError
from urllib.request import urlopen

from local_server.app.automation.browser.command_executor import CommandExecutor
from local_server.app.core.config import AppConfig

ProgressCallback = Callable[[dict], None]


class PlaywrightRunner:
    """Execute generic JSON browser plans with Playwright.

    This runner intentionally keeps the implementation web-only. Desktop
    automation for Windows and macOS is handled outside this project scope.
    """

    def __init__(self, config: AppConfig | None = None) -> None:
        self.config = config or AppConfig.from_env()

    def run_agent_plan(
        self,
        plan: dict,
        progress_callback: ProgressCallback | None = None,
        scenario_name: str = "agent_plan",
        success_summary: str | None = None,
    ) -> dict:
        try:
            from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
            from playwright.sync_api import sync_playwright
        except Exception:
            return self._simulation_failure("playwright_not_installed", [], progress_callback)

        config = replace(self.config, browser_headless=False)
        steps: list[dict] = []
        last_step: dict | None = None

        def emit(step: int, action: str, status: str, detail: str, popup_state: str = "processing") -> None:
            nonlocal last_step
            payload = {
                "step": step,
                "action": action,
                "status": status,
                "detail": detail,
                "popup_state": popup_state,
            }
            last_step = {
                "step": step,
                "action": action,
                "status": status,
                "detail": detail,
            }
            if progress_callback is not None:
                progress_callback(payload)

        def record(step: int, action: str, status: str, detail: str, popup_state: str = "success") -> None:
            nonlocal last_step
            step_payload = {
                "step": step,
                "action": action,
                "status": status,
                "detail": detail,
            }
            steps.append(step_payload)
            last_step = step_payload
            emit(step, action, status, detail, popup_state)

        browser = None
        try:
            with sync_playwright() as playwright:
                emit(1, "open_browser_session", "processing", "브라우저 세션을 준비하는 중입니다.")
                browser, page, reused_browser = self._create_browser_session(playwright)
                page.wait_for_timeout(1200)
                record(
                    1,
                    "open_browser_session",
                    "success",
                    "기존 크롬 브라우저 탭을 재사용합니다."
                    if reused_browser
                    else "크롬 브라우저를 실행하고 새 탭을 열었습니다.",
                )

                executor = CommandExecutor()
                execution = executor.execute_plan(
                    page,
                    plan,
                    progress_callback=self._offset_progress_callback(progress_callback, offset=1),
                )
                steps.extend(execution.get("steps", []))

                if execution.get("status") != "success":
                    reason = execution.get("reason", "agent_plan_failed")
                    self._append_failure_step(steps, last_step, reason)
                    return self._simulation_failure(reason, steps, progress_callback)

                observations = execution.get("observations", [])
                summary = success_summary or plan.get("goal", "") or "시나리오를 완료했습니다."

                return {
                    "status": "success",
                    "scenario": scenario_name,
                    "goal": plan.get("goal", ""),
                    "summary": summary,
                    "url": page.url,
                    "title": page.title(),
                    "steps": steps,
                    "observations": observations,
                    "engine": {
                        "browser": "chrome",
                        "headless": config.browser_headless,
                        "automation": "playwright",
                    },
                }
        except PlaywrightTimeoutError as exc:
            self._append_failure_step(steps, last_step, f"timeout:{type(exc).__name__}")
            return self._simulation_failure(f"timeout:{type(exc).__name__}", steps, progress_callback)
        except Exception as exc:
            self._append_failure_step(steps, last_step, f"playwright_error:{type(exc).__name__}: {exc}")
            return self._simulation_failure(
                f"playwright_error:{type(exc).__name__}: {exc}",
                steps,
                progress_callback,
            )
        finally:
            if browser is not None:
                self._safe_close_browser(browser)

    def _create_browser_session(self, playwright):
        endpoint = "http://127.0.0.1:9222"
        reused_browser = self._is_debug_browser_ready(endpoint)

        if not reused_browser:
            chrome_path = self._resolve_chrome_path()
            if chrome_path is None:
                raise RuntimeError("chrome_executable_not_found")

            user_data_dir = self._resolve_debug_profile_dir()
            user_data_dir.mkdir(parents=True, exist_ok=True)
            subprocess.Popen(
                [
                    chrome_path,
                    "--remote-debugging-port=9222",
                    f"--user-data-dir={user_data_dir}",
                    "--new-window",
                    "about:blank",
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                stdin=subprocess.DEVNULL,
                start_new_session=True,
            )
            self._wait_for_debug_browser(endpoint, timeout_ms=12000)

        browser = playwright.chromium.connect_over_cdp(endpoint)
        context = browser.contexts[0] if browser.contexts else browser.new_context()
        page = self._resolve_page_for_simulation(context, reused_browser)
        return browser, page, reused_browser

    def _resolve_page_for_simulation(self, context, reused_browser: bool):
        pages = context.pages
        if reused_browser and pages:
            for page in reversed(pages):
                try:
                    url = (page.url or "").strip().lower()
                    if url.startswith("devtools://"):
                        continue
                    return page
                except Exception:
                    continue
            return pages[-1]

        if pages:
            for page in pages:
                try:
                    url = (page.url or "").strip().lower()
                    if url in ("", "about:blank", "chrome://newtab/"):
                        return page
                except Exception:
                    continue
            return pages[0]

        return context.new_page()

    def _resolve_debug_profile_dir(self) -> Path:
        env_root = os.getenv("VOICE_NAVIGATOR_ROOT")
        if env_root:
            return Path(env_root) / "runtime" / "chrome_debug_profile"
        return Path.cwd() / "runtime" / "chrome_debug_profile"

    def _resolve_chrome_path(self) -> str | None:
        candidates = [
            os.getenv("PROGRAMFILES", "") + r"\Google\Chrome\Application\chrome.exe",
            os.getenv("PROGRAMFILES(X86)", "") + r"\Google\Chrome\Application\chrome.exe",
            os.getenv("LOCALAPPDATA", "") + r"\Google\Chrome\Application\chrome.exe",
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            str(Path.home() / "Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),
        ]
        for candidate in candidates:
            if candidate and Path(candidate).exists():
                return candidate
        return None

    def _is_debug_browser_ready(self, endpoint: str) -> bool:
        try:
            with urlopen(f"{endpoint}/json/version", timeout=1.2) as response:
                return response.status == 200
        except (URLError, TimeoutError, OSError):
            return False

    def _wait_for_debug_browser(self, endpoint: str, timeout_ms: int) -> None:
        deadline = time.time() + (timeout_ms / 1000)
        while time.time() < deadline:
            if self._is_debug_browser_ready(endpoint):
                return
            time.sleep(0.25)
        raise RuntimeError("chrome_debug_endpoint_not_ready")

    def _offset_progress_callback(
        self,
        callback: ProgressCallback | None,
        offset: int,
    ) -> ProgressCallback | None:
        if callback is None:
            return None

        def wrapped(payload: dict) -> None:
            adjusted = dict(payload)
            adjusted["step"] = int(adjusted.get("step", 0)) + offset
            callback(adjusted)

        return wrapped

    def _append_failure_step(self, steps: list[dict], last_step: dict | None, reason: str) -> None:
        if last_step is None:
            return
        failed_step = {
            "step": last_step["step"],
            "action": last_step["action"],
            "status": "error",
            "detail": reason,
        }
        if steps and steps[-1]["step"] == failed_step["step"]:
            steps[-1] = failed_step
            return
        steps.append(failed_step)

    def _simulation_failure(
        self,
        reason: str,
        steps: list[dict],
        progress_callback: ProgressCallback | None,
    ) -> dict:
        if progress_callback is not None:
            progress_callback(
                {
                    "step": len(steps) + 1,
                    "action": "finish",
                    "status": "error",
                    "detail": reason,
                    "popup_state": "error",
                }
            )
        return {
            "status": "error",
            "reason": reason,
            "steps": steps,
            "observations": [],
        }

    def _safe_close_browser(self, browser) -> None:
        try:
            browser.close()
        except Exception:
            pass
