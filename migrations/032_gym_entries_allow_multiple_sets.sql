-- Drop sets are now in scope: an exercise can be logged more than once a
-- day, each row its own sets x reps at its own weight (e.g. a top set
-- followed by lighter drop sets). The unique index from migration 017
-- forced exactly one row per (user, day, exercise), so it has to go;
-- the app now inserts a new row per set group instead of upserting.
drop index if exists public.gym_entries_user_date_exercise_idx;

-- Query pattern shifts from "the one row for this exercise today" to
-- "every row for this exercise today", so index the pair directly
-- instead of relying on the now-dropped unique index for that lookup.
create index if not exists gym_entries_user_date_exercise_idx
  on public.gym_entries (user_id, entry_date, exercise_id);
