-- Extends the nutrient catalog from 62 to 115 entries so a full USDA
-- style panel can be entered: individual fatty acid chains, the complete
-- amino acid profile, the separate folate / retinol / tocopherol /
-- vitamin D forms, carotenoids, the individual sugars, ash and
-- theobromine.
--
-- Adds a "carotenoid" category, since lumping lycopene and lutein in with
-- the vitamins made that group unreadable.
--
-- Three units are corrected to match the source tables: fluoride is
-- reported in ug, and EPA/DHA in g rather than mg.
--   WARNING: changing a unit does NOT rescale amounts already stored in
--   food_nutrients. Safe while the food catalog is still empty; if you
--   have already entered foods, rescale those rows by hand first:
--     update public.food_nutrients set amount = amount / 1000
--      where nutrient_id in ('epa', 'dha');
--     update public.food_nutrients set amount = amount * 1000
--      where nutrient_id = 'fluoride';
--
-- The insert below is a full upsert over every row, so it both adds the
-- new nutrients and refreshes the name, category, unit and sort_order of
-- the ones from migration 014. It is safe to run more than once.

-- Column checks are auto-named <table>_<column>_check. If this errors,
-- find the real name with:
--   select conname from pg_constraint
--    where conrelid = 'public.nutrients'::regclass and contype = 'c';
alter table public.nutrients
  drop constraint nutrients_category_check;

alter table public.nutrients
  add constraint nutrients_category_check
  check (category in ('macronutrient', 'vitamin', 'mineral', 'aminoAcid',
                      'fattyAcid', 'sugar', 'sterol', 'phytochemical',
                      'carotenoid', 'other'));

