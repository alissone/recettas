-- Voice notes: language switch + local assistant.
--
-- language: chosen on the recorder sheet (PT/EN). The worker passes it to
-- WhisperX and to the local model.
--
-- agent_*: right after transcribing, the worker runs the note through a
-- small local LLM (C:\dev\locallama, transcriber/agent.py) that may call
-- tools: Gastos, Compras, Afazeres, events and Sono. Actions it is sure
-- about run at once; the rest wait for the app to confirm.
--
-- agent_actions is a list of
--   {id, tool, args, summary, confidence, reason,
--    status: done | pending | confirmed | discarded | undo | undone | error,
--    rows: [{table, id}], error}
-- The app moves an action to 'confirmed' (run it) or 'undo' (delete the
-- rows it created) and sets agent_status = 'apply'; the worker does it and
-- sets agent_status back to 'done'. 'requested' reruns the whole agent.
-- agent_notified: the app already showed the snackbar/dialog for it.
alter table public.voice_notes
  add column language text not null default 'pt'
    check (language in ('pt', 'en')),
  add column agent_status text
    check (agent_status in ('requested', 'processing', 'done', 'apply', 'error')),
  add column agent_actions jsonb,
  add column agent_notified boolean not null default false;
