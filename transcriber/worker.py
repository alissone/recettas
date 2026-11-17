"""Transcribe voice notes recorded in the Recettas app, and summarize them on request.

Runs on the PC that has WhisperX. Everything is outbound: the worker
subscribes to Supabase Realtime changes on public.voice_notes (so new
notes are picked up within a second or two) and also polls every
POLL_SECONDS in case the realtime socket drops. No inbound port, no
Tailscale - it works from any network that can reach Supabase.

For each queued note: download the audio from the "voice-notes" bucket,
run WhisperX (transcribe_one.bat), write the transcript to the row and
delete the audio. Claude tasks are requested by setting a status column
to 'requested': summary_status (action-item bullets -> summary),
shopping_status (things to buy -> shopping), expenses_status (spoken
purchases -> rows in purchases, echoed in expenses) and pantry_status
(ingredients at home -> rows in pantry_items, echoed in pantry; read by
the /receitas Claude command, see scripts/receitas).

Each note carries the language picked on the recorder (pt/en), used for
WhisperX. Right after transcribing, the local assistant (agent.py, a small
LLM from C:\\dev\\locallama) may act on the note by itself: Gastos, Compras,
Afazeres, events, Sono. agent_status: 'requested' runs it, 'apply' carries
out what the app confirmed or asked to undo. If the local model is down the
note just keeps its transcript (agent_status = 'error').
"""
import asyncio
import json
import os
import subprocess
import sys
import tempfile
from datetime import date, datetime, timezone
from pathlib import Path

import anthropic
from dotenv import load_dotenv
from realtime.types import RealtimePostgresChangesListenEvent
from supabase import AsyncClient, acreate_client

SCRIPT_DIR = Path(__file__).resolve().parent
load_dotenv(SCRIPT_DIR / ".env")

SUPABASE_URL = os.environ.get("SUPABASE_URL") or "https://jixjuabvprbyupmaqtma.supabase.co"
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
CLAUDE_MODEL = os.environ.get("CLAUDE_MODEL") or "claude-opus-5-5"
WHISPER_MODEL = os.environ.get("WHISPER_MODEL") or "large-v2"
WHISPER_LANGUAGE = os.environ.get("WHISPER_LANGUAGE") or "pt"
POLL_SECONDS = int(os.environ.get("POLL_SECONDS") or 60)
AGENT_ENABLED = (os.environ.get("AGENT_ENABLED") or "1") not in ("0", "false", "no")

try:
    import agent
    from locallm import LocalLLM, LocalLLMError
except Exception as _e:  # noqa: BLE001 - the worker still transcribes without it
    print(f"Assistente local indisponível: {_e}", flush=True)
    agent = None
    AGENT_ENABLED = False