insert into public.nutrients (id, name, category, unit, sort_order, is_primary)
values
  -- Principais
  ('calories', 'Calorias', 'macronutrient', 'kcal', 10, true),
  ('kilojoules', 'Quilojoules', 'macronutrient', 'kj', 20, false),
  ('protein', 'Proteína', 'macronutrient', 'g', 30, true),
  ('carbohydrates', 'Carboidratos (por diferença)', 'macronutrient', 'g', 40, true),
  ('fat', 'Gorduras totais', 'macronutrient', 'g', 50, true),
  ('fiber', 'Fibra alimentar', 'macronutrient', 'g', 60, true),
  ('solubleFiber', 'Fibra solúvel', 'macronutrient', 'g', 70, false),
  ('insolubleFiber', 'Fibra insolúvel', 'macronutrient', 'g', 80, false),
  ('starch', 'Amido', 'macronutrient', 'g', 90, false),
  ('water', 'Água', 'macronutrient', 'g', 100, false),
  ('ash', 'Cinzas', 'macronutrient', 'g', 110, false),
  ('alcohol', 'Álcool', 'macronutrient', 'g', 120, false),

  -- Açúcares
  ('sugar', 'Açúcares totais', 'sugar', 'g', 200, false),
  ('addedSugar', 'Açúcares adicionados', 'sugar', 'g', 210, false),
  ('monosaccharides', 'Monossacarídeos', 'sugar', 'g', 220, false),
  ('glucose', 'Glicose', 'sugar', 'g', 230, false),
  ('fructose', 'Frutose', 'sugar', 'g', 240, false),
  ('galactose', 'Galactose', 'sugar', 'g', 250, false),
  ('sucrose', 'Sacarose', 'sugar', 'g', 260, false),
  ('lactose', 'Lactose', 'sugar', 'g', 270, false),
  ('maltose', 'Maltose', 'sugar', 'g', 280, false),

  -- Lipídios: saturadas
  ('saturatedFat', 'Gorduras saturadas', 'fattyAcid', 'g', 300, false),
  ('butyricAcid', 'Ácido butírico (4:0)', 'fattyAcid', 'g', 310, false),
  ('caproicAcid', 'Ácido capróico (6:0)', 'fattyAcid', 'g', 320, false),
  ('caprylicAcid', 'Ácido caprílico (8:0)', 'fattyAcid', 'g', 330, false),
  ('capricAcid', 'Ácido cáprico (10:0)', 'fattyAcid', 'g', 340, false),
  ('lauricAcid', 'Ácido láurico (12:0)', 'fattyAcid', 'g', 350, false),
  ('myristicAcid', 'Ácido mirístico (14:0)', 'fattyAcid', 'g', 360, false),
  ('palmiticAcid', 'Ácido palmítico (16:0)', 'fattyAcid', 'g', 370, false),
  ('stearicAcid', 'Ácido esteárico (18:0)', 'fattyAcid', 'g', 380, false),
  -- Lipídios: monoinsaturadas. Source tables often label 16:1
  -- "palmítico"; the monounsaturated C16:1 is palmitoleico.
  ('monounsaturatedFat', 'Gorduras monoinsaturadas', 'fattyAcid', 'g', 390, false),
  ('palmitoleicAcid', 'Ácido palmitoleico (16:1)', 'fattyAcid', 'g', 400, false),
  ('oleicAcid', 'Ácido oleico (18:1)', 'fattyAcid', 'g', 410, false),
  ('gadoleicAcid', 'Ácido gadoleico (20:1)', 'fattyAcid', 'g', 420, false),
  ('erucicAcid', 'Ácido erúcico (22:1)', 'fattyAcid', 'g', 430, false),
  -- Lipídios: poli-insaturadas
  ('polyunsaturatedFat', 'Gorduras poli-insaturadas', 'fattyAcid', 'g', 440, false),
  ('linoleicAcid', 'Ácido linoleico (18:2)', 'fattyAcid', 'g', 450, false),
  ('ala', 'Ácido alfa-linolênico, ALA (18:3)', 'fattyAcid', 'g', 460, false),
  ('parinaricAcid', 'Ácido parinárico (18:4)', 'fattyAcid', 'g', 470, false),
  ('arachidonicAcid', 'Ácido araquidônico (20:4)', 'fattyAcid', 'g', 480, false),
  ('epa', 'EPA, eicosapentaenoico (20:5)', 'fattyAcid', 'g', 490, false),
  ('dpa', 'DPA, docosapentaenoico (22:5)', 'fattyAcid', 'g', 500, false),
  ('dha', 'DHA, docosahexaenoico (22:6)', 'fattyAcid', 'g', 510, false),
  ('transFat', 'Gorduras trans', 'fattyAcid', 'g', 520, false),
  ('omega3', 'Ômega-3 (total)', 'fattyAcid', 'g', 530, false),
  ('omega6', 'Ômega-6 (total)', 'fattyAcid', 'g', 540, false),

  -- Esteróis
  ('cholesterol', 'Colesterol', 'sterol', 'mg', 600, false),

  -- Aminoácidos
  ('tryptophan', 'Triptofano', 'aminoAcid', 'g', 700, false),
  ('threonine', 'Treonina', 'aminoAcid', 'g', 710, false),
  ('isoleucine', 'Isoleucina', 'aminoAcid', 'g', 720, false),
  ('leucine', 'Leucina', 'aminoAcid', 'g', 730, false),
  ('lysine', 'Lisina', 'aminoAcid', 'g', 740, false),
  ('methionine', 'Metionina', 'aminoAcid', 'g', 750, false),
  ('cysteine', 'Cisteína', 'aminoAcid', 'g', 760, false),
  ('phenylalanine', 'Fenilalanina', 'aminoAcid', 'g', 770, false),
  ('tyrosine', 'Tirosina', 'aminoAcid', 'g', 780, false),
  ('valine', 'Valina', 'aminoAcid', 'g', 790, false),
  ('arginine', 'Arginina', 'aminoAcid', 'g', 800, false),
  ('histidine', 'Histidina', 'aminoAcid', 'g', 810, false),
  ('alanine', 'Alanina', 'aminoAcid', 'g', 820, false),
  ('asparticAcid', 'Aspartato', 'aminoAcid', 'g', 830, false),
  ('glutamicAcid', 'Glutamato', 'aminoAcid', 'g', 840, false),
  ('glycine', 'Glicina', 'aminoAcid', 'g', 850, false),
  ('proline', 'Prolina', 'aminoAcid', 'g', 860, false),
  ('serine', 'Serina', 'aminoAcid', 'g', 870, false),

  -- Vitaminas
  ('vitaminC', 'Vitamina C (ácido ascórbico total)', 'vitamin', 'mg', 900, false),
  ('vitaminB1', 'Vitamina B1 (tiamina)', 'vitamin', 'mg', 910, false),
  ('vitaminB2', 'Vitamina B2 (riboflavina)', 'vitamin', 'mg', 920, false),
  ('vitaminB3', 'Vitamina B3 (niacina)', 'vitamin', 'mg', 930, false),
  ('vitaminB5', 'Vitamina B5 (ácido pantotênico)', 'vitamin', 'mg', 940, false),
  ('vitaminB6', 'Vitamina B6 (piridoxina)', 'vitamin', 'mg', 950, false),
  ('vitaminB7', 'Vitamina B7 (biotina)', 'vitamin', 'ug', 960, false),
  ('vitaminB9', 'Vitamina B9 (folato total)', 'vitamin', 'ug', 970, false),
  ('folicAcid', 'Ácido fólico (sintético)', 'vitamin', 'ug', 980, false),
  ('foodFolate', 'Folato alimentar', 'vitamin', 'ug', 990, false),
  ('folateDfe', 'Folato (equivalente dietético, DFE)', 'vitamin', 'ug', 1000, false),
  ('vitaminB12', 'Vitamina B12 (cobalamina)', 'vitamin', 'ug', 1010, false),
  ('addedVitaminB12', 'Vitamina B12 adicionada', 'vitamin', 'ug', 1020, false),
  ('vitaminA', 'Vitamina A (equivalente de retinol, RAE)', 'vitamin', 'ug', 1030, false),
  ('retinol', 'Retinol', 'vitamin', 'ug', 1040, false),
  ('vitaminAIu', 'Vitamina A (UI)', 'vitamin', 'iu', 1050, false),
  ('vitaminE', 'Vitamina E (alfatocoferol)', 'vitamin', 'mg', 1060, false),
  ('addedVitaminE', 'Vitamina E adicionada', 'vitamin', 'mg', 1070, false),
  ('gammaTocopherol', 'Gama-tocoferol', 'vitamin', 'mg', 1080, false),
  ('deltaTocopherol', 'Delta-tocoferol', 'vitamin', 'mg', 1090, false),
  ('vitaminD', 'Vitamina D (D2 + D3)', 'vitamin', 'ug', 1100, false),
  ('vitaminD2', 'Vitamina D2 (ergocalciferol)', 'vitamin', 'ug', 1110, false),
  ('vitaminD3', 'Vitamina D3 (colecalciferol)', 'vitamin', 'ug', 1120, false),
  ('vitaminDIu', 'Vitamina D (UI)', 'vitamin', 'iu', 1130, false),
  ('vitaminK', 'Vitamina K (filoquinona)', 'vitamin', 'ug', 1140, false),
  ('dihydrophylloquinone', 'Di-hidrofiloquinona', 'vitamin', 'ug', 1150, false),

  -- Carotenoides
  ('betaCarotene', 'Betacaroteno', 'carotenoid', 'ug', 1200, false),
  ('alphaCarotene', 'Alfacaroteno', 'carotenoid', 'ug', 1210, false),
  ('betaCryptoxanthin', 'Beta-criptoxantina', 'carotenoid', 'ug', 1220, false),
  ('lycopene', 'Licopeno', 'carotenoid', 'ug', 1230, false),
  ('luteinZeaxanthin', 'Luteína + zeaxantina', 'carotenoid', 'ug', 1240, false),

  -- Minerais
  ('calcium', 'Cálcio', 'mineral', 'mg', 1300, false),
  ('iron', 'Ferro', 'mineral', 'mg', 1310, false),
  ('magnesium', 'Magnésio', 'mineral', 'mg', 1320, false),
  ('phosphorus', 'Fósforo', 'mineral', 'mg', 1330, false),
  ('potassium', 'Potássio', 'mineral', 'mg', 1340, false),
  ('sodium', 'Sódio', 'mineral', 'mg', 1350, true),
  ('zinc', 'Zinco', 'mineral', 'mg', 1360, false),
  ('copper', 'Cobre', 'mineral', 'mg', 1370, false),
  ('manganese', 'Manganês', 'mineral', 'mg', 1380, false),
  ('selenium', 'Selênio', 'mineral', 'ug', 1390, false),
  ('iodine', 'Iodo', 'mineral', 'ug', 1400, false),
  ('chromium', 'Cromo', 'mineral', 'ug', 1410, false),
  ('molybdenum', 'Molibdênio', 'mineral', 'ug', 1420, false),
  ('fluoride', 'Flúor', 'mineral', 'ug', 1430, false),
  ('chloride', 'Cloreto', 'mineral', 'mg', 1440, false),

  -- Fitoquímicos
  ('caffeine', 'Cafeína', 'phytochemical', 'mg', 1500, false),
  ('theobromine', 'Teobromina', 'phytochemical', 'mg', 1510, false),

  -- Outros
  ('choline', 'Colina (total)', 'other', 'mg', 1600, false),
  ('betaine', 'Betaína', 'other', 'mg', 1610, false)
on conflict (id) do update set
  name = excluded.name,
  category = excluded.category,
  unit = excluded.unit,
  sort_order = excluded.sort_order,
  is_primary = excluded.is_primary;
