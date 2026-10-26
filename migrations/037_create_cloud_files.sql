-- "Arquivos": a small personal drive for moving files between devices
-- (phone, web, ...), AirDrop-style but asynchronous - upload on one
-- device today, download on another tomorrow. Meant for small, temporary
-- files. The bytes live in the private "cloud-files" bucket under
-- "<user_id>/<file_id>" (no file name in the path, so renaming is just a
-- column update); this table holds the listing, and cloud_file_events
-- records which device uploaded and downloaded each file.
create table public.cloud_files (
  -- Generated on the client so the storage object and the row share it.
  id uuid primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  size_bytes bigint not null,
  mime_type text,
  storage_path text not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index cloud_files_user_created_idx
  on public.cloud_files (user_id, created_at desc);

alter table public.cloud_files enable row level security;

create policy "Users can view their own cloud files"
  on public.cloud_files for select
  using (auth.uid() = user_id);

create policy "Users can create their own cloud files"
  on public.cloud_files for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own cloud files"
  on public.cloud_files for update
  using (auth.uid() = user_id);

create policy "Users can delete their own cloud files"
  on public.cloud_files for delete
  using (auth.uid() = user_id);

-- One row per upload / download, with the device that did it. Deleted
-- along with the file.
create table public.cloud_file_events (
  id uuid primary key default gen_random_uuid(),
  file_id uuid references public.cloud_files(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  kind text not null check (kind in ('upload', 'download')),
  -- Human-readable, e.g. "Pixel 8 (Android)" or "Chrome (Web)".
  device_name text not null,
  created_at timestamptz default now()
);

create index cloud_file_events_file_idx
  on public.cloud_file_events (file_id, created_at);

alter table public.cloud_file_events enable row level security;

create policy "Users can view their own cloud file events"
  on public.cloud_file_events for select
  using (auth.uid() = user_id);

create policy "Users can create their own cloud file events"
  on public.cloud_file_events for insert
  with check (auth.uid() = user_id);

-- Private bucket, 25 MB cap per object. Keyed "<user_id>/<file_id>".
insert into storage.buckets (id, name, public, file_size_limit)
values ('cloud-files', 'cloud-files', false, 26214400)
on conflict (id) do nothing;

create policy "Users can upload their own cloud files"
  on storage.objects for insert
  with check (
    bucket_id = 'cloud-files'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Needed for upsert: a retried upload overwrites the partial one.
create policy "Users can update their own cloud files objects"
  on storage.objects for update
  using (
    bucket_id = 'cloud-files'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can view their own cloud files objects"
  on storage.objects for select
  using (
    bucket_id = 'cloud-files'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their own cloud files objects"
  on storage.objects for delete
  using (
    bucket_id = 'cloud-files'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
