#!/usr/bin/env python3
"""Keyboard-first terminal client for the recettas tasks.

Talks to the same Supabase project as the app (same login, same `todos`
table), so tasks added here show up in the app and vice versa. A task's
title is shown and edited exactly as stored: raw markdown, never reformatted.

Built on Textual (the Python counterpart of the Ink renderer Claude Code
uses), so it runs in Windows Terminal / PowerShell / CMD and macOS
Terminal / iTerm alike.

Every change is applied on screen immediately and saved in the background,
in order, by a single sync thread. The top-right corner shows what is still
saving; a failed save is rolled back and reported.

    pip install textual
    python scripts/tasks.py          # python3 on macOS
"""
from __future__ import annotations

import json
import os
import queue
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

try:
    from rich.syntax import Syntax
    from rich.text import Text
    from textual import on, work
    from textual.app import App, ComposeResult
    from textual.binding import Binding
    from textual.containers import Horizontal, Vertical, VerticalScroll
    from textual.message import Message
    from textual.screen import ModalScreen, Screen
    from textual.widgets import Footer, Input, Label, OptionList, Static, TextArea
    from textual.widgets.option_list import Option
except ImportError:
    sys.exit("tasks.py needs Textual:  pip install textual")

SUPABASE_URL = "https://jixjuabvprbyupmaqtma.supabase.co"
# Publishable (anon) key, the same one lib/main.dart ships with the app.
ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp"
    "peGp1YWJ2cHJieXVwbWFxdG1hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2NTE1MDgsImV4"
    "cCI6MjA5NzIyNzUwOH0.RSCK1BMUSA_6M3THDOVnJQzP9RpcPspCL75R7UcBnbk"
)


def _config_dir() -> Path:
    if os.name == "nt":
        return Path(os.environ.get("APPDATA", Path.home())) / "recettas-tasks"
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "recettas-tasks"


SESSION_FILE = _config_dir() / "session.json"
SETTINGS_FILE = _config_dir() / "settings.json"

NEWLINE_GLYPH = "↵"
SPINNER = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
THEMES = ["tokyo-night", "catppuccin-mocha", "dracula", "nord", "gruvbox",
          "monokai", "rose-pine", "textual-dark", "catppuccin-latte", "textual-light"]
# Category pills: mid-tones that stay readable with dark text on any theme.
PILL_COLORS = ["#7aa2f7", "#9ece6a", "#e0af68", "#bb9af7", "#7dcfff", "#f7768e", "#73daca", "#ff9e64"]


class ApiError(Exception):
    pass


class AuthError(ApiError):
    """Session is missing/expired and a fresh login is needed."""


# --- Supabase ---------------------------------------------------------------


