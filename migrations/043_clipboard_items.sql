-- Shared clipboard: whatever the user "sends" from one device (app or web)
-- shows up live on every other device signed in to the same account. Only
-- the latest few items are kept; the clients prune older ones after each
-- send (rows and, for images, the storage object).
create table public.clipboard_items (
  -- Generated on the client so the storage object and the row share it.
  id uuid primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  kind text not null check (kind in ('text', 'image')),
  -- Set for kind = 'text'.
  content text,
  -- Set for kind = 'image': object in the "clipboard" bucket,
  -- "<user_id>/<id>".
  storage_path text,
  mime_type text,
  size_bytes bigint,
  created_at timestamptz default now(),
  check (
    (kind = 'text' and content is not null)
    or (kind = 'image' and storage_path is not null)
  )
);

create index clipboard_items_user_created_idx
  on public.clipboard_items (user_id, created_at desc);

alter table public.clipboard_items enable row level security;

create policy "Users can view their own clipboard items"
  on public.clipboard_items for select
  using (auth.uid() = user_id);

create policy "Users can create their own clipboard items"
  on public.clipboard_items for insert
  with check (auth.uid() = user_id);

create policy "Users can delete their own clipboard items"
  on public.clipboard_items for delete
  using (auth.uid() = user_id);

-- Devices subscribe to inserts and deletes for the live preview.
alter publication supabase_realtime add table public.clipboard_items;

-- Private bucket for clipboard images, 10 MB per object, keyed
-- "<user_id>/<item_id>".
insert into storage.buckets (id, name, public, file_size_limit)
values ('clipboard', 'clipboard', false, 10485760)
on conflict (id) do nothing;

create policy "Users can upload their own clipboard images"
  on storage.objects for insert
  with check (
    bucket_id = 'clipboard'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can view their own clipboard images"
  on storage.objects for select
  using (
    bucket_id = 'clipboard'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their own clipboard images"
  on storage.objects for delete
  using (
    bucket_id = 'clipboard'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