BUCKET = "voice-notes"
TABLE = "voice_notes"
TRANSCRIBE_BAT = SCRIPT_DIR / "transcribe_one.bat"
SUMMARY_PROMPT = (SCRIPT_DIR / "summary_prompt.md").read_text(encoding="utf-8")
SHOPPING_PROMPT = (SCRIPT_DIR / "shopping_prompt.md").read_text(encoding="utf-8")
EXPENSES_PROMPT = (SCRIPT_DIR / "expenses_prompt.md").read_text(encoding="utf-8")
# Structured output for "Lançar gastos"; field meanings are in expenses_prompt.md.
EXPENSES_SCHEMA = {
    "type": "object",
    "properties": {
        "itens": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "item": {"type": "string"},
                    "valor": {"type": "number"},
                    "local": {"type": ["string", "null"]},
                    "data": {"type": ["string", "null"]},
                    "categoria": {"type": ["string", "null"]},
                },
                "required": ["item", "valor", "local", "data", "categoria"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["itens"],
    "additionalProperties": False,
}
PANTRY_PROMPT = (SCRIPT_DIR / "pantry_prompt.md").read_text(encoding="utf-8")
# Structured output for "Guardar o que há na cozinha" (see pantry_prompt.md).
PANTRY_SCHEMA = {
    "type": "object",
    "properties": {
        "itens": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "nome": {"type": "string"},
                    "quantidade": {"type": ["string", "null"]},
                },
                "required": ["nome", "quantidade"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["itens"],
    "additionalProperties": False,
}
# "Responder recrutador" (Mais tab): rows in job_replies, see
# migrations/045_job_replies.sql. The profile is re-read on every request
# so edits apply without restarting the worker.
JOB_TABLE = "job_replies"
JOB_REPLY_PROMPT = (SCRIPT_DIR / "job_reply_prompt.md").read_text(encoding="utf-8")
JOB_REPLY_PROFILE = SCRIPT_DIR / "job_reply_profile.md"
JOB_REPLY_SCHEMA = {
    "type": "object",
    "properties": {
        "assunto": {"type": ["string", "null"]},
        "resposta": {"type": "string"},
        "notas": {"type": "string"},
    },
    "required": ["assunto", "resposta", "notas"],
    "additionalProperties": False,
}
WEEKDAYS_PT = ["segunda-feira", "terça-feira", "quarta-feira", "quinta-feira",
               "sexta-feira", "sábado", "domingo"]
# Models that accept the server-side refusal fallback ("default" routing).
FALLBACK_MODELS = {"claude-opus-5-5", "claude-opus-5", "claude-fable-5-1"}
ERROR_TAIL_CHARS = 500
MIN_AUDIO_BYTES = 1024


def log(msg: str) -> None:
    print(f"[{datetime.now():%H:%M:%S}] {msg}", flush=True)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


# --- Transcription ---


def run_whisperx(audio: Path, out_dir: Path, language: str) -> str:
    """Run WhisperX on audio (blocking); return the transcript text."""
    proc = subprocess.run(
        ["cmd.exe", "/c", str(TRANSCRIBE_BAT), str(audio), str(out_dir),
         WHISPER_MODEL, language],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    output = proc.stdout.decode("utf-8", errors="replace")
    if proc.returncode != 0:
        raise RuntimeError(f"WhisperX falhou ({proc.returncode}): {output[-ERROR_TAIL_CHARS:]}")
    txt = out_dir / f"{audio.stem}.txt"
    if not txt.exists():
        raise RuntimeError(f"WhisperX não gerou {txt.name}: {output[-ERROR_TAIL_CHARS:]}")
    return txt.read_text(encoding="utf-8").strip()


async def claim(sb: AsyncClient, note_id: str, column: str, from_status: str) -> bool:
    """Atomically move a note from from_status to 'processing'; False if someone beat us."""
    res = await (
        sb.table(TABLE)
        .update({column: "processing", "updated_at": now_iso()})
        .eq("id", note_id)
        .eq(column, from_status)
        .execute()
    )
    return bool(res.data)


async def transcribe_note(sb: AsyncClient, note: dict) -> None:
    note_id = note["id"]
    if not await claim(sb, note_id, "status", "queued"):
        return
    audio_path = note["audio_path"]
    language = note.get("language") or WHISPER_LANGUAGE
    log(f"Transcrevendo {note_id} ({note.get('duration_seconds') or '?'}s, {language})...")
    try:
        audio = await sb.storage.from_(BUCKET).download(audio_path)
        if len(audio) < MIN_AUDIO_BYTES:
            # e.g. an m4a with only its header: the phone's recorder never
            # captured audio. ffmpeg's "Invalid data" would hide that.
            raise RuntimeError(
                f"Áudio vazio ({len(audio)} bytes) - a gravação falhou no celular")
        with tempfile.TemporaryDirectory(prefix="voice_note_") as tmp:
            tmp_dir = Path(tmp)
            local = tmp_dir / f"{note_id}{Path(audio_path).suffix or '.m4a'}"
            local.write_bytes(audio)
            # WhisperX blocks for minutes; keep the event loop (and the
            # realtime heartbeat) alive meanwhile.
            transcript = await asyncio.to_thread(run_whisperx, local, tmp_dir, language)
        # Save the text before deleting the audio, so a failure in
        # between never loses the recording.
        await sb.table(TABLE).update({
            "status": "done",
            "transcript": transcript,
            "error_message": None,
            "audio_path": None,
            # The local assistant looks at every new transcript.
            **({"agent_status": "requested"} if AGENT_ENABLED and transcript else {}),
            "updated_at": now_iso(),
        }).eq("id", note_id).execute()
        try:
            await sb.storage.from_(BUCKET).remove([audio_path])
        except Exception as e:  # noqa: BLE001 - orphaned audio is harmless
            log(f"Aviso: não consegui apagar {audio_path}: {e}")
        log(f"Pronto {note_id}: {len(transcript)} caracteres")
    except Exception as e:  # noqa: BLE001 - any failure is reported on the row
        log(f"Erro em {note_id}: {e}")
        await sb.table(TABLE).update({
            "status": "error",
            "error_message": str(e)[:ERROR_TAIL_CHARS],
            "updated_at": now_iso(),
        }).eq("id", note_id).execute()


# --- Claude tasks (summary, shopping list, expenses) ---


def ask_claude(client: anthropic.Anthropic, system: str, content: str,
               effort: str = "low", json_schema: dict | None = None) -> str:
    """One Claude request (blocking); returns the response text."""
    extra = {}
    if CLAUDE_MODEL in FALLBACK_MODELS:
        extra = {"betas": ["server-side-fallback-2026-07-01"], "fallbacks": "default"}
    output_config: dict = {"effort": effort}
    if json_schema:
        output_config["format"] = {"type": "json_schema", "schema": json_schema}
    response = client.beta.messages.create(
        model=CLAUDE_MODEL,
        max_tokens=16000,
        system=system,
        output_config=output_config,
        messages=[{"role": "user", "content": content}],
        **extra,
    )
    if response.stop_reason == "refusal":
        raise RuntimeError("Claude recusou o pedido")
    if response.stop_reason == "max_tokens":
        raise RuntimeError("Resposta do Claude cortada (max_tokens)")
    return "\n".join(b.text for b in response.content if b.type == "text").strip()


def transcript_message(note: dict) -> str:
    return f"Transcrição:\n\n{note.get('transcript') or ''}"


async def summary_work(sb: AsyncClient, client: anthropic.Anthropic, note: dict) -> dict:
    text = await asyncio.to_thread(ask_claude, client, SUMMARY_PROMPT, transcript_message(note))
    return {"summary": text}


async def shopping_work(sb: AsyncClient, client: anthropic.Anthropic, note: dict) -> dict:
    text = await asyncio.to_thread(ask_claude, client, SHOPPING_PROMPT, transcript_message(note))
    return {"shopping": text}


def parse_date(value) -> date | None:
    try:
        return date.fromisoformat(str(value)) if value else None
    except ValueError:
        return None


class TaskCancelled(Exception):
    """The app cancelled the task (status column reset) while it ran."""


async def still_claimed(sb: AsyncClient, note_id: str, status_column: str) -> bool:
    res = await sb.table(TABLE).select("id").eq("id", note_id).eq(
        status_column, "processing").execute()
    return bool(res.data)


async def target_list(sb: AsyncClient, user_id: str) -> str:
    """Owner id of the Gastos list to insert into.

    A shared list the user was invited to (migrations 012/013) wins over
    their own: that's the list they actually keep. With several, the one
    with the most recent purchase.
    """
    invites = await (
        sb.table("list_invites").select("inviter_id")
        .eq("invitee_id", user_id).eq("status", "accepted").execute()
    )
    shared = [r["inviter_id"] for r in invites.data]
    if len(shared) <= 1:
        return shared[0] if shared else user_id
    latest = await (
        sb.table("purchases").select("user_id").in_("user_id", shared)
        .order("created_at", desc=True).limit(1).execute()
    )
    return latest.data[0]["user_id"] if latest.data else shared[0]


async def expenses_work(sb: AsyncClient, client: anthropic.Anthropic, note: dict) -> dict:
    """Extract spoken purchases and insert them into Gastos (purchases)."""
    note_id = note["id"]
    # The phone's day, as far as this PC can tell (both are in Brazil).
    recorded = datetime.fromisoformat(note["recorded_at"]).astimezone().date()
    # Categories belong to the list, so use the target list's own.
    owner_id = await target_list(sb, note["user_id"])
    cats = await (
        sb.table("purchase_categories").select("id, name")
        .eq("user_id", owner_id).execute()
    )
    cat_ids = {c["name"].casefold(): c["id"] for c in cats.data}
    context = (
        f"Data da gravação: {recorded.isoformat()} ({WEEKDAYS_PT[recorded.weekday()]})\n"
        f"Categorias: {', '.join(c['name'] for c in cats.data) or '(nenhuma)'}\n\n"
        + transcript_message(note)
    )
    text = await asyncio.to_thread(
        ask_claude, client, EXPENSES_PROMPT, context, "medium", EXPENSES_SCHEMA)
    items = []
    for it in json.loads(text)["itens"]:
        valor = round(float(it.get("valor") or 0), 2)
        name = (it.get("item") or "").strip()
        if valor <= 0 or not name:
            continue
        categoria = it.get("categoria")
        items.append({
            "item": name,
            "valor": valor,
            "local": (it.get("local") or "").strip() or None,
            "data": (parse_date(it.get("data")) or recorded).isoformat(),
            "categoria": categoria if categoria and categoria.casefold() in cat_ids else None,
        })
    # Cancelled while Claude was thinking: don't touch Gastos.
    if not await still_claimed(sb, note_id, "expenses_status"):
        raise TaskCancelled
    # Replace whatever an earlier run for this note inserted ("Refazer", or
    # a run that died before marking the note done).
    await sb.table("purchases").delete().eq("voice_note_id", note_id).execute()
    if items:
        await sb.table("purchases").insert([{
            "user_id": owner_id,
            "purchase_date": it["data"],
            "item": it["item"],
            "valor": it["valor"],
            "local": it["local"],
            "category_id": cat_ids.get(it["categoria"].casefold()) if it["categoria"] else None,
            "voice_note_id": note_id,
        } for it in items]).execute()
    return {"expenses": items}


async def pantry_work(sb: AsyncClient, client: anthropic.Anthropic, note: dict) -> dict:
    """Save the ingredients said in the note as that day's pantry."""
    note_id = note["id"]
    recorded = datetime.fromisoformat(note["recorded_at"]).astimezone().date()
    text = await asyncio.to_thread(
        ask_claude, client, PANTRY_PROMPT, transcript_message(note), "low", PANTRY_SCHEMA)
    items, seen = [], set()
    for it in json.loads(text)["itens"]:
        name = (it.get("nome") or "").strip()
        if not name or name.casefold() in seen:
            continue
        seen.add(name.casefold())
        items.append({"nome": name, "quantidade": (it.get("quantidade") or "").strip() or None})
    if not await still_claimed(sb, note_id, "pantry_status"):
        raise TaskCancelled
    # Replace what an earlier run for this note saved ("Refazer").
    await sb.table("pantry_items").delete().eq("voice_note_id", note_id).execute()
    if items:
        await sb.table("pantry_items").insert([{
            "user_id": note["user_id"],
            "voice_note_id": note_id,
            "name": it["nome"],
            "quantity": it["quantidade"],
            "seen_on": recorded.isoformat(),
        } for it in items]).execute()
    return {"pantry": items}


# status column -> (log label, work)
TASKS = {
    "summary_status": ("Resumindo", summary_work),
    "shopping_status": ("Lista de compras de", shopping_work),
    "expenses_status": ("Lançando gastos de", expenses_work),
    "pantry_status": ("Guardando a cozinha de", pantry_work),
}


def api_error_message(e: Exception) -> str:
    """Readable message for the app, for any failure of a Claude task."""
    if isinstance(e, anthropic.AuthenticationError):
        return "ANTHROPIC_API_KEY inválida no .env do transcriber"
    if isinstance(e, anthropic.RateLimitError):
        return f"Limite de uso da API: {e}"
    if isinstance(e, anthropic.APIStatusError):
        return f"Erro da API ({e.status_code}): {e.message}"
    if isinstance(e, anthropic.APIConnectionError):
        return "Sem conexão com a API da Anthropic"
    return str(e)


# --- Local assistant (agent.py) ---

async def run_agents(sb: AsyncClient, notes: list[dict]) -> None:
    """Run the assistant on a batch of notes. The local model is loaded only
    if some note needs it and unloaded right after, so it is never in VRAM
    while WhisperX runs (both happen in this one loop, one after the other)."""
    server = None
    if any(n["agent_status"] == "requested" for n in notes):
        server = agent.ModelServer()
        log(f"Carregando modelo local ({agent.AGENT_MODEL})...")
        try:
            await asyncio.to_thread(server.start)
        except LocalLLMError as e:
            log(f"Modelo local não subiu: {e}")  # each note reports it below
    try:
        for note in notes:
            await run_agent(sb, note, server.llm if server else None)
    finally:
        if server:
            await asyncio.to_thread(server.stop)
            log("Modelo local descarregado")


async def run_agent(sb: AsyncClient, note: dict, llm) -> None:
    """Plan and run actions for a note ('requested'), or apply what the app
    confirmed / asked to undo ('apply')."""
    note_id, mode = note["id"], note["agent_status"]
    if not await claim(sb, note_id, "agent_status", mode):
        return
    try:
        recorded = datetime.fromisoformat(note["recorded_at"]).astimezone()
        owner_id = await target_list(sb, note["user_id"])
        cats = await (
            sb.table("purchase_categories").select("id, name")
            .eq("user_id", owner_id).execute()
        )
        cat_ids = {c["name"].casefold(): c["id"] for c in cats.data}
        actions = note.get("agent_actions") or []
        if mode == "requested":
            # A rerun replaces whatever the previous run did.
            for a in actions:
                if a.get("status") == "done":
                    await agent.undo(sb, a)
            log(f"Assistente lendo {note_id}...")
            try:
                result = await asyncio.to_thread(
                    agent.plan, llm, note.get("transcript") or "", recorded,
                    note.get("language") or WHISPER_LANGUAGE, [c["name"] for c in cats.data])
            except LocalLLMError as e:
                raise RuntimeError(
                    f"Modelo local ({agent.AGENT_MODEL}) não respondeu: {e}") from e
            actions = result.actions
        for a in actions:
            if a.get("status") == "confirmed":
                try:
                    a["rows"] = await agent.execute(sb, a, note, owner_id, cat_ids)
                    a["status"] = "done"
                except Exception as e:  # noqa: BLE001 - reported on the action
                    a["status"], a["error"] = "error", str(e)[:300]
            elif a.get("status") == "undo":
                await agent.undo(sb, a)
                a["status"] = "undone"
        await sb.table(TABLE).update({
            "agent_status": "done",
            "agent_actions": actions,
            # The app shows a snackbar/dialog for a new run; for 'apply' it
            # was the app that asked, so it already knows.
            "agent_notified": mode == "apply" or not actions,
            "updated_at": now_iso(),
        }).eq("id", note_id).eq("agent_status", "processing").execute()
        log(f"Assistente {note_id}: " + (
            "; ".join(f"{a['status']}: {a['summary']}" for a in actions) or "nenhuma ação"))
    except Exception as e:  # noqa: BLE001 - reported on the row
        log(f"Erro (assistente) {note_id}: {e}")
        await sb.table(TABLE).update({
            "agent_status": "error",
            "error_message": str(e)[:ERROR_TAIL_CHARS],
            "updated_at": now_iso(),
        }).eq("id", note_id).eq("agent_status", "processing").execute()


# --- Recruiter replies (job_replies) ---


def job_reply_message(row: dict) -> str:
    channel = "e-mail" if row.get("channel") == "email" else "mensagem do LinkedIn"
    parts = [
        f"<perfil>\n{JOB_REPLY_PROFILE.read_text(encoding='utf-8')}\n</perfil>",
        f"Hoje é {date.today().isoformat()}. Canal: {channel}.",
        f"Mensagem recebida:\n\n{row['message']}",
    ]
    if row.get("job_description"):
        parts.append(f"Descrição da vaga:\n\n{row['job_description']}")
    parts.append(f"Instruções do Alisson: {row.get('instructions') or '(nenhuma)'}")
    return "\n\n---\n\n".join(parts)


async def job_reply_task(sb: AsyncClient, client: anthropic.Anthropic, row: dict) -> None:
    row_id = row["id"]
    claimed = await (
        sb.table(JOB_TABLE).update({"status": "processing", "updated_at": now_iso()})
        .eq("id", row_id).eq("status", "requested").execute()
    )
    if not claimed.data:
        return
    log(f"Respondendo recrutador {row_id}...")
    try:
        text = await asyncio.to_thread(
            ask_claude, client, JOB_REPLY_PROMPT, job_reply_message(row),
            "medium", JOB_REPLY_SCHEMA)
        out = json.loads(text)
        # Only if still ours: "Cancelar" in the app moves it to 'error'.
        res = await sb.table(JOB_TABLE).update({
            "status": "done",
            "subject": (out.get("assunto") or "").strip() or None,
            "reply": out["resposta"].strip(),
            "notes": (out.get("notas") or "").strip() or None,
            "error_message": None,
            "updated_at": now_iso(),
        }).eq("id", row_id).eq("status", "processing").execute()
        log(f"Pronto: resposta {row_id}" if res.data else f"Cancelado no app: resposta {row_id}")
    except Exception as e:  # noqa: BLE001 - reported on the row
        message = api_error_message(e)
        log(f"Erro (resposta) {row_id}: {message}")
        await sb.table(JOB_TABLE).update({
            "status": "error",
            "error_message": message[:ERROR_TAIL_CHARS],
            "updated_at": now_iso(),
        }).eq("id", row_id).eq("status", "processing").execute()


async def run_task(sb: AsyncClient, client: anthropic.Anthropic, status_column: str,
                   note: dict) -> None:
    note_id = note["id"]
    if not await claim(sb, note_id, status_column, "requested"):
        return
    label, work = TASKS[status_column]
    log(f"{label} {note_id}...")
    try:
        fields = await work(sb, client, note)
        # Only if still ours: "Cancelar" in the app resets the column.
        res = await sb.table(TABLE).update({
            **fields,
            status_column: "done",
            # error_message is shared by all tasks; leave it for any other
            # task that is still in error.
            "updated_at": now_iso(),
        }).eq("id", note_id).eq(status_column, "processing").execute()
        log(f"Pronto: {label.lower()} {note_id}" if res.data
            else f"Cancelado no app: {label.lower()} {note_id}")
        return
    except TaskCancelled:
        log(f"Cancelado no app: {label.lower()} {note_id}")
        return
    except Exception as e:  # noqa: BLE001 - reported on the row
        message = api_error_message(e)
    log(f"Erro ({label.lower()}) {note_id}: {message}")
    await sb.table(TABLE).update({
        status_column: "error",
        "error_message": message[:ERROR_TAIL_CHARS],
        "updated_at": now_iso(),
    }).eq("id", note_id).eq(status_column, "processing").execute()


# --- Main loop ---


async def process_pending(sb: AsyncClient, client: anthropic.Anthropic) -> None:
    queued = await (
        sb.table(TABLE).select("id, audio_path, duration_seconds"
                               + (", language" if HAS_046 else ""))
        .eq("status", "queued").order("recorded_at").execute()
    )
    for note in queued.data:
        await transcribe_note(sb, note)

    if AGENT_ENABLED:
        pending = await (
            sb.table(TABLE)
            .select("id, user_id, transcript, recorded_at, language, agent_status, agent_actions")
            .in_("agent_status", ["requested", "apply"]).order("updated_at").execute()
        )
        if pending.data:
            await run_agents(sb, pending.data)

    for status_column in TASKS:
        requested = await (
            sb.table(TABLE).select("id, user_id, transcript, recorded_at")
            .eq(status_column, "requested").order("updated_at").execute()
        )
        for note in requested.data:
            await run_task(sb, client, status_column, note)

    try:
        replies = await (
            sb.table(JOB_TABLE).select("id, channel, message, job_description, instructions")
            .eq("status", "requested").order("updated_at").execute()
        )
    except Exception as e:  # noqa: BLE001
        if not table_missing(e):
            raise
        # Migration 045 not run yet: skip recruiter replies, keep the rest.
        warn_job_table_missing()
        return
    for row in replies.data:
        await job_reply_task(sb, client, row)


_job_table_warned = False


def table_missing(e: Exception) -> bool:
    return "PGRST205" in str(e) or "Could not find the table" in str(e)


def warn_job_table_missing() -> None:
    global _job_table_warned
    if not _job_table_warned:
        _job_table_warned = True
        log(f"Tabela {JOB_TABLE} não existe: respostas a recrutador desligadas "
            "(rode migrations/045_job_replies.sql; não precisa reiniciar)")


async def reset_interrupted(sb: AsyncClient) -> None:
    """A previous run died mid-job; this is the only worker, so requeue."""
    await sb.table(TABLE).update({"status": "queued"}).eq("status", "processing").execute()
    for status_column in TASKS:
        await sb.table(TABLE).update({status_column: "requested"}).eq(
            status_column, "processing").execute()
    # Interrupted assistant: a full run had no actions yet; otherwise it was
    # applying the app's confirmations.
    if HAS_046:
        await sb.table(TABLE).update({"agent_status": "requested"}).eq(
            "agent_status", "processing").is_("agent_actions", "null").execute()
        await sb.table(TABLE).update({"agent_status": "apply"}).eq(
            "agent_status", "processing").not_.is_("agent_actions", "null").execute()
    try:
        await sb.table(JOB_TABLE).update({"status": "requested"}).eq(
            "status", "processing").execute()
    except Exception as e:  # noqa: BLE001
        if not table_missing(e):
            raise
        warn_job_table_missing()


# Columns from migrations/046 (language, agent_*). Until it is run the worker
# keeps working as before: Portuguese only, no assistant.
HAS_046 = True


async def check_schema(sb: AsyncClient) -> None:
    global HAS_046, AGENT_ENABLED
    try:
        await sb.table(TABLE).select("language, agent_status").limit(1).execute()
    except Exception as e:  # noqa: BLE001 - missing column, or offline at boot
        if "does not exist" in str(e) or "42703" in str(e):
            HAS_046, AGENT_ENABLED = False, False
            log("Migração 046 não aplicada: sem idioma por nota e sem assistente "
                "(rode migrations/046_voice_notes_language_agent.sql)")


async def main() -> None:
    if not SUPABASE_KEY:
        sys.exit("SUPABASE_SERVICE_ROLE_KEY não definida - copie .env.example para .env")
    sb = await acreate_client(SUPABASE_URL, SUPABASE_KEY)
    await check_schema(sb)
    client = anthropic.Anthropic()
    wake = asyncio.Event()
    loop = asyncio.get_running_loop()

    def on_change(_payload) -> None:
        loop.call_soon_threadsafe(wake.set)

    try:
        channel = sb.channel("voice-notes-worker").on_postgres_changes(
            RealtimePostgresChangesListenEvent.All, on_change,
            table=TABLE, schema="public",
        ).on_postgres_changes(
            RealtimePostgresChangesListenEvent.All, on_change,
            table=JOB_TABLE, schema="public",
        )
        await channel.subscribe()
        log("Realtime conectado")
    except Exception as e:  # noqa: BLE001 - polling still works without it
        log(f"Realtime indisponível ({e}); usando só polling a cada {POLL_SECONDS}s")

    log(f"Aguardando notas de voz (whisper {WHISPER_MODEL}, {CLAUDE_MODEL}, assistente "
        + (agent.AGENT_MODEL if AGENT_ENABLED else "desligado") + ")")
    needs_reset = True
    while True:
        wake.clear()
        try:
            # Inside the try: at boot the network may not be up yet.
            if needs_reset:
                await reset_interrupted(sb)
                needs_reset = False
            await process_pending(sb, client)
        except Exception as e:  # noqa: BLE001 - offline etc.; retry next round
            log(f"Erro consultando a fila: {e}")
        try:
            await asyncio.wait_for(wake.wait(), POLL_SECONDS)
        except asyncio.TimeoutError:
            pass


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
