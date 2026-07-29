-- Food catalog and the daily food log. Foods are shared: rows with a
-- null user_id are the hand-seeded global catalog, rows with a user_id
-- were added in-app by that user.
--
-- Nutrient values are stored tall (one row per nutrient) rather than as
-- jsonb so every hand-written insert is validated against
-- public.nutrients by a foreign key. A typo in a jsonb key would insert
-- cleanly and then silently vanish from every chart.
create table public.foods (
  id uuid default gen_random_uuid() primary key,
  -- Null for the shared catalog; set for foods a user added in-app.
  user_id uuid references public.profiles(id) on delete cascade,
  name text not null,
  brand text,
  -- Nutrient values are per base_amount of base_unit, so a liquid can be
  -- catalogued per 100 ml instead of per 100 g. No ml/g density
  -- conversion happens anywhere: this is a divisor plus a display label.
  base_amount numeric(10, 3) not null default 100 check (base_amount > 0),
  base_unit text not null default 'g' check (base_unit in ('g', 'ml')),
  -- Object key inside the "habits" storage bucket.
  image_path text,
  created_at timestamptz default now()
);

create index foods_name_idx on public.foods (lower(name));

alter table public.foods enable row level security;

create policy "Foods are viewable by everyone"
  on public.foods for select
  using (true);

create policy "Users can create their own foods"
  on public.foods for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own foods"
  on public.foods for update
  using (auth.uid() = user_id);

create policy "Users can delete their own foods"
  on public.foods for delete
  using (auth.uid() = user_id);

-- One row per (food, nutrient). amount is in the nutrient's own unit,
-- per the food's base_amount.
create table public.food_nutrients (
  id uuid default gen_random_uuid() primary key,
  food_id uuid references public.foods(id) on delete cascade not null,
  nutrient_id text references public.nutrients(id) not null,
  amount numeric(12, 4) not null default 0 check (amount >= 0),
  created_at timestamptz default now()
);

create unique index food_nutrients_food_nutrient_idx
  on public.food_nutrients (food_id, nutrient_id);

alter table public.food_nutrients enable row level security;

create policy "Food nutrients are viewable by everyone"
  on public.food_nutrients for select
  using (true);

create policy "Users can create their own food nutrients"
  on public.food_nutrients for insert
  with check (
    exists (
      select 1 from public.foods f
      where f.id = food_nutrients.food_id and f.user_id = auth.uid()
    )
  );

create policy "Users can update their own food nutrients"
  on public.food_nutrients for update
  using (
    exists (
      select 1 from public.foods f
      where f.id = food_nutrients.food_id and f.user_id = auth.uid()
    )
  );

create policy "Users can delete their own food nutrients"
  on public.food_nutrients for delete
  using (
    exists (
      select 1 from public.foods f
      where f.id = food_nutrients.food_id and f.user_id = auth.uid()
    )
  );

-- Daily food log: one row per portion eaten. Several rows of the same
-- food on the same day are normal.
create table public.food_entries (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  entry_date date not null,
  food_id uuid references public.foods(id) on delete cascade not null,
  -- In the food's base_unit (g or ml).
  amount numeric(10, 2) not null check (amount > 0),
  created_at timestamptz default now()
);

create index food_entries_user_date_idx
  on public.food_entries (user_id, entry_date desc);

alter table public.food_entries enable row level security;

create policy "Users can view their own food entries"
  on public.food_entries for select
  using (auth.uid() = user_id);

create policy "Users can create their own food entries"
  on public.food_entries for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own food entries"
  on public.food_entries for update
  using (auth.uid() = user_id);

create policy "Users can delete their own food entries"
  on public.food_entries for delete
  using (auth.uid() = user_id);
