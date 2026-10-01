#!/usr/bin/env python3
"""Keyboard-only terminal client for the recettas tasks.

Talks to the same Supabase project as the app (same login, same `todos`
table), so tasks added here show up in the app and vice versa. A task's
title is shown and edited exactly as stored: raw markdown, never reformatted.

Windows only (uses msvcrt for key input). No third-party dependencies.

    python scripts/tasks.py
"""
import json
import msvcrt
import os
import shutil
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

SUPABASE_URL = "https://jixjuabvprbyupmaqtma.supabase.co"
# Publishable (anon) key, the same one lib/main.dart ships with the app.
ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp"
    "peGp1YWJ2cHJieXVwbWFxdG1hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2NTE1MDgsImV4"
    "cCI6MjA5NzIyNzUwOH0.RSCK1BMUSA_6M3THDOVnJQzP9RpcPspCL75R7UcBnbk"
)
SESSION_FILE = Path(os.environ.get("APPDATA", Path.home())) / "recettas-tasks" / "session.json"

NEWLINE_GLYPH = "↵"


class ApiError(Exception):
    pass


class AuthError(ApiError):
    """Session is missing/expired and a fresh login is needed."""


# --- Supabase ---------------------------------------------------------------


class Api:
    def __init__(self, session):
        self.session = session

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

    # Same visibility rules as the app: not archived, and completed tasks only
    # until the day they were completed on has passed.
    def todos(self):
        midnight = datetime.now().astimezone().replace(hour=0, minute=0, second=0, microsecond=0)
        cutoff = midnight.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        rows = self._request("GET", "/rest/v1/todos", params={
            "select": "id,title,is_completed",
            "is_archived": "eq.false",
            "or": f"(is_completed.eq.false,completed_at.gte.{cutoff})",
            "order": "is_completed.asc,sort_order.asc,created_at.desc",
        })
        return [{"id": r["id"], "title": r["title"], "done": bool(r["is_completed"])} for r in rows]

    def add(self, title):
        rows = self._request(
            "POST", "/rest/v1/todos", {"user_id": self.session["user_id"], "title": title},
            headers={"Prefer": "return=representation"})
        return rows[0]["id"]

    def _patch(self, todo_id, fields):
        self._request("PATCH", "/rest/v1/todos", fields, params={"id": f"eq.{todo_id}"})

    def set_done(self, todo_id, done):
        completed_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if done else None
        self._patch(todo_id, {"is_completed": done, "completed_at": completed_at})

    def set_title(self, todo_id, title):
        self._patch(todo_id, {"title": title})

    def archive(self, todo_id):  # the app archives rather than deleting
        self._patch(todo_id, {"is_archived": True})


# --- Terminal ---------------------------------------------------------------

ESC = "\x1b"
INVERT, DIM, BOLD, RESET = ESC + "[7m", ESC + "[2m", ESC + "[1m", ESC + "[0m"
RED = ESC + "[31m"

_ARROWS = {"H": "up", "P": "down", "K": "left", "M": "right", "G": "home",
           "O": "end", "S": "del", "I": "pgup", "Q": "pgdn"}


def read_key():
    ch = msvcrt.getwch()
    if ch in ("\x00", "\xe0"):
        return _ARROWS.get(msvcrt.getwch(), "?")
    if ch == "\r":
        return "enter"
    if ch == "\n":
        return "ctrl-j"
    if ch == ESC:
        return "esc"
    if ch in ("\x08", "\x7f"):
        return "bs"
    if ch == "\x03":
        return "ctrl-c"
    if ch == "\x01":
        return "home"
    if ch == "\x05":
        return "end"
    if ch == "\x15":
        return "ctrl-u"
    if ch < " ":
        return "?"
    if "\ud800" <= ch <= "\udbff":  # emoji arrive as two surrogate halves
        ch = (ch + msvcrt.getwch()).encode("utf-16", "surrogatepass").decode("utf-16")
    return ch


def out(s):
    sys.stdout.write(s)
    sys.stdout.flush()


def clip(s, width):
    return s if len(s) <= width else s[: max(width - 1, 0)] + "…"


def one_line(title):
    """Single-line preview of a raw title; the raw text itself is untouched."""
    first, *rest = title.replace("\r", "").replace("\t", "    ").split("\n")
    return first + (f" {NEWLINE_GLYPH}…" if rest else "")


