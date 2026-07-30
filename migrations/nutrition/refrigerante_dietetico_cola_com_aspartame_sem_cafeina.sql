-- Refrigerante, dietetico, cola, com aspartame, sem cafeina
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('4e449751-2768-5af4-bffd-369832dbf72c', null, 'Refrigerante, dietetico, cola, com aspartame, sem cafeina', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'water', 99.74),  -- Água
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'calories', 1),  -- Valor energético (kcal)
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'kilojoules', 4),  -- Valor energético (kJ)
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'protein', 0.12),  -- Proteína
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'fat', 0),  -- Gorduras totais
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'ash', 0),  -- Cinzas
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'carbohydrates', 0.15),  -- Carboidratos (por diferença)
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'fiber', 0),  -- Fibra alimentar
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'monosaccharides', 0),  -- Monossacarídeos
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'calcium', 3),  -- Cálcio
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'iron', 0.02),  -- Ferro
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'magnesium', 0),  -- Magnésio
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'phosphorus', 10),  -- Fósforo
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'potassium', 7),  -- Potássio
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'sodium', 4),  -- Sódio
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'zinc', 0.01),  -- Zinco
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'copper', 0.002),  -- Cobre
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'manganese', 0),  -- Manganês
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'selenium', 0.1),  -- Selênio
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'fluoride', 52),  -- Flúor
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'vitaminB1', 0.005),  -- Tiamina
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'vitaminB2', 0.023),  -- Riboflavina
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'vitaminB3', 0),  -- Niacina
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'vitaminB5', 0),  -- Ácido Pantotênico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'vitaminB6', 0),  -- Vitamina B6
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'vitaminB9', 0),  -- Ácido fólico, total
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'folicAcid', 0),  -- Ácido fólico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'foodFolate', 0),  -- Folato, alimento
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'folateDfe', 0),  -- Folato, equivalente à medida diária
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'choline', 0),  -- Colina, total
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'vitaminB12', 0),  -- Vitamina B12
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'vitaminA', 0),  -- Vitamina A (atividade equivalente de retinol)
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'retinol', 0),  -- Retinol
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'betaCarotene', 0),  -- Betacaroteno
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'alphaCarotene', 0),  -- Alfacaroteno
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'vitaminAIu', 0),  -- Vitamina A (SI)
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'lycopene', 0),  -- Licopeno
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'luteinZeaxanthin', 0),  -- Luteína + zeaxantina
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'vitaminE', 0),  -- Vitamina E (alfatocoferol)
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'vitaminDIu', 0),  -- Vitamina D
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'vitaminK', 0),  -- Vitamina K (filoquinona)
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'saturatedFat', 0),  -- Gorduras saturadas
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'myristicAcid', 0),  -- Ácido graxo mirístico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'palmiticAcid', 0),  -- Ácido graxo palmítico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'stearicAcid', 0),  -- Ácido graxo esteárico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'monounsaturatedFat', 0),  -- Gorduras monoinsaturadas
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'palmitoleicAcid', 0),  -- Ácido graxo palmítico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'oleicAcid', 0),  -- Ácido graxo oléico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'polyunsaturatedFat', 0),  -- Gorduras poliinsaturadas
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'linoleicAcid', 0),  -- Ácido graxo linoléico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'ala', 0),  -- Ácido graxo linolênico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'cholesterol', 0),  -- Colesterol
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'alcohol', 0),  -- Álcool
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'caffeine', 0),  -- Cafeína
  ('4e449751-2768-5af4-bffd-369832dbf72c', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