class Api:
    def __init__(self, session):
        self.session = session
        self._lock = threading.RLock()  # login (UI worker) vs. sync thread

    @property
    def email(self):
        return self.session.get("email", "")

    def _save(self):
        SESSION_FILE.parent.mkdir(parents=True, exist_ok=True)
        SESSION_FILE.write_text(json.dumps(self.session))

    @staticmethod
    def _error_message(e):
        try:
            body = json.loads(e.read())
            return body.get("error_description") or body.get("msg") or body.get("message") or str(e)
        except Exception:
            return str(e)

    def _request(self, method, path, body=None, headers=None, params=None, auth=True, retry=True):
        with self._lock:
            url = SUPABASE_URL + path
            if params:
                url += "?" + urllib.parse.urlencode(params, safe="(),.:")
            if auth and self.session.get("expires_at", 0) - time.time() < 60:
                self.refresh()
            h = {"apikey": ANON_KEY, "Content-Type": "application/json", **(headers or {})}
            if auth:
                h["Authorization"] = "Bearer " + self.session["access_token"]
            data = json.dumps(body).encode() if body is not None else None
            req = urllib.request.Request(url, data=data, method=method, headers=h)
            try:
                with urllib.request.urlopen(req, timeout=15) as r:
                    raw = r.read()
            except urllib.error.HTTPError as e:
                if e.code == 401 and auth and retry:
                    self.refresh()
                    return self._request(method, path, body, headers, params, auth, retry=False)
                raise ApiError(self._error_message(e)) from None
            except (urllib.error.URLError, TimeoutError, OSError) as e:
                raise ApiError(f"offline ({getattr(e, 'reason', e)})") from None
            return json.loads(raw) if raw else None

    def _adopt(self, tokens):
        self.session.update(
            access_token=tokens["access_token"],
            refresh_token=tokens["refresh_token"],
            expires_at=time.time() + tokens.get("expires_in", 3600),
            user_id=tokens["user"]["id"],
        )
        self._save()

    def login(self, email, password):
        tokens = self._request(
            "POST", "/auth/v1/token", {"email": email, "password": password},
            params={"grant_type": "password"}, auth=False)
        self.session["email"] = email
        self._adopt(tokens)

    def refresh(self):
        token = self.session.get("refresh_token")
        if not token:
            raise AuthError("not signed in")
        try:
            tokens = self._request(
                "POST", "/auth/v1/token", {"refresh_token": token},
                params={"grant_type": "refresh_token"}, auth=False)
        except ApiError as e:
            if "offline" in str(e):
                raise
            raise AuthError(str(e)) from None
        self._adopt(tokens)

    def logout(self):
        try:
            SESSION_FILE.unlink()
        except FileNotFoundError:
            pass
        self.session = {"email": self.email}

    # Same visibility rules as the app: not archived, and completed tasks only
    # until the day they were completed on has passed.
    def todos(self):
        midnight = datetime.now().astimezone().replace(hour=0, minute=0, second=0, microsecond=0)
        cutoff = midnight.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        rows = self._request("GET", "/rest/v1/todos", params={
            "select": "id,title,is_completed,sort_order,category_id",
            "is_archived": "eq.false",
            "or": f"(is_completed.eq.false,completed_at.gte.{cutoff})",
            "order": "is_completed.asc,sort_order.asc,created_at.desc",
        })
        return [{"id": r["id"], "title": r["title"], "done": bool(r["is_completed"]),
                 "order": r["sort_order"] or 0, "category": r.get("category_id")} for r in rows]

    def categories(self):
        rows = self._request("GET", "/rest/v1/todo_categories", params={
            "select": "id,name",
            "user_id": f"eq.{self.session['user_id']}",
            "order": "created_at.asc",
        })
        return [{"id": r["id"], "name": r["name"]} for r in rows]

    def set_category(self, todo_id, category_id):
        self._patch(todo_id, {"category_id": category_id})

    def add(self, title):
        rows = self._request(
            "POST", "/rest/v1/todos", {"user_id": self.session["user_id"], "title": title},
            headers={"Prefer": "return=representation"})
        return rows[0]

    def _patch(self, todo_id, fields):
        if todo_id is None:
            raise ApiError("task was never created")
        self._request("PATCH", "/rest/v1/todos", fields, params={"id": f"eq.{todo_id}"})

    def set_done(self, todo_id, done):
        completed_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if done else None
        self._patch(todo_id, {"is_completed": done, "completed_at": completed_at})

    def set_title(self, todo_id, title):
        self._patch(todo_id, {"title": title})

    def set_order(self, todo_id, sort_order):
        self._patch(todo_id, {"sort_order": sort_order})

    def archive(self, todo_id):  # the app archives rather than deleting
        self._patch(todo_id, {"is_archived": True})


# --- Card parsing (mirrors the app's TodoCard.parse) ------------------------


def parse_card(title):
    """Split a stored title into (kind, meta, body_lines). Non-plain cards
    (event/move) keep YAML-style front matter at the top, same as the app's
    TodoCard.parse; plain todos come back as ("todo", {}, all lines)."""
    lines = title.replace("\r", "").replace("\t", "    ").split("\n")
    if lines[0] == "---" and "---" in lines[1:]:
        close = lines.index("---", 1)
        meta = {}
        for line in lines[1:close]:
            key, sep, value = line.partition(":")
            if sep and key.strip():
                meta[key.strip()] = value.strip().strip("\"'")
        kind = meta.pop("type", None)
        if kind in ("event", "move"):
            return kind, meta, lines[close + 1:]
    return "todo", {}, lines


def event_when(meta):
    """"November 2 10:00 - 14:00 (Repeats daily)" from an event's metadata,
    or "" when it has none of date/time/repeat."""
    parts = []
    try:
        d = datetime.strptime(meta.get("date", ""), "%Y-%m-%d")
        parts.append(f"{d.strftime('%B')} {d.day}")
    except ValueError:
        pass
    start, end = meta.get("start"), meta.get("end")
    if start and end:
        parts.append(f"{start} - {end}")
    elif start or end:
        parts.append(start or end)
    text = " ".join(parts)
    if meta.get("repeat") == "daily":
        text = f"{text} (Repeats daily)".strip()
    return text


def one_line(title):
    """Single-line preview of a task; the stored text itself is untouched."""
    kind, meta, body = parse_card(title)
    if kind == "todo":
        first, *rest = body
        return first + (f" {NEWLINE_GLYPH}…" if any(l.strip() for l in rest) else "")
    if kind == "move":
        lines = [f"{meta.get('from') or '?'} → {meta.get('to') or '?'}"] + body
    else:
        lines = [meta.get("title", "")] + body
    lines = [l for l in lines if l.strip()]
    return " — ".join(lines[:2]) + (f" {NEWLINE_GLYPH}…" if len(lines) > 2 else "")


