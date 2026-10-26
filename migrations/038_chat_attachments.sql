-- File attachments on chat messages. An attachment is a message whose
-- file_* columns are set; `content` holds a short text ("📎 name.pdf")
-- so the inbox preview, the notification banner and old clients keep
-- working unchanged.
alter table public.chat_messages
  add column file_name text,
  add column file_size bigint,
  add column file_mime text,
  -- Path in the "chat-files" bucket: "<room_id>/<message_id>".
  add column file_path text;

-- Private bucket, 25 MB cap per object. Unlike cloud-files (037), both
-- members of the room can read and write: access follows the room, which
-- is the first folder of the path.
insert into storage.buckets (id, name, public, file_size_limit)
values ('chat-files', 'chat-files', false, 26214400)
on conflict (id) do nothing;

create policy "Chat members can upload attachments"
  on storage.objects for insert
  with check (
    bucket_id = 'chat-files'
    and public.is_chat_member(((storage.foldername(name))[1])::uuid)
  );

-- Needed for upsert: a retried upload overwrites the partial one.
create policy "Chat members can update attachments"
  on storage.objects for update
  using (
    bucket_id = 'chat-files'
    and public.is_chat_member(((storage.foldername(name))[1])::uuid)
  );

create policy "Chat members can read attachments"
  on storage.objects for select
  using (
    bucket_id = 'chat-files'
    and public.is_chat_member(((storage.foldername(name))[1])::uuid)
  );
