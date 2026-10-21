# transcriber

Background worker for the app's voice notes (Afazeres → mic button). It
runs on the PC with WhisperX and talks **only outbound** to Supabase: no
open port, no web server, no Tailscale. It works from any network the PC
can reach Supabase from.

```
phone ──upload .m4a──▶ Supabase Storage (voice-notes)  ◀──download── worker
      ──insert row───▶ public.voice_notes  ──realtime──▶  (WhisperX, Claude)
      ◀──transcript / summary────────────── row update ◀──
```

1. The phone saves the recording locally, then uploads it as soon as
   there's a connection: audio goes to `voice-notes/<user>/<id>.m4a`, and a row
   goes into `voice_notes` with `status = 'queued'`.
2. The worker is subscribed to Realtime changes on that table, so it
   wakes within a second or two. It also polls every `POLL_SECONDS`
   in case the socket drops. It downloads the audio, runs WhisperX
   (`transcribe_one.bat`, same `whisperx` conda env as `falar.bat`), writes
   `transcript`, and deletes the audio from Storage.
3. "Resumir" in the app sets `summary_status = 'requested'`. The worker
   asks Claude for action-item bullets (`summary_prompt.md`) and writes
   them to `summary`. The app turns them into todos.

Notes recorded while the PC is off just wait in the queue. Anything
interrupted mid-job is requeued when the worker starts.

## Setup

1. Run `migrations/035_create_voice_notes.sql` in the Supabase SQL editor.
2. `setup.bat` creates `.venv`, installs the dependencies, and creates `.env`.
3. Fill in `.env`:
   - `SUPABASE_SERVICE_ROLE_KEY`: Dashboard → Project Settings → API.
     The worker uses it to see every user's queue, bypassing RLS. Keep
     it on this machine only (`.env` is gitignored).
   - `ANTHROPIC_API_KEY`: the same key as in `C:\dev\Summaries\.env`.
4. `run.bat` starts the worker. To start it at login, put a shortcut to
   `run.bat` in `shell:startup` (Win+R → `shell:startup`).

## Config (`.env`)

| Key | Default | |
|---|---|---|
| `WHISPER_MODEL` | `large-v2` | any WhisperX model name |
| `WHISPER_LANGUAGE` | `pt` | passed to `--language` |
| `CLAUDE_MODEL` | `claude-opus-5-5` | model used for summaries |
| `POLL_SECONDS` | `60` | fallback poll interval |

The conda path (`D:\anaconda3\condabin\conda.bat`) and env name live
at the top of `transcribe_one.bat`.