# --- Background sync ---------------------------------------------------------


class Sync:
    """One daemon thread that runs network jobs strictly in submission order,
    so e.g. toggling a task twice quickly always ends in the right state, and
    edits to a just-added task wait for its id."""

    def __init__(self, app: "TasksApp"):
        self.app = app
        self.q: queue.Queue = queue.Queue()
        self.pending = 0  # touched only on the UI thread
        threading.Thread(target=self._loop, daemon=True).start()

    def submit(self, label, fn, on_ok=None, on_err=None, task=None):
        self.pending += 1
        if task is not None:
            task["_busy"] = task.get("_busy", 0) + 1
        self.q.put((label, fn, on_ok, on_err, task))
        self.app.sync_changed(label)

    def drop_queued(self):
        """Throw away jobs that haven't started (after an auth failure)."""
        dropped = 0
        while True:
            try:
                job = self.q.get_nowait()
            except queue.Empty:
                return dropped
            dropped += 1
            self._finish(job)

    def _finish(self, job):
        task = job[4]
        self.pending -= 1
        if task is not None:
            task["_busy"] -= 1
        self.app.sync_changed(None)

    def _ui(self, fn, *args):
        try:
            self.app.call_from_thread(fn, *args)
        except Exception:
            pass  # app is shutting down

    def _loop(self):
        while True:
            job = self.q.get()
            label, fn, on_ok, on_err, task = job
            try:
                result = fn()
            except AuthError as e:
                self._ui(self.app.auth_failed, e)
            except ApiError as e:
                self._ui(self.app.job_failed, label, e, on_err)
            except Exception as e:  # bug, not network: still roll back
                self._ui(self.app.job_failed, label, e, on_err)
            else:
                if on_ok:
                    self._ui(on_ok, result)
            self._ui(self._finish, job)


# --- Widgets & screens -------------------------------------------------------

DIALOG_CSS = """
.dialog {
    width: 80%; max-width: 100; height: auto; max-height: 90%;
    padding: 1 2; border: thick $accent; background: $panel;
}
.dialog .title { text-style: bold; color: $accent; margin-bottom: 1; }
.dialog .hint { color: $text-muted; margin-top: 1; }
.dialog .error { color: $error; margin-bottom: 1; }
"""


