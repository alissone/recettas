-- One-to-one chat between two accounts, keyed by email like
-- list_invites (012): you only need the other person's address once,
-- to open the room. The room then belongs to both addresses forever,
-- and works even if the other side hasn't signed up yet - their rows
-- become visible the moment they create an account with that email.

create table public.chat_rooms (
  id uuid default gen_random_uuid() primary key,
  -- Nulled rather than cascaded when the creator's account goes away:
  -- the other member keeps the conversation.
  created_by uuid references public.profiles(id) on delete set null,
  -- Exactly two lowercased addresses, sorted. The normalizing trigger
  -- below guarantees that form, which is what makes the unique index a
  -- real "one room per pair" constraint no matter who opens it first.
  member_emails text[] not null,
  -- Denormalized from the newest message so the inbox can sort and
  -- render every row without a per-room query.
  last_message text,
  last_message_at timestamptz,
  last_sender_email text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index chat_rooms_members_idx
  on public.chat_rooms (member_emails);

create index chat_rooms_updated_idx
  on public.chat_rooms (updated_at desc);

create table public.chat_messages (
  id uuid default gen_random_uuid() primary key,
  room_id uuid references public.chat_rooms(id) on delete cascade not null,
  sender_id uuid references public.profiles(id) on delete set null,
  -- Kept alongside sender_id so a message still renders on the right
  -- side after the sender's profile row is gone.
  sender_email text not null,
  content text not null,
  created_at timestamptz default now()
);

create index chat_messages_room_idx
  on public.chat_messages (room_id, created_at desc);

-- Canonical membership: lowercased, trimmed, deduplicated, sorted.
-- Runs before the RLS WITH CHECK, so the policies below compare
-- against the normalized array.
create or replace function public.normalize_chat_room_members()
returns trigger
language plpgsql
as $$
begin
  select array_agg(distinct lower(trim(e)) order by lower(trim(e)))
    into new.member_emails
    from unnest(new.member_emails) as e
   where trim(e) <> '';

  if coalesce(array_length(new.member_emails, 1), 0) <> 2 then
    raise exception 'A chat room needs exactly two distinct e-mails';
  end if;

  return new;
end;
$$;

create trigger chat_rooms_normalize_members
  before insert or update on public.chat_rooms
  for each row execute function public.normalize_chat_room_members();

-- True when the signed-in user is one of the room's two members.
-- security definer so chat_messages' policies don't re-enter
-- chat_rooms' own RLS on every row.
create or replace function public.is_chat_member(room uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_rooms
    where id = room
      and lower(auth.jwt() ->> 'email') = any(member_emails)
  );
$$;

-- Same test, by address: used by the profiles policy so each side can
-- read the other's display name.
create or replace function public.shares_chat_with_email(other_email text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_rooms
    where lower(auth.jwt() ->> 'email') = any(member_emails)
      and lower(other_email) = any(member_emails)
  );
$$;

alter table public.chat_rooms enable row level security;
alter table public.chat_messages enable row level security;

create policy "Members can view their chat rooms"
  on public.chat_rooms for select
  using (lower(auth.jwt() ->> 'email') = any(member_emails));

-- Opening a room is only ever done for yourself and one other person.
create policy "Users can open a chat room they belong to"
  on public.chat_rooms for insert
  with check (
    auth.uid() = created_by
    and lower(auth.jwt() ->> 'email') = any(member_emails)
  );

-- Rooms are never edited or removed from the client: the inbox keeps
-- them forever, and the last_message columns are maintained by the
-- security definer trigger below.

create policy "Members can read a room's messages"
  on public.chat_messages for select
  using (public.is_chat_member(room_id));

create policy "Members can send messages in their rooms"
  on public.chat_messages for insert
  with check (
    public.is_chat_member(room_id)
    and auth.uid() = sender_id
    and lower(sender_email) = lower(auth.jwt() ->> 'email')
  );

-- Both sides can see each other's profile, for the name on the inbox
-- row and the chat header.
create policy "Users can view profiles of their chat partners"
  on public.profiles for select
  using (email is not null and public.shares_chat_with_email(email));

-- Newest message, copied onto the room so the inbox stream carries
-- everything it renders. security definer because members have no
-- update policy on chat_rooms.
create or replace function public.bump_chat_room()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_rooms
     set last_message = new.content,
         last_message_at = new.created_at,
         last_sender_email = new.sender_email,
         updated_at = now()
   where id = new.room_id;
  return new;
end;
$$;

create trigger chat_messages_bump_room
  after insert on public.chat_messages
  for each row execute function public.bump_chat_room();

-- Realtime. chat_rooms drives the inbox and the in-app notification
-- banner; chat_messages drives the open conversation. replica identity
-- full is what lets Realtime run the SELECT policies against the old
-- row on an UPDATE - without it the room bumps never reach the client.
alter table public.chat_rooms replica identity full;
alter table public.chat_messages replica identity full;

alter publication supabase_realtime add table public.chat_rooms;
alter publication supabase_realtime add table public.chat_messages;
