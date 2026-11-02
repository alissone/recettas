-- "Guardar o que há na cozinha": a voice note listing the ingredients
-- lying around the house. Requested from the app like the other Claude
-- tasks (pantry_status = 'requested'); the transcriber worker has Claude
-- turn the list into rows here, tagged with the note, and echoes them in
-- voice_notes.pantry so the app can show what was saved.
--
-- One note is one snapshot: seen_on is the recording day, and the
-- /receitas Claude command (scripts/receitas) cooks from the latest day
-- that has items. Older days are kept as history.
create table public.pantry_items (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  -- "Refazer" replaces what the note saved; deleting the note keeps them.
  voice_note_id uuid references public.voice_notes(id) on delete set null,
  name text not null,
  quantity text,
  seen_on date not null,
  created_at timestamptz default now()
);

create index pantry_items_user_day_idx
  on public.pantry_items (user_id, seen_on desc);
create index pantry_items_voice_note_idx
  on public.pantry_items (voice_note_id) where voice_note_id is not null;

alter table public.pantry_items enable row level security;

create policy "Users can view their own pantry items"
  on public.pantry_items for select
  using (auth.uid() = user_id);

create policy "Users can create their own pantry items"
  on public.pantry_items for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own pantry items"
  on public.pantry_items for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their own pantry items"
  on public.pantry_items for delete
  using (auth.uid() = user_id);

alter table public.voice_notes
  add column pantry jsonb,
  add column pantry_status text
    check (pantry_status in ('requested', 'processing', 'done', 'error'));
