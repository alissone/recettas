-- Two more things the transcriber worker can do with a voice note,
-- requested from the app the same way as summaries (set the status
-- column to 'requested'):
--
--   expenses  "Lançar gastos": Claude turns spoken purchases ("comprei no
--             Mello 3 linguiças por 10 e 50...") into JSON items and the
--             worker inserts them into purchases (Gastos), tagged with
--             voice_note_id. The parsed items are kept here so the app
--             can show what was added.
--   shopping  "Lista de compras": Claude extracts things to buy as "- "
--             lines; the app lets the user pick which go to shopping_items.
alter table public.voice_notes
  add column expenses jsonb,
  add column expenses_status text
    check (expenses_status in ('requested', 'processing', 'done', 'error')),
  add column shopping text,
  add column shopping_status text
    check (shopping_status in ('requested', 'processing', 'done', 'error'));

-- Lets "Refazer" replace the purchases a note created instead of
-- duplicating them (and keeps a crashed-then-requeued job idempotent).
-- Deleting the note keeps the purchases.
alter table public.purchases
  add column voice_note_id uuid references public.voice_notes(id) on delete set null;

create index purchases_voice_note_idx
  on public.purchases (voice_note_id) where voice_note_id is not null;
