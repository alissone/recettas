"""Transcribe voice notes recorded in the Recettas app, and summarize them on request.

Runs on the PC that has WhisperX. Everything is outbound: the worker
subscribes to Supabase Realtime changes on public.voice_notes (so new
notes are picked up within a second or two) and also polls every
POLL_SECONDS in case the realtime socket drops. No inbound port, no
Tailscale - it works from any network that can reach Supabase.

For each queued note: download the audio from the "voice-notes" bucket,
run WhisperX (transcribe_one.bat), write the transcript to the row and
delete the audio. For each note with summary_status = 'requested': ask
Claude for action-item bullet points and write them to summary.
"""
import asyncio
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
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
# Models that accept the server-side refusal fallback ("default" routing).
FALLBACK_MODELS = {"claude-opus-5-5", "claude-opus-5", "claude-fable-5-1"}
ERROR_TAIL_CHARS = 500


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


# --- Summaries ---


def summarize(client: anthropic.Anthropic, transcript: str) -> str:
    """Ask Claude for action-item bullet points (blocking)."""
    extra = {}
    if CLAUDE_MODEL in FALLBACK_MODELS:
        extra = {"betas": ["server-side-fallback-2026-07-01"], "fallbacks": "default"}
    response = client.beta.messages.create(
        model=CLAUDE_MODEL,
        max_tokens=16000,
        system=SUMMARY_PROMPT,
        output_config={"effort": "low"},
        messages=[{"role": "user", "content": f"Transcrição:\n\n{transcript}"}],
        **extra,
    )
    if response.stop_reason == "refusal":
        raise RuntimeError("Claude recusou resumir esta transcrição")
    return "\n".join(b.text for b in response.content if b.type == "text").strip()


async def summarize_note(sb: AsyncClient, client: anthropic.Anthropic, note: dict) -> None:
    note_id = note["id"]
    if not await claim(sb, note_id, "summary_status", "requested"):
        return
    log(f"Resumindo {note_id}...")
    try:
        summary = await asyncio.to_thread(summarize, client, note.get("transcript") or "")
        await sb.table(TABLE).update({
            "summary_status": "done",
            "summary": summary,
            "error_message": None,
            "updated_at": now_iso(),
        }).eq("id", note_id).execute()
        log(f"Resumo pronto {note_id}")
    except anthropic.AuthenticationError:
        await fail_summary(sb, note_id, "ANTHROPIC_API_KEY inválida no .env do transcriber")
    except anthropic.RateLimitError as e:
        await fail_summary(sb, note_id, f"Limite de uso da API: {e}")
    except anthropic.APIStatusError as e:
        await fail_summary(sb, note_id, f"Erro da API ({e.status_code}): {e.message}")
    except anthropic.APIConnectionError:
        await fail_summary(sb, note_id, "Sem conexão com a API da Anthropic")
    except Exception as e:  # noqa: BLE001 - reported on the row
        await fail_summary(sb, note_id, str(e))


async def fail_summary(sb: AsyncClient, note_id: str, message: str) -> None:
    log(f"Erro no resumo {note_id}: {message}")
    await sb.table(TABLE).update({
        "summary_status": "error",
        "error_message": message[:ERROR_TAIL_CHARS],
        "updated_at": now_iso(),
    }).eq("id", note_id).execute()


# --- Main loop ---


async def process_pending(sb: AsyncClient, client: anthropic.Anthropic) -> None:
    queued = await (
        sb.table(TABLE).select("id, audio_path, duration_seconds")
        .eq("status", "queued").order("recorded_at").execute()
    )
    for note in queued.data:
        await transcribe_note(sb, note)

    requested = await (
        sb.table(TABLE).select("id, transcript")
        .eq("summary_status", "requested").order("updated_at").execute()
    )
    for note in requested.data:
        await summarize_note(sb, client, note)


async def reset_interrupted(sb: AsyncClient) -> None:
    """A previous run died mid-job; this is the only worker, so requeue."""
    await sb.table(TABLE).update({"status": "queued"}).eq("status", "processing").execute()
    await sb.table(TABLE).update({"summary_status": "requested"}).eq(
        "summary_status", "processing").execute()


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
