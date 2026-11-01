-- People ("Pessoas") and shared todos.
--
-- contacts is each user's private address book: an email plus the
-- nickname they type after "@" to tag that person on a todo. The nickname
-- only exists on the owner's side; it never touches the other account.
--
-- A todo whose text tags a contact lists that contact's account in
-- todos.assignee_ids, which gives them access to the row: it shows up in
-- their list too and either side can tick it.
--
-- todos.today_on is the "@today" pin: the local date the todo was marked
-- for. The app sorts it to the top while that date is today; afterwards
-- it falls back to its normal place in the list.

create table public.contacts (
  id uuid default gen_random_uuid() primary key,
  owner_id uuid references public.profiles(id) on delete cascade not null,
  email text not null,
  nickname text not null
    check (nickname <> '' and nickname !~ '[[:space:]@]'
           and lower(nickname) not in ('today', 'hoje')),
  -- The account behind `email`, filled by the triggers below. Null while
  -- that email hasn't signed up; tags on such a contact aren't shared.
  contact_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz default now()
);

create unique index contacts_owner_nickname_idx
  on public.contacts (owner_id, lower(nickname));

create unique index contacts_owner_email_idx
  on public.contacts (owner_id, lower(email));

alter table public.contacts enable row level security;

create policy "Users can view their own contacts"
  on public.contacts for select
  using (auth.uid() = owner_id);

create policy "Users can create their own contacts"
  on public.contacts for insert
  with check (auth.uid() = owner_id);

create policy "Users can update their own contacts"
  on public.contacts for update
  using (auth.uid() = owner_id);

create policy "Users can delete their own contacts"
  on public.contacts for delete
  using (auth.uid() = owner_id);

-- Resolves the email to an account. security definer: auth.users isn't
-- readable by clients.
create or replace function public.resolve_contact_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.email := lower(trim(new.email));
  new.contact_user_id := (
    select id from auth.users where lower(email) = new.email limit 1
  );
  return new;
end;
$$;

create trigger contacts_resolve_user
  before insert or update of email on public.contacts
  for each row execute function public.resolve_contact_user();

-- Someone saved as a contact before they had an account gets linked the
-- moment they sign up.
create or replace function public.link_contacts_to_new_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.contacts
     set contact_user_id = new.id
   where contact_user_id is null
     and email = lower(new.email);
  return new;
end;
$$;

create trigger profiles_link_contacts
  after insert on public.profiles
  for each row execute function public.link_contacts_to_new_profile();

-- Todos: assignees and the "@today" pin
alter table public.todos
  add column assignee_ids uuid[] not null default '{}',
  add column today_on date;

create index todos_assignee_ids_idx
  on public.todos using gin (assignee_ids);

drop policy "Users can view their own todos" on public.todos;
drop policy "Users can update their own todos" on public.todos;

create policy "Owners and assignees can view todos"
  on public.todos for select
  using (auth.uid() = user_id or auth.uid() = any(assignee_ids));

create policy "Owners and assignees can update todos"
  on public.todos for update
  using (auth.uid() = user_id or auth.uid() = any(assignee_ids));

-- Owners may only assign their own contacts that have an account (anything
-- else is silently dropped). Assignees share the task, not the owner's
-- list: they can tick it, edit its text and pin it for today, or remove
-- themselves (leave_todo below); category, order, archiving and the
-- assignee list stay the owner's.
create or replace function public.guard_todo_sharing()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and auth.uid() is not null
     and auth.uid() <> old.user_id then
    new.user_id := old.user_id;
    new.category_id := old.category_id;
    new.sort_order := old.sort_order;
    new.is_archived := old.is_archived;
    if new.assignee_ids is distinct from
       array_remove(old.assignee_ids, auth.uid()) then
      new.assignee_ids := old.assignee_ids;
    end if;
    return new;
  end if;

  new.assignee_ids := coalesce(array(
    select distinct c.contact_user_id
      from public.contacts c
     where c.owner_id = new.user_id
       and c.contact_user_id = any(new.assignee_ids)
  ), '{}');
  return new;
end;
$$;

create trigger todos_guard_sharing
  before insert or update on public.todos
  for each row execute function public.guard_todo_sharing();

-- "Deleting" a todo someone else tagged you on just takes you off it. A
-- plain update can't do this: once you're off the row, RLS no longer
-- lets you write it.
create or replace function public.leave_todo(todo_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.todos
     set assignee_ids = array_remove(assignee_ids, auth.uid())
   where id = todo_id
     and auth.uid() = any(assignee_ids);
$$;

grant execute on function public.leave_todo(uuid) to authenticated;
