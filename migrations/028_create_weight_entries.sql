-- Body weight history, one row per check-in. recorded_at keeps time (not
-- just date) since the Nutrition screen's "this week" chart plots entries
-- as they were logged, while the longer-range chart buckets them into
-- weekly averages.
create table public.weight_entries (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  weight_kg numeric not null,
  recorded_at timestamptz not null default now(),
  created_at timestamptz default now()
);

alter table public.weight_entries enable row level security;

create policy "Users can view their own weight entries"
  on public.weight_entries for select
  using (auth.uid() = user_id);

create policy "Users can create their own weight entries"
  on public.weight_entries for insert
  with check (auth.uid() = user_id);

create policy "Users can delete their own weight entries"
  on public.weight_entries for delete
  using (auth.uid() = user_id);

create index weight_entries_user_recorded_idx
  on public.weight_entries (user_id, recorded_at);
