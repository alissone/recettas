-- Shopping list ("Compras"): reminders of stuff to buy. Checking an item
-- registers a purchase (gasto) and links back to it via purchase_id.
create table public.shopping_items (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  item text not null,
  is_purchased boolean not null default false,
  purchase_id uuid references public.purchases(id) on delete set null,
  purchased_at timestamptz,
  created_at timestamptz default now()
);

create index shopping_items_user_idx
  on public.shopping_items (user_id, is_purchased, created_at desc);

alter table public.shopping_items enable row level security;

create policy "Users can view their own shopping items"
  on public.shopping_items for select
  using (auth.uid() = user_id);

create policy "Users can create their own shopping items"
  on public.shopping_items for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own shopping items"
  on public.shopping_items for update
  using (auth.uid() = user_id);

create policy "Users can delete their own shopping items"
  on public.shopping_items for delete
  using (auth.uid() = user_id);
