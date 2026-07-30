-- Maca, crua, com casca
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.
--
-- Nutrientes do relatorio sem correspondencia no catalogo,
-- portanto NAO importados:
--   Fitosterol

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('7ad25218-087f-58f1-9625-b6f1d9e7550f', null, 'Maca, crua, com casca', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'water', 85.56),  -- Água
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'calories', 52),  -- Valor energético (kcal)
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'kilojoules', 218),  -- Valor energético (kJ)
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'protein', 0.26),  -- Proteína
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'fat', 0.17),  -- Gorduras totais
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'ash', 0.19),  -- Cinzas
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'carbohydrates', 13.81),  -- Carboidratos (por diferença)
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'fiber', 2.4),  -- Fibra alimentar
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'monosaccharides', 10.39),  -- Monossacarídeos
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'sucrose', 2.07),  -- Sacarose
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'glucose', 2.43),  -- Glicose
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'fructose', 5.9),  -- Frutose
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'lactose', 0),  -- Lactose
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'maltose', 0),  -- Maltose
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'galactose', 0),  -- Galactose
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'starch', 0.05),  -- Amido
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'calcium', 6),  -- Cálcio
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'iron', 0.12),  -- Ferro
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'magnesium', 5),  -- Magnésio
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'phosphorus', 11),  -- Fósforo
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'potassium', 107),  -- Potássio
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'sodium', 1),  -- Sódio
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'zinc', 0.04),  -- Zinco
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'copper', 0.027),  -- Cobre
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'manganese', 0.035),  -- Manganês
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'selenium', 0),  -- Selênio
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'fluoride', 3.3),  -- Flúor
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'vitaminC', 4.6),  -- Vitamina C, ácido ascórbico total
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'vitaminB1', 0.017),  -- Tiamina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'vitaminB2', 0.026),  -- Riboflavina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'vitaminB3', 0.091),  -- Niacina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'vitaminB5', 0.061),  -- Ácido Pantotênico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'vitaminB6', 0.041),  -- Vitamina B6
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'vitaminB9', 3),  -- Ácido fólico, total
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'folicAcid', 0),  -- Ácido fólico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'foodFolate', 3),  -- Folato, alimento
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'folateDfe', 3),  -- Folato, equivalente à medida diária
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'choline', 3.4),  -- Colina, total
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'betaine', 0.1),  -- Betaína
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'vitaminB12', 0),  -- Vitamina B12
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'vitaminA', 3),  -- Vitamina A (atividade equivalente de retinol)
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'retinol', 0),  -- Retinol
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'betaCarotene', 27),  -- Betacaroteno
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'alphaCarotene', 0),  -- Alfacaroteno
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'betaCryptoxanthin', 11),  -- Beta-criptoxantina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'vitaminAIu', 54),  -- Vitamina A (SI)
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'lycopene', 0),  -- Licopeno
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'luteinZeaxanthin', 29),  -- Luteína + zeaxantina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'vitaminE', 0.18),  -- Vitamina E (alfatocoferol)
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'betaTocopherol', 0),  -- Beta-tocoferol
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'gammaTocopherol', 0),  -- Gama-tocoferol
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'deltaTocopherol', 0),  -- Delta-tocoferol
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'vitaminDIu', 0),  -- Vitamina D
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'vitaminK', 2.2),  -- Vitamina K (filoquinona)
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'dihydrophylloquinone', 0),  -- Dihidrofiloquinona
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'saturatedFat', 0.028),  -- Gorduras saturadas
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'myristicAcid', 0.001),  -- Ácido graxo mirístico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'palmiticAcid', 0.024),  -- Ácido graxo palmítico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'stearicAcid', 0.003),  -- Ácido graxo esteárico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'monounsaturatedFat', 0.007),  -- Gorduras monoinsaturadas
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'palmitoleicAcid', 0),  -- Ácido graxo palmítico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'oleicAcid', 0.007),  -- Ácido graxo oléico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'polyunsaturatedFat', 0.051),  -- Gorduras poliinsaturadas
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'linoleicAcid', 0.043),  -- Ácido graxo linoléico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'ala', 0.009),  -- Ácido graxo linolênico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'cholesterol', 0),  -- Colesterol
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'tryptophan', 0.001),  -- Triptofano
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'threonine', 0.006),  -- Treonina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'isoleucine', 0.006),  -- Isoleucina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'leucine', 0.013),  -- Leucina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'lysine', 0.012),  -- Lisina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'methionine', 0.001),  -- Metionina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'cysteine', 0.001),  -- Cisteína
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'phenylalanine', 0.006),  -- Fenilalanina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'tyrosine', 0.001),  -- Tirosina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'valine', 0.012),  -- Valina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'arginine', 0.006),  -- Arginina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'histidine', 0.005),  -- Histidina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'alanine', 0.011),  -- Alanina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'asparticAcid', 0.07),  -- Aspartato
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'glutamicAcid', 0.025),  -- Glutamato
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'glycine', 0.009),  -- Glicina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'proline', 0.006),  -- Prolina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'serine', 0.01),  -- Serina
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'alcohol', 0),  -- Álcool
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'caffeine', 0),  -- Cafeína
  ('7ad25218-087f-58f1-9625-b6f1d9e7550f', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
