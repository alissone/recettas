-- Purchase categories ("Importancia"), same structure as todo_categories
create table public.purchase_categories (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  color_value bigint not null default 4294937666,
  created_at timestamptz default now()
);

alter table public.purchase_categories enable row level security;

create policy "Users can view their own purchase categories"
  on public.purchase_categories for select
  using (auth.uid() = user_id);

create policy "Users can create their own purchase categories"
  on public.purchase_categories for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own purchase categories"
  on public.purchase_categories for update
  using (auth.uid() = user_id);

create policy "Users can delete their own purchase categories"
  on public.purchase_categories for delete
  using (auth.uid() = user_id);

-- Purchases: Data, Item, Valor (BRL), Local, Importancia (category)
create table public.purchases (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  purchase_date date not null,
  item text not null,
  valor numeric(12, 2) not null,
  local text,
  category_id uuid references public.purchase_categories(id) on delete set null,
  created_at timestamptz default now()
);

create index purchases_user_date_idx
  on public.purchases (user_id, purchase_date desc);

alter table public.purchases enable row level security;

create policy "Users can view their own purchases"
  on public.purchases for select
  using (auth.uid() = user_id);

create policy "Users can create their own purchases"
  on public.purchases for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own purchases"
  on public.purchases for update
  using (auth.uid() = user_id);

create policy "Users can delete their own purchases"
  on public.purchases for delete
  using (auth.uid() = user_id);
