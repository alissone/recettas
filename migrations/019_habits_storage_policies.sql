-- The "habits" bucket was created from the Supabase dashboard, so this
-- file only normalizes it: a private bucket whose objects are keyed
-- "<user_id>/<kind>/<id>.jpg", readable by any signed-in account
-- because food, exercise and habit pictures are a shared catalog, but
-- writable only inside the uploader's own folder.
--
-- Before running this, list what the dashboard already created so the
-- policies below don't end up duplicated under different names:
--   select policyname, cmd from pg_policies
--    where schemaname = 'storage' and tablename = 'objects';
--
-- "drop policy if exists" is used for the same reason: unlike every
-- other migration here, this one runs against state created out of band.
insert into storage.buckets (id, name, public)
values ('habits', 'habits', false)
on conflict (id) do nothing;

drop policy if exists "Signed-in users can view habit images" on storage.objects;
drop policy if exists "Users can upload their own habit images" on storage.objects;
drop policy if exists "Users can update their own habit images" on storage.objects;
drop policy if exists "Users can delete their own habit images" on storage.objects;

create policy "Signed-in users can view habit images"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'habits');

create policy "Users can upload their own habit images"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'habits'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can update their own habit images"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'habits'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their own habit images"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'habits'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
