-- Deleting a todo in the app now archives it instead of removing the row,
-- so history is kept. Archived todos are hidden from the list.
alter table public.todos
  add column is_archived boolean not null default false;
