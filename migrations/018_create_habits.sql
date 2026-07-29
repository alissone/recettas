-- Custom habits and their daily logs. A habit's goal is either a
-- duration (goal_target in minutes) or a counter (goal_target repeats of
-- goal_unit), checked over a daily / weekly / monthly period. The
-- current value is never stored: it is the sum of habit_logs.value over
-- the period.
--
-- icon_name is a key into the app's curated kHabitIcons map, not a font
-- code point, because Flutter's icon tree shaking only keeps glyphs
-- reachable through const IconData references - a runtime-built
-- IconData(codePoint) renders as a blank box in release builds.
-- color_value follows the categories convention: ARGB in a bigint,
-- because 0xFFFF8C42 overflows int4.
create table public.habits (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  description text,
  icon_name text not null default 'check_circle',
  color_value bigint not null default 4294937666,
  -- Object key inside the "habits" storage bucket.
  image_path text,
  goal_type text not null default 'counter'
    check (goal_type in ('counter', 'duration')),
  -- Repeats for counter goals, minutes for duration goals.
  goal_target numeric(10, 2) not null default 1 check (goal_target > 0),
  -- Label for counter goals ("copos", "páginas"); null means "vezes".
  goal_unit text,
  period text not null default 'daily'
    check (period in ('daily', 'weekly', 'monthly')),
  is_archived boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz default now()
);

create index habits_user_idx
  on public.habits (user_id, is_archived, sort_order);

alter table public.habits enable row level security;

create policy "Users can view their own habits"
  on public.habits for select
  using (auth.uid() = user_id);

create policy "Users can create their own habits"
  on public.habits for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own habits"
  on public.habits for update
  using (auth.uid() = user_id);

create policy "Users can delete their own habits"
  on public.habits for delete
  using (auth.uid() = user_id);

-- One row per logged amount. Several rows a day are normal (15 minutes
-- in the morning plus 20 in the evening); the period total is their sum.
create table public.habit_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  habit_id uuid references public.habits(id) on delete cascade not null,
  log_date date not null,
  -- Repeats for counter goals, minutes for duration goals.
  value numeric(10, 2) not null default 1 check (value > 0),
  created_at timestamptz default now()
);

create index habit_logs_habit_date_idx
  on public.habit_logs (habit_id, log_date);

create index habit_logs_user_date_idx
  on public.habit_logs (user_id, log_date desc);

alter table public.habit_logs enable row level security;

create policy "Users can view their own habit logs"
  on public.habit_logs for select
  using (auth.uid() = user_id);

create policy "Users can create their own habit logs"
  on public.habit_logs for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own habit logs"
  on public.habit_logs for update
  using (auth.uid() = user_id);

create policy "Users can delete their own habit logs"
  on public.habit_logs for delete
  using (auth.uid() = user_id);
