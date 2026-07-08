-- Accelerometer recordings captured by the app. Each recording is a burst
-- of 200 samples; samples is a jsonb array of [t_ms, x, y, z] vectors,
-- where t_ms is milliseconds since the start of the recording.
create table public.accel_recordings (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  recorded_at timestamptz not null default now(),
  sample_count integer not null,
  samples jsonb not null,
  created_at timestamptz default now()
);

alter table public.accel_recordings enable row level security;

create policy "Users can view their own accel recordings"
  on public.accel_recordings for select
  using (auth.uid() = user_id);

create policy "Users can create their own accel recordings"
  on public.accel_recordings for insert
  with check (auth.uid() = user_id);

create policy "Users can delete their own accel recordings"
  on public.accel_recordings for delete
  using (auth.uid() = user_id);
