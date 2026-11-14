-- Replies to recruiters: the user pastes a job e-mail or LinkedIn message
-- (and optionally the full job description) in "Mais > Responder
-- recrutador"; the transcriber worker (transcriber/worker.py) asks Claude
-- for a reply, using transcriber/job_reply_profile.md as the user's
-- background, and writes it back here. Same flow as the voice-note
-- tasks: the app sets status = 'requested', the worker claims it
-- ('processing') and finishes with 'done' or 'error'.
create table public.job_replies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  channel text not null default 'linkedin'
    check (channel in ('email', 'linkedin')),
  -- The message as received from the recruiter.
  message text not null,
  -- Optional: the full job description, when the message only links to it.
  job_description text,
  -- Optional: what the user wants ("interessado, pergunte o valor",
  -- "recusar com educação", "responder em português").
  instructions text,
  status text not null default 'requested'
    check (status in ('requested', 'processing', 'done', 'error')),
  error_message text,
  -- Filled by the worker.
  subject text,
  reply text,
  -- Short fit/gap notes for the user, not meant to be sent.
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index job_replies_user_created_idx
  on public.job_replies (user_id, created_at desc);

alter table public.job_replies enable row level security;

create policy "Users can view their own job replies"
  on public.job_replies for select
  using (auth.uid() = user_id);

create policy "Users can create their own job replies"
  on public.job_replies for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own job replies"
  on public.job_replies for update
  using (auth.uid() = user_id);

create policy "Users can delete their own job replies"
  on public.job_replies for delete
  using (auth.uid() = user_id);

-- The worker wakes on inserts/updates; the app watches its rows live.
alter publication supabase_realtime add table public.job_replies;