def prompt_line(label, text="", mask=False, hint="Enter confirm · Esc cancel"):
    """Single-row editor on the bottom line. Returns the text, or None on Esc.

    Ctrl+J (or Ctrl+Enter) inserts a real newline, shown as ↵, so multi-line
    markdown titles round-trip untouched.
    """
    pos = len(text)
    while True:
        cols, rows = shutil.get_terminal_size()
        shown = "*" * len(text) if mask else text.replace("\r", "").replace("\n", NEWLINE_GLYPH)
        avail = max(cols - len(label) - 1, 1)
        start = max(0, pos - avail + 1)
        visible = shown[start:start + avail]
        out(f"{ESC}[{rows - 1};1H{ESC}[K{DIM}{clip(hint, cols - 1)}{RESET}"
            f"{ESC}[{rows};1H{ESC}[K{BOLD}{label}{RESET}{visible}"
            f"{ESC}[{rows};{len(label) + pos - start + 1}H{ESC}[?25h")
        k = read_key()
        if k == "enter":
            out(ESC + "[?25l")
            return text
        if k in ("esc", "ctrl-c"):
            out(ESC + "[?25l")
            return None
        if k == "left":
            pos = max(pos - 1, 0)
        elif k == "right":
            pos = min(pos + 1, len(text))
        elif k == "home":
            pos = 0
        elif k == "end":
            pos = len(text)
        elif k == "bs" and pos > 0:
            text, pos = text[:pos - 1] + text[pos:], pos - 1
        elif k == "del":
            text = text[:pos] + text[pos + 1:]
        elif k == "ctrl-u":
            text, pos = "", 0
        elif k == "ctrl-j":
            text, pos = text[:pos] + "\n" + text[pos:], pos + 1
        elif len(k) >= 1 and k not in _ARROWS.values() and k not in ("?", "pgup", "pgdn"):
            text, pos = text[:pos] + k + text[pos:], pos + len(k)


def confirm(question):
    cols, rows = shutil.get_terminal_size()
    out(f"{ESC}[{rows};1H{ESC}[K{BOLD}{clip(question, cols - 1)} (y/N) {RESET}")
    return read_key() in ("y", "Y")


def login_screen(api, notice=""):
    saved_email = api.session.get("email", "")
    while True:
        out(f"{ESC}[2J{ESC}[H{BOLD} recettas tasks — sign in{RESET}\n")
        if notice:
            out(f"\n {RED}{notice}{RESET}\n")
        cols, rows = shutil.get_terminal_size()
        out(f"{ESC}[{rows - 3};1H")  # keep the prompt rows at the bottom
        email = prompt_line("Email: ", saved_email, hint="Enter next · Esc quit")
        if email is None:
            return False
        password = prompt_line("Password: ", mask=True, hint="Enter sign in · Esc back")
        if password is None:
            continue
        out(f"{ESC}[{rows};1H{ESC}[K{DIM}Signing in…{RESET}")
        try:
            api.login(email.strip(), password)
            return True
        except ApiError as e:
            notice, saved_email = str(e), email


