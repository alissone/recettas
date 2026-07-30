-- Refrigerante, cola, sem cafeina
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('88355503-99cd-561e-a3ba-77c3f55a9789', null, 'Refrigerante, cola, sem cafeina', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'water', 89.62),  -- Água
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'calories', 41),  -- Valor energético (kcal)
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'kilojoules', 171),  -- Valor energético (kJ)
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'protein', 0),  -- Proteína
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'fat', 0),  -- Gorduras totais
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'ash', 0.06),  -- Cinzas
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'carbohydrates', 10.58),  -- Carboidratos (por diferença)
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'fiber', 0),  -- Fibra alimentar
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'monosaccharides', 10.58),  -- Monossacarídeos
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'sucrose', 0),  -- Sacarose
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'glucose', 4.48),  -- Glicose
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'fructose', 6.1),  -- Frutose
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'calcium', 2),  -- Cálcio
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'iron', 0.02),  -- Ferro
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'magnesium', 0),  -- Magnésio
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'phosphorus', 11),  -- Fósforo
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'potassium', 3),  -- Potássio
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'sodium', 4),  -- Sódio
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'zinc', 0.01),  -- Zinco
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'copper', 0),  -- Cobre
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'manganese', 0),  -- Manganês
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'selenium', 0.1),  -- Selênio
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'vitaminB1', 0),  -- Tiamina
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'vitaminB2', 0),  -- Riboflavina
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'vitaminB3', 0),  -- Niacina
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'vitaminB5', 0),  -- Ácido Pantotênico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'vitaminB6', 0),  -- Vitamina B6
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'vitaminB9', 0),  -- Ácido fólico, total
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'folicAcid', 0),  -- Ácido fólico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'foodFolate', 0),  -- Folato, alimento
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'folateDfe', 0),  -- Folato, equivalente à medida diária
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'choline', 0.3),  -- Colina, total
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'vitaminB12', 0),  -- Vitamina B12
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'vitaminA', 0),  -- Vitamina A (atividade equivalente de retinol)
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'retinol', 0),  -- Retinol
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'betaCarotene', 0),  -- Betacaroteno
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'alphaCarotene', 0),  -- Alfacaroteno
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'vitaminAIu', 0),  -- Vitamina A (SI)
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'lycopene', 0),  -- Licopeno
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'luteinZeaxanthin', 0),  -- Luteína + zeaxantina
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'vitaminE', 0),  -- Vitamina E (alfatocoferol)
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'vitaminDIu', 0),  -- Vitamina D
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'vitaminK', 0),  -- Vitamina K (filoquinona)
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'saturatedFat', 0),  -- Gorduras saturadas
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'myristicAcid', 0),  -- Ácido graxo mirístico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'palmiticAcid', 0),  -- Ácido graxo palmítico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'stearicAcid', 0),  -- Ácido graxo esteárico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'monounsaturatedFat', 0),  -- Gorduras monoinsaturadas
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'palmitoleicAcid', 0),  -- Ácido graxo palmítico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'oleicAcid', 0),  -- Ácido graxo oléico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'polyunsaturatedFat', 0),  -- Gorduras poliinsaturadas
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'linoleicAcid', 0),  -- Ácido graxo linoléico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'ala', 0),  -- Ácido graxo linolênico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'cholesterol', 0),  -- Colesterol
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'alcohol', 0),  -- Álcool
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'caffeine', 0),  -- Cafeína
  ('88355503-99cd-561e-a3ba-77c3f55a9789', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
