"""Local assistant for voice notes: one call to a small local LLM decides
whether a transcript asks for an action, and the worker carries it out.

The model runs on the PC through C:\\dev\\locallama (llama.cpp, OpenAI-style
API, see locallm.py there). Tools:

    add_expenses        -> purchases (Gastos), same rules as expenses_prompt.md
    add_shopping_items  -> shopping_items (Compras)
    add_todos           -> todos (Afazeres)
    create_event        -> todos as an event card (type: event, date, start)
    log_sleep           -> sleep_events (Sono)

Every call carries the model's own confidence. An action runs at once when
that is >= AGENT_MIN_CONFIDENCE *and* it passes the checks below (amounts
> 0, dates that parse and aren't in the past, sane sleep times...);
otherwise it is saved as 'pending' for the app to confirm. Each executed
action remembers the rows it created, so the app can undo it.

Dry run, no database:

    .venv\\Scripts\\python.exe agent.py "comprei pão por 8 reais e preciso comprar leite"
    .venv\\Scripts\\python.exe agent.py --lang en --at 2026-11-17T07:30 "I just woke up"
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time
import uuid
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

SCRIPT_DIR = Path(__file__).resolve().parent
load_dotenv(SCRIPT_DIR / ".env")

LOCALLAMA_DIR = os.environ.get("LOCALLAMA_DIR") or r"C:\dev\locallama"
sys.path.insert(0, LOCALLAMA_DIR)
from locallm import LocalLLM, LocalLLMError, tool  # noqa: E402

AGENT_MODEL = os.environ.get("AGENT_MODEL") or "qwen3.5-9b"
AGENT_MIN_CONFIDENCE = float(os.environ.get("AGENT_MIN_CONFIDENCE") or 0.75)
# "", "low", "medium", "high": thinking is slower but better at date math.
AGENT_THINK = os.environ.get("AGENT_THINK") or ""

EXPENSES_RULES = (SCRIPT_DIR / "expenses_prompt.md").read_text(encoding="utf-8")

WEEKDAYS = {
    "pt": ["segunda-feira", "terça-feira", "quarta-feira", "quinta-feira",
           "sexta-feira", "sábado", "domingo"],
    "en": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
}
HHMM = re.compile(r"^([01]?\d|2[0-3]):([0-5]\d)$")
# A clock time said without a date is the latest one at or before the
# recording, unless it is at most this far ahead ("vou dormir às 23h").
LOOKAHEAD = timedelta(hours=3)
MAX_SLEEP = timedelta(hours=16)

DAY_WORDS = (
    "Say the day as the user did, in English words, and let the app compute it: "
    "'today', 'tomorrow', 'day after tomorrow', 'yesterday', a weekday ('friday'), "
    "'+3' (in 3 days), a day of the month ('25'), or YYYY-MM-DD if a full date was said."
)

CONFIDENCE = {
    "type": "number",
    "description": "0 to 1: how sure you are that the user asked for exactly this. "
                   "1 = explicit request with every detail clear; 0.5 = guessing.",
}


def build_tools(categories: list[str]) -> list[dict]:
    expense_item: dict[str, Any] = {
        "type": "object",
        "properties": {
            "item": {"type": "string"},
            "valor": {"type": "number", "description": "Total paid for the line, in BRL"},
            "local": {"type": "string", "description": "Store/place; omit if not said"},
            "data": {"type": "string", "description": "Only if a day other than the "
                                                      "recording day was said. " + DAY_WORDS},
            "categoria": {"type": "string", "description": "One of the user's categories, "
                                                           "exactly; omit if none fits"},
        },
        "required": ["item", "valor"],
    }
    if categories:
        expense_item["properties"]["categoria"]["enum"] = categories
    return [
        tool("add_expenses",
             "Record money the user ALREADY SPENT (Gastos). Only purchases with a price.",
             {"items": {"type": "array", "items": expense_item}, "confidence": CONFIDENCE}),
        tool("add_shopping_items",
             "Add things the user still NEEDS TO BUY to the shopping list (Compras).",
             {"items": {"type": "array", "items": {"type": "string"},
                        "description": "Short product names, capitalized, with quantity "
                                       "if said: 'Leite', 'Ovos (2 dúzias)'"},
              "confidence": CONFIDENCE}),
        tool("add_todos",
             "Add tasks to the to-do list (Afazeres): things to do or to be reminded of "
             "with NO specific date/time.",
             {"items": {"type": "array", "items": {"type": "string"},
                        "description": "Each a short self-contained task, starting with a verb"},
              "confidence": CONFIDENCE}),
        tool("create_event",
             "Create a reminder/event on a SPECIFIC day (and optionally time).",
             {"title": {"type": "string"},
              "date": {"type": "string", "description": DAY_WORDS},
              "start": {"type": "string",
                        "description": "HH:MM 24h if any time was said, else empty string"},
              "end": {"type": "string", "description": "HH:MM 24h if an end time was said"},
              "confidence": CONFIDENCE},
             required=["title", "date", "start", "confidence"]),
        tool("log_sleep",
             "Log sleep (Sono): going to sleep, waking up, or a nap/period slept.",
             {"sleep_at": {"type": "string", "description": "'now' if going to sleep now, "
                                                            "or HH:MM when they fell asleep"},
              "wake_at": {"type": "string", "description": "'now' if they just woke up, "
                                                           "or HH:MM when they woke up"},
              "duration_minutes": {"type": "integer",
                                   "description": "Minutes slept, if said ('dormi 40 minutos')"},
              "confidence": CONFIDENCE},
             required=["confidence"]),
    ]


def system_prompt(recorded: datetime, language: str, categories: list[str]) -> str:
    wd = WEEKDAYS["en"]
    lang_name = "Brazilian Portuguese" if language == "pt" else "English"
    return f"""You turn the user's voice note (a WhisperX transcript in {lang_name}, possibly \
with transcription errors) into actions on their personal app, using the tools.

