-- Voice notes recorded on the phone and transcribed by the local
-- WhisperX worker (transcriber/worker.py). The phone uploads the audio
-- to the "voice-notes" bucket and inserts a row; the worker picks it up
-- (realtime + polling, outbound only - no Tailscale needed), writes the
-- transcript here and deletes the audio. Summaries are requested the
-- same way: the app sets summary_status = 'requested' and the worker
-- fills in summary.
create table public.voice_notes (
  -- Generated on the phone, so the audio path and the row share it and a
  -- retried upload can't create a duplicate.
  id uuid primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  -- Null once the worker has transcribed the audio and deleted it.
  audio_path text,
  duration_seconds integer,
  status text not null default 'queued'
    check (status in ('queued', 'processing', 'done', 'error')),
  error_message text,
  transcript text,
  summary text,
  summary_status text
    check (summary_status in ('requested', 'processing', 'done', 'error')),
  recorded_at timestamptz not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.voice_notes enable row level security;

create policy "Users can view their own voice notes"
  on public.voice_notes for select
  using (auth.uid() = user_id);

create policy "Users can create their own voice notes"
  on public.voice_notes for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own voice notes"
  on public.voice_notes for update
  using (auth.uid() = user_id);

create policy "Users can delete their own voice notes"
  on public.voice_notes for delete
  using (auth.uid() = user_id);

-- The worker subscribes to inserts/updates so new notes and summary
-- requests are picked up immediately instead of on the next poll.
alter publication supabase_realtime add table public.voice_notes;

-- Private bucket for the audio, keyed "<user_id>/<note_id>.m4a". The
-- worker uses the service role key, which bypasses these policies.
insert into storage.buckets (id, name, public)
values ('voice-notes', 'voice-notes', false)
on conflict (id) do nothing;

create policy "Users can upload their own voice notes"
  on storage.objects for insert
  with check (
    bucket_id = 'voice-notes'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Needed for upsert: a retried upload overwrites the partial one.
create policy "Users can update their own voice notes audio"
  on storage.objects for update
  using (
    bucket_id = 'voice-notes'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can view their own voice notes audio"
  on storage.objects for select
  using (
    bucket_id = 'voice-notes'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their own voice notes audio"
  on storage.objects for delete
  using (
    bucket_id = 'voice-notes'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