class App:
    def __init__(self, api):
        self.api = api
        self.todos = []
        self.sel = 0
        self.top = 0
        self.status = ""

    def reload(self, select_id=None):
        keep = select_id or (self.todos[self.sel]["id"] if self.todos else None)
        self.todos = self.api.todos()
        self.sel = next((i for i, t in enumerate(self.todos) if t["id"] == keep), min(self.sel, max(len(self.todos) - 1, 0)))

    def draw(self):
        cols, rows = shutil.get_terminal_size()
        detail_h = 5
        list_h = max(rows - 4 - detail_h, 1)
        self.sel = max(0, min(self.sel, len(self.todos) - 1))
        if self.sel < self.top:
            self.top = self.sel
        elif self.sel >= self.top + list_h:
            self.top = self.sel - list_h + 1

        open_n = sum(not t["done"] for t in self.todos)
        lines = [f"{BOLD} Tasks{RESET}{DIM}  {open_n} open · {len(self.todos)} shown · {self.api.email}{RESET}",
                 DIM + "─" * cols + RESET]
        if not self.todos:
            lines.append(f"{DIM}  Nothing here. Press a to add a task.{RESET}")
        for i in range(self.top, min(self.top + list_h, len(self.todos))):
            t = self.todos[i]
            row = clip(f" [{'x' if t['done'] else ' '}] {one_line(t['title'])}", cols - 1)
            if i == self.sel:
                lines.append(f"{INVERT}{row.ljust(cols - 1)}{RESET}")
            else:
                lines.append(f"{DIM if t['done'] else ''}{row}{RESET}")
        lines += [""] * (2 + list_h - len(lines))

        # Raw view of the selected task, shown exactly as stored.
        lines.append(DIM + "─" * cols + RESET)
        raw = self.todos[self.sel]["title"].replace("\r", "").replace("\t", "    ").split("\n") if self.todos else []
        for i in range(detail_h):
            if i < len(raw):
                more = i == detail_h - 1 and len(raw) > detail_h
                lines.append(" " + clip(raw[i], cols - 3) + (f" {DIM}(+{len(raw) - detail_h + 1} more lines){RESET}" if more else ""))
            else:
                lines.append("")

        keys = " ↑↓ move · space done · a add · e edit · d archive · r reload · L logout · q quit"
        lines.append(DIM + clip(keys, cols - 1) + RESET)
        lines.append((RED + self.status + RESET) if self.status else "")
        out(f"{ESC}[?25l{ESC}[H" + "".join(l + ESC + "[K\n" for l in lines[:-1]) + lines[-1] + ESC + "[K")

    def run(self):
        self.guard(self.reload, "Loading…")
        while True:
            self.draw()
            k = read_key()
            self.status = ""
            page = max(shutil.get_terminal_size()[1] - 9, 1)
            if k in ("q", "esc", "ctrl-c"):
                return "quit"
            elif k in ("down", "j"):
                self.sel += 1
            elif k in ("up", "k"):
                self.sel -= 1
            elif k in ("home", "g"):
                self.sel = 0
            elif k in ("end", "G"):
                self.sel = len(self.todos) - 1
            elif k == "pgdn":
                self.sel += page
            elif k == "pgup":
                self.sel -= page
            elif k == "r":
                self.guard(self.reload, "Refreshing…")
            elif k == "L":
                self.api.logout()
                return "logout"
            elif k in ("a", "n"):
                self.add()
            elif self.todos and k in (" ", "x"):
                self.toggle()
            elif self.todos and k in ("e", "enter"):
                self.edit()
            elif self.todos and k == "d":
                self.archive()

    def guard(self, fn, busy="", *args):
        """Run a network call, turning failures into a status line."""
        if busy:
            cols, rows = shutil.get_terminal_size()
            out(f"{ESC}[{rows};1H{ESC}[K{DIM}{busy}{RESET}")
        try:
            fn(*args)
            return True
        except AuthError:
            raise
        except ApiError as e:
            self.status = str(e)
            return False

    def add(self):
        title = prompt_line("New task: ", hint="Enter add · Ctrl+J newline · Esc cancel")
        if title is None or not title.strip():
            return
        def go():
            new_id = self.api.add(title)
            self.reload(select_id=new_id)
        self.guard(go, "Adding…")

    def edit(self):
        t = self.todos[self.sel]
        title = prompt_line("Edit: ", t["title"], hint="Enter save · Ctrl+J newline · Esc cancel")
        if title is None or title == t["title"] or not title.strip():
            return
        if self.guard(self.api.set_title, "Saving…", t["id"], title):
            t["title"] = title

    def toggle(self):
        t = self.todos[self.sel]
        if self.guard(self.api.set_done, "Saving…", t["id"], not t["done"]):
            t["done"] = not t["done"]  # stays in place until the next refresh

    def archive(self):
        t = self.todos[self.sel]
        if not confirm(f"Archive “{clip(one_line(t['title']), 40)}”?"):
            return
        if self.guard(self.api.archive, "Archiving…", t["id"]):
            del self.todos[self.sel]


def load_session():
    try:
        return json.loads(SESSION_FILE.read_text())
    except (OSError, ValueError):
        return {}


def main():
    if not sys.stdout.isatty():
        sys.exit("tasks.py needs an interactive terminal.")
    sys.stdout.reconfigure(encoding="utf-8")
    os.system("")  # turns on ANSI escape handling in the Windows console
    api = Api(load_session())
    out(ESC + "[?1049h")  # alternate screen: leaves the shell untouched on exit
    try:
        while True:
            if not api.session.get("refresh_token") and not login_screen(api):
                return
            try:
                if App(api).run() == "quit":
                    return
            except AuthError as e:
                api.logout()
                api.session = {"email": api.session.get("email", "")}
                if not login_screen(api, f"Session expired: {e}"):
                    return
            else:
                api.session = {"email": api.session.get("email", "")}
    finally:
        out(f"{ESC}[?25h{ESC}[?1049l")


if __name__ == "__main__":
    main()