Recorded at: {recorded:%Y-%m-%d %H:%M} ({wd[recorded.weekday()]}). Treat this as "now".
Dates: never compute a calendar date yourself. Write the day the way the user said it, \
in English words: "amanhã" -> "tomorrow", "sexta" -> "friday", "dia 25" -> "25", \
"daqui a 3 dias" -> "+3", "ontem" -> "yesterday". The app works out the real date (the \
next one for events, the last one for expenses).

User's expense categories: {', '.join(categories) or '(none)'}

How to decide:
- Call a tool only when the user states something to record or asks for something to \
be done. A note that is just thinking aloud, a diary entry, a question or an idea gets \
NO tool call: answer with one short sentence instead.
- One note can need several tools (e.g. "comprei pão por 8 reais e preciso comprar leite" \
-> add_expenses + add_shopping_items). Put every item for the same tool in ONE call.
- Bought already, with a price -> add_expenses. Still has to buy -> add_shopping_items.
- "Me lembra de X" / "remind me to X" with a day or time -> create_event; without -> add_todos.
- "Vou dormir", "acordei", "dormi 40 minutos", "dormi das 23h às 7h" -> log_sleep.
- Write every item, task and title in {lang_name} (the language the user spoke), \
fixing obvious transcription errors. Do not translate.
- Times are 24h HH:MM: "3 da tarde" = 15:00, "9 da noite" = 21:00, "meio-dia" = 12:00, \
"9pm" = 21:00, "11 e meia" = 11:30 (or 23:30 if it is night). If a time was said, \
ALWAYS fill it in.
- Be honest in confidence: lower it when the transcript is garbled, the intent is \
unclear, or you had to guess a value, date or category.

