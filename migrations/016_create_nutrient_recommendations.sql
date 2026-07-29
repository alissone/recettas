-- Named daily nutrient targets ("Adulto homem", "Gestante", "Cetogênica",
-- "Atleta", ...). Sets with a null user_id are shared presets seeded by
-- hand; a user can also build their own.
--
-- unit is kept per row instead of read from public.nutrients so a target
-- can be expressed differently from the food data (vitamin A in iu
-- instead of ug, for example). The set a user is currently following is
-- stored on their profile.
create table public.nutrient_recommendation_sets (
  id uuid default gen_random_uuid() primary key,
  -- Null for shared presets; set for a user's own list.
  user_id uuid references public.profiles(id) on delete cascade,
  name text not null,
  description text,
  created_at timestamptz default now()
);

alter table public.nutrient_recommendation_sets enable row level security;

create policy "Recommendation sets are viewable by everyone"
  on public.nutrient_recommendation_sets for select
  using (true);

create policy "Users can create their own recommendation sets"
  on public.nutrient_recommendation_sets for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own recommendation sets"
  on public.nutrient_recommendation_sets for update
  using (auth.uid() = user_id);

create policy "Users can delete their own recommendation sets"
  on public.nutrient_recommendation_sets for delete
  using (auth.uid() = user_id);

create table public.nutrient_recommendations (
  id uuid default gen_random_uuid() primary key,
  set_id uuid references public.nutrient_recommendation_sets(id)
    on delete cascade not null,
  nutrient_id text references public.nutrients(id) not null,
  amount numeric(12, 4) not null check (amount >= 0),
  unit text not null
    check (unit in ('kcal', 'kj', 'g', 'mg', 'ug', 'iu', 'l', 'ml', 'percent')),
  created_at timestamptz default now()
);

create unique index nutrient_recommendations_set_nutrient_idx
  on public.nutrient_recommendations (set_id, nutrient_id);

alter table public.nutrient_recommendations enable row level security;

create policy "Recommendations are viewable by everyone"
  on public.nutrient_recommendations for select
  using (true);

create policy "Users can create their own recommendations"
  on public.nutrient_recommendations for insert
  with check (
    exists (
      select 1 from public.nutrient_recommendation_sets s
      where s.id = nutrient_recommendations.set_id and s.user_id = auth.uid()
    )
  );

create policy "Users can update their own recommendations"
  on public.nutrient_recommendations for update
  using (
    exists (
      select 1 from public.nutrient_recommendation_sets s
      where s.id = nutrient_recommendations.set_id and s.user_id = auth.uid()
    )
  );

create policy "Users can delete their own recommendations"
  on public.nutrient_recommendations for delete
  using (
    exists (
      select 1 from public.nutrient_recommendation_sets s
      where s.id = nutrient_recommendations.set_id and s.user_id = auth.uid()
    )
  );

-- Which named set the user is currently following.
alter table public.profiles
  add column active_recommendation_set_id uuid
    references public.nutrient_recommendation_sets(id) on delete set null;

-- Starter shared preset: the Brazilian food-label reference values
-- (ANVISA "Valores Diários de referência", 2000 kcal diet). Meant to be
-- copied and edited, not treated as personal advice. The id is fixed so
-- later updates can target it.
insert into public.nutrient_recommendation_sets (id, user_id, name, description)
values (
  '00000000-0000-0000-0000-0000000000d0',
  null,
  'Adulto - VD ANVISA (2000 kcal)',
  'Valores Diários de referência usados na rotulagem brasileira.'
);

insert into public.nutrient_recommendations (set_id, nutrient_id, amount, unit)
values
  ('00000000-0000-0000-0000-0000000000d0', 'calories', 2000, 'kcal'),
  ('00000000-0000-0000-0000-0000000000d0', 'carbohydrates', 300, 'g'),
  ('00000000-0000-0000-0000-0000000000d0', 'protein', 75, 'g'),
  ('00000000-0000-0000-0000-0000000000d0', 'fat', 55, 'g'),
  ('00000000-0000-0000-0000-0000000000d0', 'saturatedFat', 22, 'g'),
  ('00000000-0000-0000-0000-0000000000d0', 'fiber', 25, 'g'),
  ('00000000-0000-0000-0000-0000000000d0', 'sodium', 2400, 'mg');
