-- Queue of receipt images waiting to be processed by the local
-- llama-server (vision). Images live in the "receipts" storage bucket;
-- each job tracks one image and its processing status.
create table public.receipt_jobs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  image_path text not null,
  status text not null default 'queued'
    check (status in ('queued', 'processing', 'done', 'error')),
  error_message text,
  items_count integer,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.receipt_jobs enable row level security;

create policy "Users can view their own receipt jobs"
  on public.receipt_jobs for select
  using (auth.uid() = user_id);

create policy "Users can create their own receipt jobs"
  on public.receipt_jobs for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own receipt jobs"
  on public.receipt_jobs for update
  using (auth.uid() = user_id);

create policy "Users can delete their own receipt jobs"
  on public.receipt_jobs for delete
  using (auth.uid() = user_id);

-- Link purchases back to the job that generated them
alter table public.purchases
  add column receipt_job_id uuid references public.receipt_jobs(id) on delete set null;

-- Private storage bucket for receipt photos.
-- Objects are stored as "<user_id>/<job_id>.jpg" so the first path
-- segment can be used for per-user access control.
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

create policy "Users can upload their own receipts"
  on storage.objects for insert
  with check (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can view their own receipts"
  on storage.objects for select
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their own receipts"
  on storage.objects for delete
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