Rules for add_expenses (from the user's existing spreadsheet prompt; 'data' only when \
another day was said, written as day words like above instead of AAAA-MM-DD; never \
invent 'local'):
{EXPENSES_RULES}
"""


# --- Planning (model call + checks; no database) ---


@dataclass
class Plan:
    actions: list[dict]
    reply: str


def _clock(value: str | None, ref: datetime) -> datetime | None:
    if not value:
        return None
    value = value.strip().lower()
    if value in ("now", "agora"):
        return ref
    m = HHMM.match(value)
    if not m:
        return None
    at = ref.replace(hour=int(m[1]), minute=int(m[2]), second=0, microsecond=0)
    return at - timedelta(days=1) if at > ref + LOOKAHEAD else at


WEEKDAY_WORDS = {
    "monday": 0, "segunda": 0, "tuesday": 1, "terça": 1, "terca": 1, "wednesday": 2,
    "quarta": 2, "thursday": 3, "quinta": 3, "friday": 4, "sexta": 4, "saturday": 5,
    "sábado": 5, "sabado": 5, "sunday": 6, "domingo": 6,
}
RELATIVE_DAYS = {
    "today": 0, "hoje": 0, "tomorrow": 1, "amanhã": 1, "amanha": 1,
    "day after tomorrow": 2, "depois de amanhã": 2, "depois de amanha": 2,
    "yesterday": -1, "ontem": -1, "day before yesterday": -2, "anteontem": -2,
}


def resolve_day(value: Any, ref: date, future: bool) -> date | None:
    """Day words from the model -> a date. future=True picks the next
    occurrence (events), False the last one (expenses)."""
    text = str(value or "").strip().lower()
    if not text:
        return None
    try:
        return date.fromisoformat(text)
    except ValueError:
        pass
    text = re.sub(r"^(next|this|on|last|the|próxima|proxima|próximo|proximo|dia)\s+", "", text)
    text = text.replace("-feira", "").replace(" que vem", "").replace(" passada", "").strip()
    if text in RELATIVE_DAYS:
        return ref + timedelta(days=RELATIVE_DAYS[text])
    if re.fullmatch(r"[+-]\d{1,3}", text):
        return ref + timedelta(days=int(text))
    if text in WEEKDAY_WORDS:
        delta = (WEEKDAY_WORDS[text] - ref.weekday()) % 7
        return ref + timedelta(days=delta) if future else ref - timedelta(days=(7 - delta) % 7)
    m = re.fullmatch(r"(\d{1,2})(?:st|nd|rd|th)?", text)
    if m and 1 <= int(m[1]) <= 31:
        day, y, mo = int(m[1]), ref.year, ref.month
        for _ in range(3):
            try:
                cand = date(y, mo, day)
            except ValueError:
                cand = None
            if cand and (cand >= ref if future else cand <= ref):
                return cand
            mo += 1 if future else -1
            if mo == 13:
                y, mo = y + 1, 1
            elif mo == 0:
                y, mo = y - 1, 12
    return None


def _brl(v: float) -> str:
    return f"R$ {v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def _list_summary(items: list[str], limit: int = 4) -> str:
    shown = ", ".join(items[:limit])
    return shown + (f" +{len(items) - limit}" if len(items) > limit else "")


def check(name: str, args: dict, recorded: datetime, categories: list[str]
          ) -> tuple[dict, str, list[str]] | None:
    """Normalize a tool call. Returns (args, summary, problems) or None to drop it."""
    problems: list[str] = []
    if name == "add_expenses":
        cats = {c.casefold(): c for c in categories}
        items = []
        for it in args.get("items") or []:
            if not isinstance(it, dict):
                continue
            item = str(it.get("item") or "").strip()
            try:
                valor = round(float(it.get("valor") or 0), 2)
            except (TypeError, ValueError):
                valor = 0
            if not item or valor <= 0:
                problems.append(f"item sem valor: {item or '?'}")
                continue
            day = resolve_day(it.get("data"), recorded.date(), future=False)
            if it.get("data") and not day:
                problems.append(f"data inválida: {it.get('data')}")
            if day and day > recorded.date():
                problems.append(f"data no futuro: {day}")
            cat = cats.get(str(it.get("categoria") or "").casefold())
            local = str(it.get("local") or "").strip() or None
            if local and local.casefold() in cats:
                local = None  # a category the model put in the place field
            items.append({"item": item, "valor": valor,
                          "local": local,
                          "data": (day or recorded.date()).isoformat(),
                          "categoria": cat})
        if not items:
            return None
        total = sum(i["valor"] for i in items)
        summary = (f"Gasto: {items[0]['item']} {_brl(total)}" if len(items) == 1
                   else f"{len(items)} gastos, {_brl(total)}")
        return {"items": items}, summary, problems

    if name in ("add_shopping_items", "add_todos"):
        seen, items = set(), []
        for it in args.get("items") or []:
            text = str(it).strip()
            if text and text.casefold() not in seen:
                seen.add(text.casefold())
                items.append(text)
        if not items:
            return None
        label = "Compras" if name == "add_shopping_items" else (
            "Afazer" if len(items) == 1 else "Afazeres")
        return {"items": items}, f"{label}: {_list_summary(items)}", problems

    if name == "create_event":
        title = str(args.get("title") or "").strip()
        if not title:
            return None
        day = resolve_day(args.get("date"), recorded.date(), future=True)
        if not day:
            problems.append(f"data inválida: {args.get('date')}")
            day = recorded.date()
        elif day < recorded.date():
            problems.append(f"data no passado: {day}")
        start = str(args.get("start") or "").strip()
        end = str(args.get("end") or "").strip()
        if start and not HHMM.match(start):
            problems.append(f"hora inválida: {start}")
            start = ""
        if end and not HHMM.match(end):
            end = ""
        start = f"{int(start.split(':')[0]):02d}:{start.split(':')[1]}" if start else ""
        end = f"{int(end.split(':')[0]):02d}:{end.split(':')[1]}" if end else ""
        when = f"{day:%d/%m}" + (f" {start}" if start else "")
        return ({"title": title, "date": day.isoformat(), "start": start or None,
                 "end": end or None}, f"Evento: {title} ({when})", problems)

    if name == "log_sleep":
        sleep = _clock(args.get("sleep_at"), recorded)
        wake = _clock(args.get("wake_at"), recorded)
        for key, parsed in (("sleep_at", sleep), ("wake_at", wake)):
            if args.get(key) and not parsed:
                problems.append(f"hora inválida: {args.get(key)}")
        try:
            minutes = int(args.get("duration_minutes") or 0)
        except (TypeError, ValueError):
            minutes = 0
        if minutes > 0 and sleep is None:
            wake = wake or recorded
            sleep = wake - timedelta(minutes=minutes)
        elif minutes > 0 and wake is None:
            wake = sleep + timedelta(minutes=minutes)
        if sleep and wake and sleep >= wake:
            sleep -= timedelta(days=1)
        if sleep is None and wake is None:
            return None
        if sleep and wake and wake - sleep > MAX_SLEEP:
            problems.append(f"sono de {(wake - sleep) / timedelta(hours=1):.0f}h")
        if wake and wake > recorded + LOOKAHEAD:
            problems.append("acordar no futuro")
        events = [{"type": t, "at": at.isoformat()}
                  for t, at in (("sleep", sleep), ("wake", wake)) if at]
        if sleep and wake:
            mins = int((wake - sleep).total_seconds() // 60)
            summary = f"Sono: {sleep:%H:%M}–{wake:%H:%M} ({mins // 60}h{mins % 60:02d})"
        elif sleep:
            summary = f"Sono: dormiu às {sleep:%H:%M}"
        else:
            summary = f"Sono: acordou às {wake:%H:%M}"
        return {"events": events}, summary, problems

    return None


def plan(llm: LocalLLM, transcript: str, recorded: datetime, language: str,
         categories: list[str]) -> Plan:
    """Ask the local model which tools to call and check each call."""
    reply = llm.complete(
        [{"role": "system", "content": system_prompt(recorded, language, categories)},
         {"role": "user", "content": transcript}],
        tools=build_tools(categories),
        think=AGENT_THINK or False,
        temperature=0.2,
    )
    actions = []
    for call in reply.tool_calls:
        checked = check(call.name, call.arguments, recorded, categories)
        if checked is None:
            continue
        args, summary, problems = checked
        try:
            confidence = max(0.0, min(1.0, float(call.arguments.get("confidence", 0))))
        except (TypeError, ValueError):
            confidence = 0.0
        if confidence < AGENT_MIN_CONFIDENCE:
            problems.insert(0, f"confiança {confidence:.2f}")
        actions.append({
            "id": uuid.uuid4().hex[:12],
            "tool": call.name,
            "args": args,
            "summary": summary,
            "confidence": round(confidence, 2),
            "reason": "; ".join(problems) or None,
            "status": "pending" if problems else "confirmed",
            "rows": [],
        })
    return Plan(actions=actions, reply=reply.content.strip())


# --- Model lifecycle: loaded only while the agent works ---

AGENT_CTX = int(os.environ.get("AGENT_CTX") or 8192)
AGENT_LOAD_SECONDS = int(os.environ.get("AGENT_LOAD_SECONDS") or 180)


class ModelServer:
    """Starts the local model for a batch of notes and unloads it after, so it
    never sits in VRAM next to WhisperX. If a server is already running
    (started by hand), it is used and left alone."""

    def __init__(self, name: str = AGENT_MODEL, ctx: int = AGENT_CTX, timeout: float = 180):
        self.name = name
        self.ctx = ctx
        self.llm = LocalLLM(name, timeout=timeout)
        self.proc: subprocess.Popen | None = None

    def start(self) -> LocalLLM:
        if self.llm.is_up():
            return self.llm
        script = Path(LOCALLAMA_DIR) / f"start-{self.name}.ps1"
        if not script.exists():
            raise LocalLLMError(f"{script} não existe")
        self.proc = subprocess.Popen(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script),
             "-Ctx", str(self.ctx)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        deadline = time.monotonic() + AGENT_LOAD_SECONDS
        while time.monotonic() < deadline:
            if self.proc.poll() is not None:
                self.proc = None
                raise LocalLLMError(f"o modelo local ({self.name}) fechou ao iniciar")
            if self.llm.is_up():
                return self.llm
            time.sleep(1)
        self.stop()
        raise LocalLLMError(f"o modelo local ({self.name}) não subiu em {AGENT_LOAD_SECONDS}s")

    def stop(self) -> None:
        if self.proc is None:
            return
        # powershell -> llama-server: kill the whole tree to free the VRAM.
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(self.proc.pid)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.proc = None


# --- Executing against Supabase (called by worker.py) ---


def event_title(args: dict) -> str:
    """The todo text for an event card (see lib/models/todo_card.dart)."""
    meta = [("type", "event"), ("title", args["title"]), ("date", args["date"]),
            ("start", args.get("start")), ("end", args.get("end"))]
    lines = [f"{k}: {str(v).replace(chr(10), ' ').strip()}" for k, v in meta if v]
    return "---\n" + "\n".join(lines) + "\n---\n"


async def execute(sb, action: dict, note: dict, list_owner: str,
                  category_ids: dict[str, str]) -> list[dict]:
    """Run one action; returns the rows it created as [{table, id}]."""
    args, user_id = action["args"], note["user_id"]
    if action["tool"] == "add_expenses":
        table = "purchases"
        rows = [{"user_id": list_owner, "purchase_date": it["data"], "item": it["item"],
                 "valor": it["valor"], "local": it["local"],
                 "category_id": category_ids.get((it["categoria"] or "").casefold()),
                 "voice_note_id": note["id"]} for it in args["items"]]
    elif action["tool"] == "add_shopping_items":
        table = "shopping_items"
        rows = [{"user_id": list_owner, "item": it} for it in args["items"]]
    elif action["tool"] == "add_todos":
        table = "todos"
        rows = [{"user_id": user_id, "title": it} for it in args["items"]]
    elif action["tool"] == "create_event":
        table = "todos"
        rows = [{"user_id": user_id, "title": event_title(args)}]
    elif action["tool"] == "log_sleep":
        table = "sleep_events"
        rows = [{"user_id": user_id, "event_type": e["type"], "occurred_at": e["at"]}
                for e in args["events"]]
    else:
        raise ValueError(f"ferramenta desconhecida: {action['tool']}")
    res = await sb.table(table).insert(rows).execute()
    return [{"table": table, "id": r["id"]} for r in res.data]


async def undo(sb, action: dict) -> None:
    by_table: dict[str, list[str]] = {}
    for row in action.get("rows") or []:
        by_table.setdefault(row["table"], []).append(row["id"])
    for table, ids in by_table.items():
        await sb.table(table).delete().in_("id", ids).execute()


# --- CLI dry run ---


def main() -> None:
    ap = argparse.ArgumentParser(description="Dry run: show what the agent would do.")
    ap.add_argument("text")
    ap.add_argument("--lang", choices=["pt", "en"], default="pt")
    ap.add_argument("--at", help="recording time, ISO (default: now)")
    ap.add_argument("--model", default=AGENT_MODEL)
    ap.add_argument("--categories", default="Mercado,Restaurante,Transporte,Casa,Saúde,Lazer")
    a = ap.parse_args()
    recorded = (datetime.fromisoformat(a.at) if a.at else datetime.now()).astimezone()
    cats = [c.strip() for c in a.categories.split(",") if c.strip()]
    server = ModelServer(a.model)
    try:
        p = plan(server.start(), a.text, recorded, a.lang, cats)
    except LocalLLMError as e:
        sys.exit(str(e))
    finally:
        server.stop()
    if not p.actions:
        print(f"(sem ação) {p.reply}")
    for act in p.actions:
        mark = "OK " if act["status"] == "confirmed" else "?? "
        print(f"{mark}{act['summary']}  [{act['tool']}, conf {act['confidence']}]"
              + (f"  -> confirmar: {act['reason']}" if act["reason"] else ""))
        print(f"    {act['args']}")


if __name__ == "__main__":
    main()
