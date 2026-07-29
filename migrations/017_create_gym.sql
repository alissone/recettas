-- Gym: a shared exercise catalog (populated by hand, one photo each in
-- the "habits" storage bucket) plus one row per exercise done per day.
--
-- Drop sets are explicitly out of scope: the same weight is used for
-- every set of an exercise on a given day, so a single weight column is
-- correct. image_path is seeded by hand after uploading the photo
-- through the Supabase dashboard; the app never writes to the catalog.
create table public.exercises (
  id uuid default gen_random_uuid() primary key,
  -- Null for the shared catalog; set for exercises a user added in-app.
  user_id uuid references public.profiles(id) on delete cascade,
  name text not null,
  description text,
  muscle_group text,
  -- Object key inside the "habits" storage bucket.
  image_path text,
  sort_order integer not null default 0,
  created_at timestamptz default now()
);

create index exercises_order_idx
  on public.exercises (sort_order, lower(name));

alter table public.exercises enable row level security;

create policy "Exercises are viewable by everyone"
  on public.exercises for select
  using (true);

create policy "Users can create their own exercises"
  on public.exercises for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own exercises"
  on public.exercises for update
  using (auth.uid() = user_id);

create policy "Users can delete their own exercises"
  on public.exercises for delete
  using (auth.uid() = user_id);

-- One row per exercise per day: sets x reps at a single weight in kg
-- (null for bodyweight work). The unique index below lets the app upsert
-- on (user_id, entry_date, exercise_id) instead of read-then-write, so
-- re-saving a day's entry is idempotent.
create table public.gym_entries (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  entry_date date not null,
  exercise_id uuid references public.exercises(id) on delete cascade not null,
  sets integer not null default 1 check (sets > 0),
  reps integer not null default 1 check (reps > 0),
  weight numeric(6, 2) check (weight >= 0),
  notes text,
  created_at timestamptz default now()
);

create unique index gym_entries_user_date_exercise_idx
  on public.gym_entries (user_id, entry_date, exercise_id);

create index gym_entries_user_date_idx
  on public.gym_entries (user_id, entry_date desc);

alter table public.gym_entries enable row level security;

create policy "Users can view their own gym entries"
  on public.gym_entries for select
  using (auth.uid() = user_id);

create policy "Users can create their own gym entries"
  on public.gym_entries for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own gym entries"
  on public.gym_entries for update
  using (auth.uid() = user_id);

create policy "Users can delete their own gym entries"
  on public.gym_entries for delete
  using (auth.uid() = user_id);
