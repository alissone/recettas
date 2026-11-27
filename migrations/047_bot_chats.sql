-- Chats with the local assistant (Chat tab -> robot button).
--
-- Each bot chat is a private conversation of one user with the local LLM
-- on the PC (transcriber/worker.py + transcriber/bot_chat.py, same
-- C:\dev\locallama model as the voice-note assistant). Everything is kept
-- here, so a conversation survives closing the app, like chat_messages.
--
-- Flow: the app inserts a role='user' message with status 'requested';
-- the worker claims it ('processing'), sends the chat history to the
-- model, inserts the role='assistant' reply and marks the user message
-- 'done' (or 'error' + error_message). Setting 'requested' again retries.
--
-- context: hidden data the app attached to a message (e.g. the todo list,
-- in the order the app shows it, for "Resumir meus afazeres"). It goes to
-- the model with the message but the bubble only shows `content`.

create table public.bot_chats (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null
    default auth.uid(),
  title text not null default 'Assistente',
  -- Denormalized from the newest message for the inbox (see trigger).
  last_message text,
  last_message_at timestamptz,
  last_role text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index bot_chats_user_idx on public.bot_chats (user_id, updated_at desc);

create table public.bot_messages (
  id uuid default gen_random_uuid() primary key,
  chat_id uuid references public.bot_chats(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null
    default auth.uid(),
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  context text,
  -- Only on user messages: where the worker is with the answer.
  status text check (status in ('requested', 'processing', 'done', 'error')),
  error_message text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index bot_messages_chat_idx on public.bot_messages (chat_id, created_at);
create index bot_messages_status_idx on public.bot_messages (status)
  where status in ('requested', 'processing');

alter table public.bot_chats enable row level security;
alter table public.bot_messages enable row level security;

create policy "Users manage their bot chats"
  on public.bot_chats for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users read their bot messages"
  on public.bot_messages for select
  using (auth.uid() = user_id);

-- The app only ever writes the user's side; replies come from the worker
-- (service role, bypasses RLS).
create policy "Users send messages in their bot chats"
  on public.bot_messages for insert
  with check (
    auth.uid() = user_id
    and role = 'user'
    and exists (select 1 from public.bot_chats c
                where c.id = chat_id and c.user_id = auth.uid())
  );

-- Retry / cancel: the app moves its own message's status.
create policy "Users update their bot messages"
  on public.bot_messages for update
  using (auth.uid() = user_id and role = 'user')
  with check (auth.uid() = user_id and role = 'user');

create or replace function public.bump_bot_chat()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.bot_chats
     set last_message = new.content,
         last_message_at = new.created_at,
         last_role = new.role,
         updated_at = now()
   where id = new.chat_id;
  return new;
end;
$$;

create trigger bot_messages_bump_chat
  after insert on public.bot_messages
  for each row execute function public.bump_bot_chat();

-- Realtime: bot_chats drives the inbox, bot_messages the open chat (and
-- wakes the worker).
alter table public.bot_chats replica identity full;
alter table public.bot_messages replica identity full;

alter publication supabase_realtime add table public.bot_chats;
alter publication supabase_realtime add table public.bot_messages;
