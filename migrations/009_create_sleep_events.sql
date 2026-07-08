-- Sleep log: one row per "went to sleep" or "woke up" moment. The app
-- pairs a sleep event with the next wake event to draw sleep intervals.
create table public.sleep_events (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  event_type text not null check (event_type in ('sleep', 'wake')),
  occurred_at timestamptz not null default now(),
  created_at timestamptz default now()
);

alter table public.sleep_events enable row level security;

create policy "Users can view their own sleep events"
  on public.sleep_events for select
  using (auth.uid() = user_id);

create policy "Users can create their own sleep events"
  on public.sleep_events for insert
  with check (auth.uid() = user_id);

create policy "Users can delete their own sleep events"
  on public.sleep_events for delete
  using (auth.uid() = user_id);