class TaskList(OptionList):
    BINDINGS = [
        Binding("space,x", "app.toggle", "Done"),
        Binding("a,n", "app.add", "Add"),
        Binding("enter,e", "app.edit", "Edit"),
        Binding("s,slash", "app.search", "Search"),
        Binding("c", "app.categorize", "Category"),
        Binding("t", "app.move(True)", "Top"),
        Binding("b", "app.move(False)", "Bottom"),
        Binding("d,delete", "app.archive", "Archive"),
        Binding("r", "app.reload", "Reload"),
        Binding("z", "center", "Center", show=False),
        Binding("j", "cursor_down", show=False),
        Binding("k", "cursor_up", show=False),
        Binding("g", "first", show=False),
        Binding("G", "last", show=False),
        Binding("L", "app.logout", "Logout", show=False),
    ]

    def action_center(self) -> None:
        if self.highlighted is not None:
            self.scroll_to(y=max(self.highlighted - self.scrollable_content_region.height // 2, 0), animate=False)


class SearchInput(Input):
    BINDINGS = [
        Binding("escape", "app.cancel_search", "Cancel"),
        Binding("down", "app.list_cursor(1)", "Next", show=False),
        Binding("up", "app.list_cursor(-1)", "Prev", show=False),
    ]


class TitleArea(TextArea):
    """Enter submits; Ctrl+J (or Shift/Ctrl+Enter where the terminal reports
    it) inserts a real newline, so multi-line markdown round-trips."""

    class Submit(Message):
        pass

    async def _on_key(self, event) -> None:
        if event.key == "enter":
            event.stop()
            event.prevent_default()
            self.post_message(self.Submit())
        elif event.key in ("ctrl+j", "shift+enter", "ctrl+enter", "alt+enter"):
            event.stop()
            event.prevent_default()
            self.insert("\n")


class EditScreen(ModalScreen):
    DEFAULT_CSS = "EditScreen { align: center middle; }" + DIALOG_CSS + """
    EditScreen TitleArea { height: auto; min-height: 3; max-height: 20; }
    """
    BINDINGS = [Binding("escape", "cancel", "Cancel")]

    def __init__(self, title: str, text: str = ""):
        super().__init__()
        self.title_text, self.text = title, text

    def compose(self) -> ComposeResult:
        with Vertical(classes="dialog"):
            yield Label(self.title_text, classes="title")
            yield TitleArea(self.text, soft_wrap=True, show_line_numbers=False)
            yield Label("Enter save · Ctrl+J newline · Esc cancel", classes="hint")

    def on_mount(self) -> None:
        area = self.query_one(TitleArea)
        area.focus()
        area.move_cursor(area.document.end)

    @on(TitleArea.Submit)
    def submit(self) -> None:
        self.dismiss(self.query_one(TitleArea).text)

    def action_cancel(self) -> None:
        self.dismiss(None)


class ConfirmScreen(ModalScreen):
    DEFAULT_CSS = "ConfirmScreen { align: center middle; }" + DIALOG_CSS
    BINDINGS = [Binding("y,enter", "answer(True)", "Yes"), Binding("n,escape", "answer(False)", "No")]

    def __init__(self, question: str):
        super().__init__()
        self.question = question

    def compose(self) -> ComposeResult:
        with Vertical(classes="dialog"):
            yield Label(self.question, classes="title")
            yield Label("y / Enter yes · n / Esc no", classes="hint")

    def action_answer(self, yes: bool) -> None:
        self.dismiss(yes)


class PickScreen(ModalScreen):
    DEFAULT_CSS = "PickScreen { align: center middle; }" + DIALOG_CSS + """
    PickScreen OptionList, PickScreen OptionList:focus { height: auto; max-height: 20; border: none; background: $panel; }
    """
    BINDINGS = [Binding("escape,q", "cancel", "Cancel"),
                Binding("j", "move(1)", show=False), Binding("k", "move(-1)", show=False),
                *[Binding(str(i), f"jump({i - 1})", show=False) for i in range(1, 10)]]

    def __init__(self, title: str, options: list, current: int = 0):
        super().__init__()
        self.title_text, self.options, self.current = title, options, current

    def compose(self) -> ComposeResult:
        with Vertical(classes="dialog"):
            yield Label(self.title_text, classes="title")
            yield OptionList(*[Option(Text.assemble((f"{i + 1 if i < 9 else ' '}  ", "dim"), o))
                               for i, o in enumerate(self.options)])
            yield Label("↑/↓ j/k move · Enter choose · 1-9 jump · Esc cancel", classes="hint")

    def on_mount(self) -> None:
        ol = self.query_one(OptionList)
        ol.highlighted = self.current
        ol.focus()

    @on(OptionList.OptionSelected)
    def chosen(self, event: OptionList.OptionSelected) -> None:
        self.dismiss(event.option_index)

    def action_move(self, d: int) -> None:
        ol = self.query_one(OptionList)
        ol.action_cursor_down() if d > 0 else ol.action_cursor_up()

    def action_jump(self, i: int) -> None:
        if i < len(self.options):
            self.dismiss(i)

    def action_cancel(self) -> None:
        self.dismiss(None)


class LoginScreen(Screen):
    DEFAULT_CSS = "LoginScreen { align: center middle; }" + DIALOG_CSS + """
    LoginScreen .dialog { max-width: 60; }
    LoginScreen Input { margin-bottom: 1; }
    LoginScreen #logo { color: $accent; text-style: bold; content-align: center middle; width: 1fr; margin-bottom: 1; }
    """
    BINDINGS = [Binding("escape", "app.quit", "Quit")]

    def __init__(self, api: Api, notice: str = ""):
        super().__init__()
        self.api, self.notice = api, notice

    def compose(self) -> ComposeResult:
        with Vertical(classes="dialog"):
            yield Static("✓ recettas tasks", id="logo")
            yield Label(self.notice, classes="error", id="error")
            yield Input(self.api.email, placeholder="Email", id="email")
            yield Input(placeholder="Password", password=True, id="password")
            yield Label("Enter next / sign in · Esc quit", classes="hint")

    def on_mount(self) -> None:
        self.query_one("#error").display = bool(self.notice)
        self.query_one("#password" if self.api.email else "#email", Input).focus()

    @on(Input.Submitted, "#email")
    def next_field(self) -> None:
        self.query_one("#password", Input).focus()

    @on(Input.Submitted, "#password")
    def sign_in(self) -> None:
        email = self.query_one("#email", Input).value.strip()
        password = self.query_one("#password", Input).value
        if not email or not password:
            return
        self.query_one(".dialog").loading = True
        self._login(email, password)

    @work(thread=True, exclusive=True)
    def _login(self, email: str, password: str) -> None:
        try:
            self.api.login(email, password)
        except ApiError as e:
            self.app.call_from_thread(self._failed, str(e))
        else:
            self.app.call_from_thread(self.dismiss, True)

    def _failed(self, msg: str) -> None:
        self.query_one(".dialog").loading = False
        err = self.query_one("#error", Label)
        err.update(msg)
        err.display = True
        pw = self.query_one("#password", Input)
        pw.value = ""
        pw.focus()


# --- App ---------------------------------------------------------------------


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


class TasksApp(App):
    TITLE = "recettas tasks"
    CSS = """
    Screen { background: $background; }
    #topbar { dock: top; height: 1; background: $boost; }
    #brand { width: auto; padding: 0 1; background: $accent; color: $text; text-style: bold; }
    #counts { width: 1fr; padding: 0 1; color: $text-muted; }
    #sync { width: auto; padding: 0 1; }
    #main { height: 1fr; }
    TaskList {
        width: 3fr; height: 1fr; border: round $primary-darken-2; background: $surface;
        border-title-color: $text-muted; padding: 0;
        text-wrap: nowrap; text-overflow: ellipsis;
    }
    TaskList:focus { border: round $accent; border-title-color: $accent; }
    TaskList > .option-list--option-highlighted { background: $accent 25%; }
    TaskList:focus > .option-list--option-highlighted { background: $accent 40%; }
    #detail {
        width: 2fr; height: 1fr; border: round $primary-darken-2; background: $surface;
        padding: 0 1; border-title-color: $text-muted;
    }
    #detail-head { margin-bottom: 1; }
    #main.narrow { layout: vertical; }
    #main.narrow TaskList { width: 1fr; }
    #main.narrow #detail { width: 1fr; height: 40%; }
    #search { dock: bottom; display: none; height: 3; border: round $accent; }
    #search.on { display: block; }
    """
    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("T", "cycle_theme", "Theme"),
        Binding("ctrl+c", "quit", show=False, priority=True),
    ]

    def __init__(self):
        super().__init__()
        self.api = Api(load_json(SESSION_FILE))
        self.settings = load_json(SETTINGS_FILE)
        self.todos: list[dict] = []
        self.cats: list[dict] = []
        self.shown: list[dict] = []  # what the list displays (filtered while searching)
        self.query_text: str | None = None  # None = not searching
        self.search_origin = None
        self.sync = Sync(self)
        self.reload_wanted = False
        self.last_sync: str | None = None
        self.last_error: str | None = None
        self.sync_label = ""
        self.frame = 0
        self.quit_armed = 0.0

    # ---- layout ----

    def compose(self) -> ComposeResult:
        with Horizontal(id="topbar"):
            yield Static("✓ tasks", id="brand")
            yield Static(id="counts")
            yield Static(id="sync")
        with Horizontal(id="main"):
            yield TaskList(id="list")
            with VerticalScroll(id="detail"):
                yield Static(id="detail-head")
                yield Static(id="detail-body")
        yield SearchInput(placeholder="Search tasks and categories…", id="search")
        yield Footer()

    def on_mount(self) -> None:
        theme = self.settings.get("theme", "tokyo-night")
        self.theme = theme if theme in self.available_themes else "tokyo-night"
        self.ui("#list").border_title = "Tasks"
        self.ui("#detail").border_title = "Details"
        self.set_interval(0.08, self._spin)
        self.set_interval(60, self.auto_reload)
        if self.api.session.get("refresh_token"):
            self.start()
        else:
            self.push_screen(LoginScreen(self.api), self._after_login)

    def on_resize(self, event) -> None:
        self.ui("#main").set_class(event.size.width < 100, "narrow")

    def watch_theme(self, theme: str) -> None:
        self.settings["theme"] = theme
        try:
            SETTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
            SETTINGS_FILE.write_text(json.dumps(self.settings))
        except OSError:
            pass
        if self.screen_stack and self.screen_stack[0].query(TaskList):
            self.rebuild()

    def ui(self, selector, expect=None):
        """query_one on the main screen, even while a dialog is on top."""
        main = self.screen_stack[0]
        return main.query_one(selector, expect) if expect else main.query_one(selector)

    def action_cycle_theme(self) -> None:
        names = [t for t in THEMES if t in self.available_themes]
        i = names.index(self.theme) if self.theme in names else -1
        self.theme = names[(i + 1) % len(names)]
        self.notify(f"Theme: {self.theme}  (Ctrl+P → Change theme for all)", timeout=2)

    def color(self, name: str, fallback: str) -> str:
        return getattr(self.current_theme, name, None) or fallback

    # ---- session ----

    def _after_login(self, ok) -> None:
        if ok:
            self.start()

    def start(self) -> None:
        self.ui("#list").loading = not self.todos
        self.ui("#list").focus()
        self.reload()

    def auth_failed(self, e) -> None:
        dropped = self.sync.drop_queued()
        self.api.logout()
        self.todos, self.cats = [], []
        self.rebuild()
        if not isinstance(self.screen, LoginScreen):
            note = f"Session expired: {e}" + (f" ({dropped} unsaved change(s) discarded)" if dropped else "")
            self.push_screen(LoginScreen(self.api, note), self._after_login)

    def action_logout(self) -> None:
        self.sync.drop_queued()
        self.api.logout()
        self.todos, self.cats = [], []
        self.rebuild()
        self.push_screen(LoginScreen(self.api), self._after_login)

    def action_quit(self) -> None:
        if self.sync.pending and time.monotonic() - self.quit_armed > 3:
            self.quit_armed = time.monotonic()
            self.notify(f"{self.sync.pending} change(s) still saving. Press q again to quit anyway.",
                        severity="warning", timeout=3)
            return
        self.exit()

    # ---- sync status ----

    def sync_changed(self, label) -> None:
        if label:
            self.sync_label = label
        if self.sync.pending == 0 and self.reload_wanted:
            self.reload_wanted = False
            self.reload(quiet=True)
        self._render_sync()
        self.refresh_rows()

    def job_failed(self, label, e, on_err) -> None:
        self.last_error = str(e)
        if on_err:
            on_err()
        self.notify(f"{label.rstrip('…')} failed: {e}", severity="error", timeout=6)

    def _spin(self) -> None:
        if self.sync.pending:
            self.frame = (self.frame + 1) % len(SPINNER)
            self._render_sync()

    def _render_sync(self) -> None:
        t = Text()
        if self.sync.pending:
            t.append(SPINNER[self.frame] + " ", style=self.color("warning", "yellow"))
            t.append(self.sync_label or "Saving…")
            if self.sync.pending > 1:
                t.append(f" +{self.sync.pending - 1}", style="dim")
        elif self.last_error:
            t.append("⚠ ", style=self.color("error", "red")).append(self.last_error[:40], style="dim")
        elif self.last_sync:
            t.append("● ", style=self.color("success", "green")).append(f"synced {self.last_sync}", style="dim")
        self.ui("#sync", Static).update(t)

    # ---- data ----

    def reload(self, quiet=False) -> None:
        def fetch():
            return self.api.todos(), self.api.categories()
        self.sync.submit("Syncing…" if quiet else "Loading…", fetch, on_ok=self._loaded,
                         on_err=lambda: setattr(self.ui("#list"), "loading", False))

    def action_reload(self) -> None:
        self.reload()

    def auto_reload(self) -> None:
        if (self.api.session.get("refresh_token") and not self.sync.pending
                and len(self.screen_stack) == 1 and self.query_text is None):
            self.reload(quiet=True)

    def _loaded(self, result) -> None:
        self.ui("#list").loading = False
        if self.query_text is None and len(self.screen_stack) == 1:
            self.ui(TaskList).focus()
        if self.sync.pending > 1:  # more local changes queued after this fetch
            self.reload_wanted = True
            return
        keep = self.current()
        self.todos, self.cats = result
        self.last_sync, self.last_error = datetime.now().strftime("%H:%M"), None
        ids = [t["id"] for t in self.todos]
        self.rebuild(select=ids.index(keep["id"]) if keep and keep["id"] in ids else None)

    def current(self) -> dict | None:
        ol = self.ui(TaskList)
        if ol.highlighted is None or ol.highlighted >= len(self.shown):
            return None
        return self.shown[ol.highlighted]

    def cat_name(self, t) -> str | None:
        return next((c["name"] for c in self.cats if c["id"] == t.get("category")), None)

    def cat_color(self, cid) -> str:
        idx = next((i for i, c in enumerate(self.cats) if c["id"] == cid), 0)
        return PILL_COLORS[idx % len(PILL_COLORS)]

    # ---- rendering ----

    def row(self, t: dict) -> Text:
        kind, meta, _ = parse_card(t["title"])
        accent = self.color("accent", "cyan")
        if t.get("_busy"):
            mark = Text("◌ ", style=self.color("warning", "yellow"))
        elif t["done"]:
            mark = Text("✓ ", style=f"bold {self.color('success', 'green')}")
        else:
            mark = Text("○ ", style=accent)
        text = Text(" ", no_wrap=True, overflow="ellipsis") + mark
        if kind == "event":
            when = " ".join(x for x in (meta.get("start"), meta.get("date") and meta["date"][5:]) if x)
            text.append("◷ " + (when + " " if when else ""), style=self.color("warning", "yellow"))
        elif kind == "move":
            text.append("⇢ ", style=self.color("secondary", "magenta"))
        title = Text(one_line(t["title"]), style="dim strike" if t["done"] else "")
        if self.query_text:
            title.highlight_words([self.query_text], style=f"bold reverse {accent}", case_sensitive=False)
        text.append_text(title)
        name = self.cat_name(t)
        if name:
            text.append("  ")
            text.append(f" {name} ", style=f"#1a1b26 on {self.cat_color(t['category'])}")
        return text

    def rebuild(self, select: int | None = None) -> None:
        """Re-render the whole list. `select` is an index into self.todos."""
        ol = self.ui(TaskList)
        prev = self.current()
        q = (self.query_text or "").strip().lower()
        self.shown = [t for t in self.todos
                      if not q or q in t["title"].lower() or q in (self.cat_name(t) or "").lower()]
        target = self.todos[select] if select is not None and select < len(self.todos) else prev
        old = ol.highlighted
        ol.clear_options()
        ol.add_options([Option(self.row(t)) for t in self.shown])
        if self.shown:
            idx = next((i for i, t in enumerate(self.shown) if t is target), None)
            ol.highlighted = idx if idx is not None else min(old or 0, len(self.shown) - 1)
        self.render_counts()
        self.render_detail()

    def refresh_rows(self) -> None:
        """Cheap repaint of each row's prompt without rebuilding the list."""
        ol = self.ui(TaskList)
        if ol.option_count != len(self.shown):
            return self.rebuild()
        for i, t in enumerate(self.shown):
            ol.replace_option_prompt_at_index(i, self.row(t))
        self.render_counts()
        self.render_detail()

    def render_counts(self) -> None:
        open_n = sum(not t["done"] for t in self.todos)
        done_n = len(self.todos) - open_n
        t = Text()
        t.append(f"{open_n} open", style="bold")
        t.append(f" · {done_n} done today", style="dim")
        if self.query_text is not None:
            t.append(f" · {len(self.shown)} match", style=self.color("accent", "cyan"))
        if self.api.email:
            t.append(f" · {self.api.email}", style="dim")
        self.ui("#counts", Static).update(t)
        self.ui(TaskList).border_subtitle = f"{len(self.shown)}"

    @on(OptionList.OptionHighlighted, "#list")
    def render_detail(self, _=None) -> None:
        head = self.ui("#detail-head", Static)
        body = self.ui("#detail-body", Static)
        t = self.current()
        if not t:
            msg = "Nothing here. Press a to add a task." if not self.todos else "No task matches."
            head.update(Text(msg, style="dim"))
            body.update("")
            return
        kind, meta, lines = parse_card(t["title"])
        h = Text()
        if t["done"]:
            h.append(" ✓ Done ", style=f"bold #1a1b26 on {self.color('success', 'green')}")
        else:
            h.append(" ○ Open ", style=f"bold #1a1b26 on {self.color('accent', 'cyan')}")
        if kind != "todo":
            h.append(" ")
            h.append(f" {kind} ", style=f"bold #1a1b26 on {self.color('warning', 'yellow')}")
        name = self.cat_name(t)
        if name:
            h.append(" ")
            h.append(f" {name} ", style=f"#1a1b26 on {self.cat_color(t['category'])}")
        if t.get("_busy"):
            h.append("  ◌ saving…", style=self.color("warning", "yellow"))
        if kind == "event":
            if meta.get("title"):
                h.append("\n\n").append(meta["title"], style="bold")
            when = event_when(meta)
            if when:
                h.append("\n").append("◷ " + when, style=self.color("warning", "yellow"))
        elif kind == "move":
            h.append("\n\n").append(f"{meta.get('from') or '?'} → {meta.get('to') or '?'}", style="bold")
        head.update(h)
        raw = "\n".join(lines).strip("\n")
        body.update(Syntax(raw, "markdown", theme="monokai" if self.current_theme.dark else "friendly",
                           word_wrap=True,
                           background_color=self.color("surface", "default")) if raw else "")

    # ---- actions (optimistic: change locally, save in the background) ----

    def action_list_cursor(self, d: int) -> None:
        ol = self.ui(TaskList)
        ol.action_cursor_down() if d > 0 else ol.action_cursor_up()

    def action_toggle(self) -> None:
        t = self.current()
        if not t:
            return
        new = not t["done"]
        t["done"] = new  # stays in place until the next refresh

        def undo():
            t["done"] = not new
            self.refresh_rows()
        self.sync.submit("Completing…" if new else "Reopening…",
                         lambda: self.api.set_done(t["id"], new), on_err=undo, task=t)

    def action_add(self) -> None:
        def done(title):
            if title is None or not title.strip():
                return
            orders = [x["order"] for x in self.todos] or [0]
            t = {"id": None, "title": title, "done": False, "order": min(orders) - 1, "category": None}
            self.todos.insert(0, t)
            self.rebuild(select=0)

            def go():
                row = self.api.add(title)
                t["id"] = row["id"]  # set here so queued edits of this task can use it

            def undo():
                if t in self.todos:
                    self.todos.remove(t)
                    self.rebuild()
            self.sync.submit("Adding…", go, on_err=undo, task=t)
            self.reload_wanted = True  # pick up the server's ordering once idle
        self.push_screen(EditScreen("New task"), done)

    def action_edit(self) -> None:
        t = self.current()
        if not t:
            return
        old = t["title"]

        def done(title):
            if title is None or title == old or not title.strip():
                return
            t["title"] = title
            self.refresh_rows()

            def undo():
                if t["title"] == title:
                    t["title"] = old
                    self.refresh_rows()
            self.sync.submit("Saving…", lambda: self.api.set_title(t["id"], title), on_err=undo, task=t)
        self.push_screen(EditScreen("Edit task", old), done)

    def action_move(self, top: bool) -> None:
        """Send the task to the top/bottom of the list. The cursor stays on the
        same row, so it ends up on the task that was right below it."""
        t = self.current()
        if not t or self.query_text is not None:
            return
        i = self.todos.index(t)
        if i == (0 if top else len(self.todos) - 1):
            return
        orders = [x["order"] for x in self.todos]
        old_order, new = t["order"], (min(orders) - 1 if top else max(orders) + 1)
        t["order"] = new
        self.todos.remove(t)
        self.todos.insert(0 if top else len(self.todos), t)
        follow = self.todos[min(i + 1, len(self.todos) - 1)] if top else self.todos[i]
        self.rebuild(select=self.todos.index(follow))

        def undo():
            t["order"] = old_order
            if t in self.todos:
                self.todos.remove(t)
                self.todos.insert(min(i, len(self.todos)), t)
                self.rebuild()
        self.sync.submit("Moving…", lambda: self.api.set_order(t["id"], new), on_err=undo, task=t)

    def action_archive(self) -> None:
        t = self.current()
        if not t:
            return

        def done(yes):
            if not yes or t not in self.todos:
                return
            i = self.todos.index(t)
            self.todos.remove(t)
            self.rebuild(select=min(i, len(self.todos) - 1) if self.todos else None)

            def undo():
                self.todos.insert(min(i, len(self.todos)), t)
                self.rebuild()
            self.sync.submit("Archiving…", lambda: self.api.archive(t["id"]), on_err=undo)
        self.push_screen(ConfirmScreen(f"Archive “{one_line(t['title'])[:60]}”?"), done)

    def action_categorize(self) -> None:
        t = self.current()
        if not t:
            return
        if not self.cats:
            self.notify("No categories yet. Create one in the app.", severity="warning")
            return
        names = ["(none)"] + [c["name"] for c in self.cats]
        current = next((i + 1 for i, c in enumerate(self.cats) if c["id"] == t.get("category")), 0)

        def done(idx):
            if idx is None:
                return
            new = self.cats[idx - 1]["id"] if idx else None
            old = t.get("category")
            if new == old:
                return
            t["category"] = new
            self.refresh_rows()

            def undo():
                t["category"] = old
                self.refresh_rows()
            self.sync.submit("Saving category…", lambda: self.api.set_category(t["id"], new), on_err=undo, task=t)
        self.push_screen(PickScreen(f"Category for: {one_line(t['title'])[:60]}", names, current), done)

    # ---- search ----

    def action_search(self) -> None:
        self.search_origin = self.current()
        self.query_text = ""
        s = self.ui("#search", SearchInput)
        s.value = ""
        s.add_class("on")
        s.focus()
        self.rebuild()

    @on(Input.Changed, "#search")
    def search_changed(self, event: Input.Changed) -> None:
        if self.query_text is None:
            return
        self.query_text = event.value
        self.rebuild()
        if self.shown:
            self.ui(TaskList).highlighted = 0

    @on(Input.Submitted, "#search")
    def search_submitted(self) -> None:
        target = self.current() if (self.query_text or "").strip() else self.search_origin
        if (self.query_text or "").strip() and not self.shown:
            self.notify(f"No task matches “{self.query_text.strip()}”", severity="warning")
            target = self.search_origin
        self._end_search(target, center=True)

    def action_cancel_search(self) -> None:
        self._end_search(self.search_origin)

    def _end_search(self, target, center=False) -> None:
        self.query_text = None
        s = self.ui("#search", SearchInput)
        s.remove_class("on")
        ol = self.ui(TaskList)
        ol.focus()
        self.rebuild(select=self.todos.index(target) if target in self.todos else None)
        if center:
            self.call_after_refresh(ol.action_center)


def main():
    if not sys.stdout.isatty():
        sys.exit("tasks.py needs an interactive terminal.")
    TasksApp().run()


if __name__ == "__main__":
    main()
