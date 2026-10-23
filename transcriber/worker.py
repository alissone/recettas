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
shopping_status (things to buy -> shopping) and expenses_status (spoken
purchases -> rows in purchases, echoed in expenses).
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


def run_whisperx(audio: Path, out_dir: Path) -> str:
    """Run WhisperX on audio (blocking); return the transcript text."""
    proc = subprocess.run(
        ["cmd.exe", "/c", str(TRANSCRIBE_BAT), str(audio), str(out_dir),
         WHISPER_MODEL, WHISPER_LANGUAGE],
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
    log(f"Transcrevendo {note_id} ({note.get('duration_seconds') or '?'}s)...")
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
            transcript = await asyncio.to_thread(run_whisperx, local, tmp_dir)
        # Save the text before deleting the audio, so a failure in
        # between never loses the recording.
        await sb.table(TABLE).update({
            "status": "done",
            "transcript": transcript,
            "error_message": None,
            "audio_path": None,
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
        raise RuntimeError("Claude recusou processar esta transcrição")
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


async def expenses_work(sb: AsyncClient, client: anthropic.Anthropic, note: dict) -> dict:
    """Extract spoken purchases and insert them into Gastos (purchases)."""
    note_id = note["id"]
    # The phone's day, as far as this PC can tell (both are in Brazil).
    recorded = datetime.fromisoformat(note["recorded_at"]).astimezone().date()
    cats = await (
        sb.table("purchase_categories").select("id, name")
        .eq("user_id", note["user_id"]).execute()
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
            "user_id": note["user_id"],
            "purchase_date": it["data"],
            "item": it["item"],
            "valor": it["valor"],
            "local": it["local"],
            "category_id": cat_ids.get(it["categoria"].casefold()) if it["categoria"] else None,
            "voice_note_id": note_id,
        } for it in items]).execute()
    return {"expenses": items}


# status column -> (log label, work)
TASKS = {
    "summary_status": ("Resumindo", summary_work),
    "shopping_status": ("Lista de compras de", shopping_work),
    "expenses_status": ("Lançando gastos de", expenses_work),
}


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
    except anthropic.AuthenticationError:
        message = "ANTHROPIC_API_KEY inválida no .env do transcriber"
    except anthropic.RateLimitError as e:
        message = f"Limite de uso da API: {e}"
    except anthropic.APIStatusError as e:
        message = f"Erro da API ({e.status_code}): {e.message}"
    except anthropic.APIConnectionError:
        message = "Sem conexão com a API da Anthropic"
    except Exception as e:  # noqa: BLE001 - reported on the row
        message = str(e)
    log(f"Erro ({label.lower()}) {note_id}: {message}")
    await sb.table(TABLE).update({
        status_column: "error",
        "error_message": message[:ERROR_TAIL_CHARS],
        "updated_at": now_iso(),
    }).eq("id", note_id).eq(status_column, "processing").execute()


# --- Main loop ---


async def process_pending(sb: AsyncClient, client: anthropic.Anthropic) -> None:
    queued = await (
        sb.table(TABLE).select("id, audio_path, duration_seconds")
        .eq("status", "queued").order("recorded_at").execute()
    )
    for note in queued.data:
        await transcribe_note(sb, note)

    for status_column in TASKS:
        requested = await (
            sb.table(TABLE).select("id, user_id, transcript, recorded_at")
            .eq(status_column, "requested").order("updated_at").execute()
        )
        for note in requested.data:
            await run_task(sb, client, status_column, note)


async def reset_interrupted(sb: AsyncClient) -> None:
    """A previous run died mid-job; this is the only worker, so requeue."""
    await sb.table(TABLE).update({"status": "queued"}).eq("status", "processing").execute()
    for status_column in TASKS:
        await sb.table(TABLE).update({status_column: "requested"}).eq(
            status_column, "processing").execute()


async def main() -> None:
    if not SUPABASE_KEY:
        sys.exit("SUPABASE_SERVICE_ROLE_KEY não definida - copie .env.example para .env")
    sb = await acreate_client(SUPABASE_URL, SUPABASE_KEY)
    client = anthropic.Anthropic()
    wake = asyncio.Event()
    loop = asyncio.get_running_loop()

    def on_change(_payload) -> None:
        loop.call_soon_threadsafe(wake.set)

    try:
        channel = sb.channel("voice-notes-worker").on_postgres_changes(
            RealtimePostgresChangesListenEvent.All, on_change,
            table=TABLE, schema="public",
        )
        await channel.subscribe()
        log("Realtime conectado")
    except Exception as e:  # noqa: BLE001 - polling still works without it
        log(f"Realtime indisponível ({e}); usando só polling a cada {POLL_SECONDS}s")

    log(f"Aguardando notas de voz (whisper {WHISPER_MODEL}/{WHISPER_LANGUAGE}, {CLAUDE_MODEL})")
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
