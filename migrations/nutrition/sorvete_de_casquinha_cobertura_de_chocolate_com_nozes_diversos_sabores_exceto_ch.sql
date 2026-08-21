-- Sorvete de casquinha, cobertura de chocolate, com nozes, diversos sabores exceto chocolate
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.
--
-- Nutrientes do relatorio sem correspondencia no catalogo,
-- portanto NAO importados:
--   Ácido graxo tridecanóico
--   Ácido graxo pentadecanóico
--   Ácido graxo be-hênico
--   Ácido graxo lignocérico
--   Ácido graxo pentadecenóico
--   Ácido graxo heptadecenóico
--   Ácido graxo tetracosenóico, cis
--   Ácido eicosadienóico, cis, n-6
--   Ácido graxo eicosatrienóico, indiferenciado

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('06ac2349-5053-5b8a-bbb2-a564a5c44686', null, 'Sorvete de casquinha, cobertura de chocolate, com nozes, diversos sabores exceto chocolate', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'water', 37.43),  -- Água
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'calories', 354),  -- Valor energético (kcal)
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'kilojoules', 1482),  -- Valor energético (kJ)
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'protein', 5.21),  -- Proteína
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'fat', 21.88),  -- Gorduras totais
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'ash', 1.11),  -- Cinzas
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'carbohydrates', 34.38),  -- Carboidratos (por diferença)
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'fiber', 1),  -- Fibra alimentar
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'monosaccharides', 25),  -- Monossacarídeos
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'calcium', 63),  -- Cálcio
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'iron', 0),  -- Ferro
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'magnesium', 29),  -- Magnésio
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'phosphorus', 108),  -- Fósforo
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'potassium', 222),  -- Potássio
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'sodium', 94),  -- Sódio
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'zinc', 0.86),  -- Zinco
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'copper', 0.128),  -- Cobre
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'manganese', 0.194),  -- Manganês
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'selenium', 2.6),  -- Selênio
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'fluoride', 4),  -- Flúor
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminB1', 0.108),  -- Tiamina
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminB2', 0.252),  -- Riboflavina
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminB3', 0.829),  -- Niacina
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminB5', 0.438),  -- Ácido Pantotênico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminB6', 0.046),  -- Vitamina B6
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminB9', 24),  -- Ácido fólico, total
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'folicAcid', 16),  -- Ácido fólico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'foodFolate', 8),  -- Folato, alimento
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'folateDfe', 35),  -- Folato, equivalente à medida diária
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'choline', 23.8),  -- Colina, total
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminB12', 0.36),  -- Vitamina B12
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminA', 32),  -- Vitamina A (atividade equivalente de retinol)
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'retinol', 31),  -- Retinol
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'betaCarotene', 11),  -- Betacaroteno
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'alphaCarotene', 0),  -- Alfacaroteno
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminAIu', 104),  -- Vitamina A (SI)
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'lycopene', 0),  -- Licopeno
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'luteinZeaxanthin', 4),  -- Luteína + zeaxantina
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminE', 0.18),  -- Vitamina E (alfatocoferol)
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminD', 0.1),  -- Vitamina D (D2 + D3)
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminD3', 0.1),  -- Vitamina D3 (colecalciferol)
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminDIu', 3),  -- Vitamina D
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'vitaminK', 1.1),  -- Vitamina K (filoquinona)
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'saturatedFat', 11.458),  -- Gorduras saturadas
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'butyricAcid', 0.281),  -- Ácido graxo butírico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'caproicAcid', 0.197),  -- Ácido graxo capróico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'caprylicAcid', 0.148),  -- Ácido graxo caprílico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'capricAcid', 0.235),  -- Ácido graxo cáprico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'lauricAcid', 0.254),  -- Ácido graxo láurico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'myristicAcid', 0.948),  -- Ácido graxo mirístico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'palmiticAcid', 4.933),  -- Ácido graxo palmítico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'heptadecanoicAcid', 0.014),  -- Ácido graxo heptadecanóico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'stearicAcid', 4.204),  -- Ácido graxo esteárico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'arachidicAcid', 0.08),  -- Ácido graxo araquídico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'monounsaturatedFat', 7.34),  -- Gorduras monoinsaturadas
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'palmitoleicAcid', 0.185),  -- Ácido graxo palmítico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'oleicAcid', 7.14),  -- Ácido graxo oléico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'gadoleicAcid', 0.014),  -- Ácido graxo gadoléico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'polyunsaturatedFat', 1.657),  -- Gorduras poliinsaturadas
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'linoleicAcid', 1.408),  -- Ácido graxo linoléico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'ala', 0.249),  -- Ácido graxo linolênico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'cholesterol', 21),  -- Colesterol
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'alcohol', 0),  -- Álcool
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'caffeine', 7),  -- Cafeína
  ('06ac2349-5053-5b8a-bbb2-a564a5c44686', 'theobromine', 56)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
