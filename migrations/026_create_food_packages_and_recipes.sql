-- Two ways of logging a food that isn't "N grams of one ingredient".
--
-- A package ("pacote") is an ingredient plus a predetermined net weight:
-- the small and the large pack of the same biscuits hold identical
-- values per 100 g, so the nutrients stay on public.foods and only the
-- weight lives here. Logging one writes an ordinary food_entries row
-- with amount = package.amount x however many packs were eaten, and
-- remembers which package it came from so the log can say "1 x Pacote
-- pequeno" instead of a bare 140 g.
--
-- A recipe ("receita") is several ingredients, each with its own weight.
-- Its nutrients are the sum of the ingredients', spread over the weight
-- of the finished dish, so a recipe entry stores the recipe id and how
-- much of the dish was eaten.
create table public.food_packages (
  id uuid default gen_random_uuid() primary key,
  -- Null for shared packages seeded in SQL; set for a user's own.
  user_id uuid references public.profiles(id) on delete cascade,
  food_id uuid references public.foods(id) on delete cascade not null,
  -- "Pacote pequeno", "Lata", "Barra". Optional: the weight alone is
  -- already a usable label.
  name text,
  -- In the food's base_unit, so a 350 ml can and a 140 g pack are both
  -- expressed in whatever their ingredient is catalogued in.
  amount numeric(10, 3) not null check (amount > 0),
  created_at timestamptz default now()
);

create index food_packages_food_idx on public.food_packages (food_id);

alter table public.food_packages enable row level security;

create policy "Food packages are viewable by everyone"
  on public.food_packages for select
  using (true);

create policy "Users can create their own food packages"
  on public.food_packages for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own food packages"
  on public.food_packages for update
  using (auth.uid() = user_id);

create policy "Users can delete their own food packages"
  on public.food_packages for delete
  using (auth.uid() = user_id);

-- Named public.food_recipes, not public.recipes: that name is taken by
-- the cooking recipes (free-text sections, no nutrient data) the app
-- shows on the "Receitas" tab. The two are deliberately unrelated.
create table public.food_recipes (
  id uuid default gen_random_uuid() primary key,
  -- Null for shared recipes seeded in SQL; set for a user's own.
  user_id uuid references public.profiles(id) on delete cascade,
  name text not null,
  -- Weight of the finished dish when it differs from the sum of the
  -- ingredients - water boils off, dough loses moisture. Null means
  -- "nothing was lost", i.e. the sum of the ingredients. It never
  -- changes how much of each nutrient the recipe holds, only how
  -- concentrated they are per gram served.
  yield_amount numeric(10, 3) check (yield_amount > 0),
  -- Object key inside the "habits" storage bucket.
  image_path text,
  created_at timestamptz default now()
);

create index food_recipes_name_idx on public.food_recipes (lower(name));

alter table public.food_recipes enable row level security;

create policy "Food recipes are viewable by everyone"
  on public.food_recipes for select
  using (true);

create policy "Users can create their own food recipes"
  on public.food_recipes for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own food recipes"
  on public.food_recipes for update
  using (auth.uid() = user_id);

create policy "Users can delete their own food recipes"
  on public.food_recipes for delete
  using (auth.uid() = user_id);

-- One row per ingredient. amount is in the ingredient's own base_unit;
-- as everywhere else in the nutrition schema, ml and g are added up as
-- if they were the same thing rather than converted by density.
create table public.food_recipe_items (
  id uuid default gen_random_uuid() primary key,
  recipe_id uuid references public.food_recipes(id) on delete cascade not null,
  food_id uuid references public.foods(id) on delete cascade not null,
  amount numeric(10, 3) not null check (amount > 0),
  sort_order integer not null default 0,
  created_at timestamptz default now()
);

-- An ingredient appears once per recipe: listing flour twice would be a
-- data entry slip, not two different things to sum.
create unique index food_recipe_items_recipe_food_idx
  on public.food_recipe_items (recipe_id, food_id);

alter table public.food_recipe_items enable row level security;

create policy "Food recipe items are viewable by everyone"
  on public.food_recipe_items for select
  using (true);

create policy "Users can create their own food recipe items"
  on public.food_recipe_items for insert
  with check (
    exists (
      select 1 from public.food_recipes r
      where r.id = food_recipe_items.recipe_id and r.user_id = auth.uid()
    )
  );

create policy "Users can update their own food recipe items"
  on public.food_recipe_items for update
  using (
    exists (
      select 1 from public.food_recipes r
      where r.id = food_recipe_items.recipe_id and r.user_id = auth.uid()
    )
  );

create policy "Users can delete their own food recipe items"
  on public.food_recipe_items for delete
  using (
    exists (
      select 1 from public.food_recipes r
      where r.id = food_recipe_items.recipe_id and r.user_id = auth.uid()
    )
  );

-- A log row now points at either an ingredient or a recipe. amount keeps
-- meaning the same thing in both cases: how much was eaten, in the
-- ingredient's base_unit or in grams of the finished dish.
alter table public.food_entries
  alter column food_id drop not null;

alter table public.food_entries
  add column recipe_id uuid references public.food_recipes(id) on delete cascade,
  -- Which package the amount came from, for display only - the nutrients
  -- come from food_id either way. Nulled rather than cascaded when the
  -- package definition is deleted, so the entry keeps its weight.
  add column package_id uuid references public.food_packages(id) on delete set null;

alter table public.food_entries
  add constraint food_entries_source_check
    check (num_nonnulls(food_id, recipe_id) = 1),
  add constraint food_entries_package_needs_food_check
    check (package_id is null or food_id is not null);
