-- Reference catalog of every nutrient the app can track. Read-only for
-- everyone, like public.recipes: rows are seeded here and edited by hand
-- in the SQL editor.
--
-- It exists so hand-written food_nutrients inserts are validated by a
-- foreign key instead of a 62-value check constraint, and so the SQL
-- editor can show readable names and units next to the ids.
--
-- id is spelled exactly like the Dart NutrientId enum value (.name), so
-- it round-trips both ways with no conversion table. The same goes for
-- category and unit, which mirror NutrientCategory and NutrientUnit.
create table public.nutrients (
  id text primary key,
  name text not null,
  category text not null
    check (category in ('macronutrient', 'vitamin', 'mineral', 'aminoAcid',
                        'fattyAcid', 'sugar', 'sterol', 'phytochemical',
                        'other')),
  unit text not null
    check (unit in ('kcal', 'kj', 'g', 'mg', 'ug', 'iu', 'l', 'ml', 'percent')),
  -- Display order in the app; steps of 10 leave room to insert rows.
  sort_order integer not null default 0,
  -- Highlighted on the "Hábitos" summary card without expanding a group.
  is_primary boolean not null default false,
  created_at timestamptz default now()
);

alter table public.nutrients enable row level security;

create policy "Nutrients are viewable by everyone"
  on public.nutrients for select
  using (true);

insert into public.nutrients (id, name, category, unit, sort_order, is_primary)
values
  ('calories', 'Calorias', 'macronutrient', 'kcal', 10, true),
  ('kilojoules', 'Quilojoules', 'macronutrient', 'kj', 20, false),
  ('protein', 'Proteína', 'macronutrient', 'g', 30, true),
  ('carbohydrates', 'Carboidratos', 'macronutrient', 'g', 40, true),
  ('fat', 'Gorduras totais', 'macronutrient', 'g', 50, true),
  ('water', 'Água', 'macronutrient', 'g', 60, false),
  ('alcohol', 'Álcool', 'macronutrient', 'g', 70, false),
  ('fiber', 'Fibra alimentar', 'macronutrient', 'g', 80, true),
  ('solubleFiber', 'Fibra solúvel', 'macronutrient', 'g', 90, false),
  ('insolubleFiber', 'Fibra insolúvel', 'macronutrient', 'g', 100, false),
  ('sugar', 'Açúcares', 'sugar', 'g', 110, false),
  ('addedSugar', 'Açúcares adicionados', 'sugar', 'g', 120, false),
  ('starch', 'Amido', 'macronutrient', 'g', 130, false),
  ('saturatedFat', 'Gordura saturada', 'fattyAcid', 'g', 140, false),
  ('monounsaturatedFat', 'Gordura monoinsaturada', 'fattyAcid', 'g', 150, false),
  ('polyunsaturatedFat', 'Gordura poli-insaturada', 'fattyAcid', 'g', 160, false),
  ('transFat', 'Gordura trans', 'fattyAcid', 'g', 170, false),
  ('cholesterol', 'Colesterol', 'sterol', 'mg', 180, false),
  ('omega3', 'Ômega-3', 'fattyAcid', 'g', 190, false),
  ('omega6', 'Ômega-6', 'fattyAcid', 'g', 200, false),
  ('epa', 'EPA', 'fattyAcid', 'mg', 210, false),
  ('dha', 'DHA', 'fattyAcid', 'mg', 220, false),
  ('ala', 'ALA', 'fattyAcid', 'g', 230, false),
  ('tryptophan', 'Triptofano', 'aminoAcid', 'g', 240, false),
  ('threonine', 'Treonina', 'aminoAcid', 'g', 250, false),
  ('isoleucine', 'Isoleucina', 'aminoAcid', 'g', 260, false),
  ('leucine', 'Leucina', 'aminoAcid', 'g', 270, false),
  ('lysine', 'Lisina', 'aminoAcid', 'g', 280, false),
  ('methionine', 'Metionina', 'aminoAcid', 'g', 290, false),
  ('phenylalanine', 'Fenilalanina', 'aminoAcid', 'g', 300, false),
  ('valine', 'Valina', 'aminoAcid', 'g', 310, false),
  ('histidine', 'Histidina', 'aminoAcid', 'g', 320, false),
  ('vitaminA', 'Vitamina A', 'vitamin', 'ug', 330, false),
  ('vitaminB1', 'Vitamina B1 (tiamina)', 'vitamin', 'mg', 340, false),
  ('vitaminB2', 'Vitamina B2 (riboflavina)', 'vitamin', 'mg', 350, false),
  ('vitaminB3', 'Vitamina B3 (niacina)', 'vitamin', 'mg', 360, false),
  ('vitaminB5', 'Vitamina B5 (ácido pantotênico)', 'vitamin', 'mg', 370, false),
  ('vitaminB6', 'Vitamina B6 (piridoxina)', 'vitamin', 'mg', 380, false),
  ('vitaminB7', 'Vitamina B7 (biotina)', 'vitamin', 'ug', 390, false),
  ('vitaminB9', 'Vitamina B9 (folato)', 'vitamin', 'ug', 400, false),
  ('vitaminB12', 'Vitamina B12 (cobalamina)', 'vitamin', 'ug', 410, false),
  ('vitaminC', 'Vitamina C', 'vitamin', 'mg', 420, false),
  ('vitaminD', 'Vitamina D', 'vitamin', 'ug', 430, false),
  ('vitaminE', 'Vitamina E', 'vitamin', 'mg', 440, false),
  ('vitaminK', 'Vitamina K', 'vitamin', 'ug', 450, false),
  ('calcium', 'Cálcio', 'mineral', 'mg', 460, false),
  ('iron', 'Ferro', 'mineral', 'mg', 470, false),
  ('magnesium', 'Magnésio', 'mineral', 'mg', 480, false),
  ('phosphorus', 'Fósforo', 'mineral', 'mg', 490, false),
  ('potassium', 'Potássio', 'mineral', 'mg', 500, false),
  ('sodium', 'Sódio', 'mineral', 'mg', 510, true),
  ('zinc', 'Zinco', 'mineral', 'mg', 520, false),
  ('copper', 'Cobre', 'mineral', 'mg', 530, false),
  ('manganese', 'Manganês', 'mineral', 'mg', 540, false),
  ('selenium', 'Selênio', 'mineral', 'ug', 550, false),
  ('iodine', 'Iodo', 'mineral', 'ug', 560, false),
  ('chromium', 'Cromo', 'mineral', 'ug', 570, false),
  ('molybdenum', 'Molibdênio', 'mineral', 'ug', 580, false),
  ('fluoride', 'Flúor', 'mineral', 'mg', 590, false),
  ('chloride', 'Cloreto', 'mineral', 'mg', 600, false),
  ('caffeine', 'Cafeína', 'phytochemical', 'mg', 610, false),
  ('choline', 'Colina', 'other', 'mg', 620, false);
