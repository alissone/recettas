-- Laranja, crua, todas variedades comerciais
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', null, 'Laranja, crua, todas variedades comerciais', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'water', 86.75),  -- Água
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'calories', 47),  -- Valor energético (kcal)
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'kilojoules', 197),  -- Valor energético (kJ)
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'protein', 0.94),  -- Proteína
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'fat', 0.12),  -- Gorduras totais
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'ash', 0.44),  -- Cinzas
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'carbohydrates', 11.75),  -- Carboidratos (por diferença)
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'fiber', 2.4),  -- Fibra alimentar
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'monosaccharides', 9.35),  -- Monossacarídeos
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'calcium', 40),  -- Cálcio
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'iron', 0.1),  -- Ferro
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'magnesium', 10),  -- Magnésio
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'phosphorus', 14),  -- Fósforo
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'potassium', 181),  -- Potássio
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'sodium', 0),  -- Sódio
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'zinc', 0.07),  -- Zinco
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'copper', 0.045),  -- Cobre
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'manganese', 0.025),  -- Manganês
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'selenium', 0.5),  -- Selênio
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'vitaminC', 53.2),  -- Vitamina C, ácido ascórbico total
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'vitaminB1', 0.087),  -- Tiamina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'vitaminB2', 0.04),  -- Riboflavina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'vitaminB3', 0.282),  -- Niacina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'vitaminB5', 0.25),  -- Ácido Pantotênico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'vitaminB6', 0.06),  -- Vitamina B6
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'vitaminB9', 30),  -- Ácido fólico, total
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'folicAcid', 0),  -- Ácido fólico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'foodFolate', 30),  -- Folato, alimento
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'folateDfe', 30),  -- Folato, equivalente à medida diária
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'choline', 8.4),  -- Colina, total
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'vitaminB12', 0),  -- Vitamina B12
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'vitaminA', 11),  -- Vitamina A (atividade equivalente de retinol)
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'retinol', 0),  -- Retinol
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'betaCarotene', 71),  -- Betacaroteno
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'alphaCarotene', 11),  -- Alfacaroteno
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'betaCryptoxanthin', 116),  -- Beta-criptoxantina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'vitaminAIu', 225),  -- Vitamina A (SI)
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'lycopene', 0),  -- Licopeno
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'luteinZeaxanthin', 129),  -- Luteína + zeaxantina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'vitaminE', 0.18),  -- Vitamina E (alfatocoferol)
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'vitaminDIu', 0),  -- Vitamina D
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'vitaminK', 0),  -- Vitamina K (filoquinona)
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'saturatedFat', 0.015),  -- Gorduras saturadas
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'myristicAcid', 0),  -- Ácido graxo mirístico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'palmiticAcid', 0.013),  -- Ácido graxo palmítico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'stearicAcid', 0),  -- Ácido graxo esteárico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'monounsaturatedFat', 0.023),  -- Gorduras monoinsaturadas
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'palmitoleicAcid', 0.003),  -- Ácido graxo palmítico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'oleicAcid', 0.02),  -- Ácido graxo oléico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'polyunsaturatedFat', 0.025),  -- Gorduras poliinsaturadas
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'linoleicAcid', 0.018),  -- Ácido graxo linoléico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'ala', 0.007),  -- Ácido graxo linolênico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'cholesterol', 0),  -- Colesterol
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'tryptophan', 0.009),  -- Triptofano
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'threonine', 0.015),  -- Treonina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'isoleucine', 0.025),  -- Isoleucina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'leucine', 0.023),  -- Leucina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'lysine', 0.047),  -- Lisina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'methionine', 0.02),  -- Metionina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'cysteine', 0.01),  -- Cisteína
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'phenylalanine', 0.031),  -- Fenilalanina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'tyrosine', 0.016),  -- Tirosina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'valine', 0.04),  -- Valina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'arginine', 0.065),  -- Arginina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'histidine', 0.018),  -- Histidina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'alanine', 0.05),  -- Alanina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'asparticAcid', 0.114),  -- Aspartato
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'glutamicAcid', 0.094),  -- Glutamato
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'glycine', 0.094),  -- Glicina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'proline', 0.046),  -- Prolina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'serine', 0.032),  -- Serina
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'alcohol', 0),  -- Álcool
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'caffeine', 0),  -- Cafeína
  ('ce90e135-1ba6-5c0f-a24f-fc71666552eb', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
