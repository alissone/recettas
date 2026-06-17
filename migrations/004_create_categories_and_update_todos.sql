-- Create categories table for user-defined task categories
create table public.todo_categories (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  color_value bigint not null default 4294937666,
  created_at timestamptz default now()
);

alter table public.todo_categories enable row level security;

create policy "Users can view their own categories"
  on public.todo_categories for select
  using (auth.uid() = user_id);

create policy "Users can create their own categories"
  on public.todo_categories for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own categories"
  on public.todo_categories for update
  using (auth.uid() = user_id);

create policy "Users can delete their own categories"
  on public.todo_categories for delete
  using (auth.uid() = user_id);

-- Add category reference and manual sort order to todos
alter table public.todos
  add column category_id uuid references public.todo_categories(id) on delete set null,
  add column sort_order integer not null default 0;
