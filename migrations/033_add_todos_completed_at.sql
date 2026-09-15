-- Track when a todo was marked done, so completed todos from a previous
-- day can stop being shown (and stop being fetched at all) once the day
-- they were completed on has passed.
alter table public.todos
  add column completed_at timestamptz;
