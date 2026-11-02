-- Saving the todo order used to take one UPDATE request per todo (the
-- app sent sort_order = index for every row in the list, in parallel).
-- This does the same in a single call and a single statement, and only
-- writes the rows whose position actually changed.
--
-- security invoker: RLS still decides which rows the caller may update,
-- and guard_todo_sharing (039) still keeps assignees from reordering
-- someone else's todo, so passing ids you don't own is a no-op for them.
create or replace function public.reorder_todos(ids uuid[])
returns void
language sql
security invoker
set search_path = public
as $$
  update public.todos t
     set sort_order = o.idx - 1
    from unnest(ids) with ordinality as o(id, idx)
   where t.id = o.id
     and t.sort_order is distinct from o.idx - 1;
$$;

grant execute on function public.reorder_todos(uuid[]) to authenticated;
