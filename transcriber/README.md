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
3. The "Com Claude" actions in the app set a status column to
   `'requested'` and the worker runs the matching task:
   - `summary_status`: action-item bullets (`summary_prompt.md`) go to
     `summary`. The app turns the ones you pick into todos.
   - `shopping_status`: things to buy (`shopping_prompt.md`) go to
     `shopping`. The app adds the ones you pick to Compras.
   - `expenses_status`: spoken purchases ("comprei no Mello 3 linguiças
     por 10 e 50...") are extracted as JSON (`expenses_prompt.md`, with
     structured output). Each item has an item, a value, an optional
     place, a date when one other than the recording day is mentioned,
     and one of the user's categories. The worker inserts them straight
     into `purchases` with `voice_note_id`, and echoes them in `expenses`.
     A rerun deletes that note's purchases first, so it never duplicates.

4. "Responder recrutador" (Mais tab) inserts a row into `job_replies`
   with `status = 'requested'`: the pasted recruiter message (e-mail or
   LinkedIn), an optional job description and optional instructions. The
   worker sends it to Claude with `job_reply_prompt.md` plus
   `job_reply_profile.md` (your career background, re-read on every
   request, so keep it current) and writes back `subject`, `reply` and
   `notes` (fit and gaps, for you only).

5. **Local assistant** (`agent.py`, no cloud). Right after a note is
   transcribed, the worker loads a small local LLM (`C:\dev\locallama`,
   Qwen3.5-9B by default), asks it whether the note asks for something,
   and unloads it again. That way it never shares the GPU with WhisperX
   (load + answer + unload takes about 10 s). Its tools:
   - `add_expenses`: rows in `purchases`, same rules as `expenses_prompt.md`
   - `add_shopping_items`: rows in `shopping_items`
   - `add_todos`: rows in `todos`
   - `create_event`: a `todos` row as an event card (`type: event`)
   - `log_sleep`: `sleep_events` ("vou dormir", "acordei", "dormi 40 min")

   The model writes days as words ("friday", "tomorrow", "25") and
   `resolve_day` turns them into dates, since a 9B model gets calendar
   math wrong. An action runs at once if the model's confidence is
   >= `AGENT_MIN_CONFIDENCE` and it passes the checks (amount > 0, valid
   date not in the past, sane sleep times). Otherwise it is saved as
   `pending`. Everything is in `voice_notes.agent_actions`, including the
   ids of the rows each action created. The app shows a snackbar for
   what was done (with **Desfazer**) and a dialog for the pending
   actions. It sends confirm/undo back by marking the actions and setting
   `agent_status = 'apply'`. Older app versions don't show any of this,
   and sure actions still run silently. A note with no request just
   keeps its transcript.

   Dry run without the database: `.venv\Scripts\python.exe agent.py
   "comprei pão por 8 reais e preciso comprar leite"` (`--lang en`,
   `--at 2026-11-17T08:00`).

The recorder has a PT/EN switch; it's saved in `voice_notes.language`
(migration 046) and passed to WhisperX and to the assistant.

Notes recorded while the PC is off just wait in the queue. Anything
interrupted mid-job is requeued when the worker starts.

## Setup

1. Run `migrations/035_create_voice_notes.sql` and
   `036_voice_notes_expenses_shopping.sql` (and `045_job_replies.sql` for
   recruiter replies, `046_voice_notes_language_agent.sql` for the
   language switch and local assistant) in the Supabase SQL editor.
   Without 046 the worker still runs, Portuguese only and without the
   assistant.
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
| `CLAUDE_MODEL` | `claude-opus-5-5` | model used for the Claude tasks |
| `POLL_SECONDS` | `60` | fallback poll interval |
| `AGENT_ENABLED` | `1` | `0` turns the local assistant off |
| `AGENT_MODEL` | `qwen3.5-9b` | any model in `locallm.py` with a `start-<name>.ps1` |
| `AGENT_MIN_CONFIDENCE` | `0.75` | below this an action waits for confirmation |
| `AGENT_THINK` | (off) | `low`/`medium`/`high`: slower, more careful |
| `AGENT_CTX` | `8192` | context size the model is loaded with |
| `LOCALLAMA_DIR` | `C:\dev\locallama` | where `locallm.py` and the start scripts are |

`WHISPER_LANGUAGE` is now only the fallback for notes without a language.

The conda path (`D:\anaconda\condabin\conda.bat`) and env name live
at the top of `transcribe_one.bat`.
