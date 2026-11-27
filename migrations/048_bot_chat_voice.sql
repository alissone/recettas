-- Voice messages in the assistant chat (on top of 047).
--
-- The app records a WhatsApp-style audio, uploads it to the "bot-audio"
-- bucket and inserts a role='user' message with audio_path set and an
-- empty content. The worker transcribes it (Parakeet or WhisperX, chosen
-- per chat), writes the transcript into content, answers, and - because
-- the question was spoken - speaks the answer with Kokoro TTS, uploading
-- it next to the question and setting the reply's audio_path.

alter table public.bot_chats
  -- Speech to text for this chat: parakeet (fast, PT/EN auto-detected) or
  -- whisper (WhisperX, slower; stt_language says which language).
  add column stt_engine text not null default 'parakeet'
    check (stt_engine in ('parakeet', 'whisper')),
  add column stt_language text not null default 'pt'
    check (stt_language in ('pt', 'en')),
  -- Kokoro voice for spoken replies; its first letter is the language
  -- (a/b = English, p = Brazilian Portuguese).
  add column tts_voice text not null default 'pf_dora';

alter table public.bot_messages
  -- "<user_id>/<chat_id>/<message_id>.m4a" in the bot-audio bucket.
  add column audio_path text,
  add column audio_seconds real;

-- Private bucket; each user's folder is theirs (the worker uses the
-- service role). 10 MB is ~20 minutes of 64 kbps AAC.
insert into storage.buckets (id, name, public, file_size_limit)
values ('bot-audio', 'bot-audio', false, 10485760)
on conflict (id) do nothing;

create policy "Users upload their bot audio"
  on storage.objects for insert
  with check (
    bucket_id = 'bot-audio'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users read their bot audio"
  on storage.objects for select
  using (
    bucket_id = 'bot-audio'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users delete their bot audio"
  on storage.objects for delete
  using (
    bucket_id = 'bot-audio'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
