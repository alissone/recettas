-- Refrigerante, SPRITE, lima-limao, sem cafeina
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('deb4d0db-41d8-5eba-91b1-fac38be3f200', null, 'Refrigerante, SPRITE, lima-limao, sem cafeina', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'water', 89.78),  -- Água
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'calories', 40),  -- Valor energético (kcal)
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'kilojoules', 165),  -- Valor energético (kJ)
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'protein', 0.05),  -- Proteína
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'fat', 0.02),  -- Gorduras totais
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'ash', 0.01),  -- Cinzas
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'carbohydrates', 10.14),  -- Carboidratos (por diferença)
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'fiber', 0),  -- Fibra alimentar
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'monosaccharides', 8.98),  -- Monossacarídeos
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'sucrose', 0.65),  -- Sacarose
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'glucose', 3.13),  -- Glicose
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'fructose', 5.19),  -- Frutose
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'calcium', 2),  -- Cálcio
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'iron', 0.11),  -- Ferro
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'magnesium', 1),  -- Magnésio
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'phosphorus', 0),  -- Fósforo
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'potassium', 1),  -- Potássio
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'sodium', 9),  -- Sódio
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'zinc', 0.04),  -- Zinco
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'copper', 0.001),  -- Cobre
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'manganese', 0.002),  -- Manganês
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'selenium', 0),  -- Selênio
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'fluoride', 55.9),  -- Flúor
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'vitaminB1', 0),  -- Tiamina
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'vitaminB2', 0),  -- Riboflavina
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'vitaminB3', 0.015),  -- Niacina
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'vitaminB5', 0),  -- Ácido Pantotênico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'vitaminB6', 0),  -- Vitamina B6
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'vitaminB9', 0),  -- Ácido fólico, total
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'folicAcid', 0),  -- Ácido fólico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'foodFolate', 0),  -- Folato, alimento
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'folateDfe', 0),  -- Folato, equivalente à medida diária
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'choline', 0.4),  -- Colina, total
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'vitaminB12', 0),  -- Vitamina B12
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'vitaminA', 0),  -- Vitamina A (atividade equivalente de retinol)
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'retinol', 0),  -- Retinol
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'betaCarotene', 0),  -- Betacaroteno
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'alphaCarotene', 0),  -- Alfacaroteno
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'vitaminAIu', 0),  -- Vitamina A (SI)
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'lycopene', 0),  -- Licopeno
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'luteinZeaxanthin', 0),  -- Luteína + zeaxantina
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'vitaminE', 0),  -- Vitamina E (alfatocoferol)
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'vitaminDIu', 0),  -- Vitamina D
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'vitaminK', 0),  -- Vitamina K (filoquinona)
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'saturatedFat', 0),  -- Gorduras saturadas
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'myristicAcid', 0),  -- Ácido graxo mirístico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'palmiticAcid', 0),  -- Ácido graxo palmítico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'stearicAcid', 0),  -- Ácido graxo esteárico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'monounsaturatedFat', 0),  -- Gorduras monoinsaturadas
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'palmitoleicAcid', 0),  -- Ácido graxo palmítico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'oleicAcid', 0),  -- Ácido graxo oléico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'polyunsaturatedFat', 0),  -- Gorduras poliinsaturadas
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'linoleicAcid', 0),  -- Ácido graxo linoléico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'ala', 0),  -- Ácido graxo linolênico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'cholesterol', 0),  -- Colesterol
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'alcohol', 0),  -- Álcool
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'caffeine', 0),  -- Cafeína
  ('deb4d0db-41d8-5eba-91b1-fac38be3f200', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
