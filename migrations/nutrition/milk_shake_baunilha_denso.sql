-- Milk-shake, baunilha denso
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', null, 'Milk-shake, baunilha denso', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'water', 74.45),  -- Água
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'calories', 112),  -- Valor energético (kcal)
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'kilojoules', 468),  -- Valor energético (kJ)
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'protein', 3.86),  -- Proteína
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'fat', 3.03),  -- Gorduras totais
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'ash', 0.91),  -- Cinzas
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'carbohydrates', 17.75),  -- Carboidratos (por diferença)
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'fiber', 0),  -- Fibra alimentar
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'monosaccharides', 17.75),  -- Monossacarídeos
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'calcium', 146),  -- Cálcio
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'iron', 0.1),  -- Ferro
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'magnesium', 12),  -- Magnésio
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'phosphorus', 115),  -- Fósforo
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'potassium', 183),  -- Potássio
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'sodium', 95),  -- Sódio
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'zinc', 0.39),  -- Zinco
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'copper', 0.051),  -- Cobre
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'manganese', 0.014),  -- Manganês
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'selenium', 2.3),  -- Selênio
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminB1', 0.03),  -- Tiamina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminB2', 0.195),  -- Riboflavina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminB3', 0.146),  -- Niacina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminB5', 0.368),  -- Ácido Pantotênico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminB6', 0.042),  -- Vitamina B6
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminB9', 7),  -- Ácido fólico, total
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'folicAcid', 0),  -- Ácido fólico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'foodFolate', 7),  -- Folato, alimento
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'folateDfe', 7),  -- Folato, equivalente à medida diária
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'choline', 14.3),  -- Colina, total
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminB12', 0.52),  -- Vitamina B12
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminA', 25),  -- Vitamina A (atividade equivalente de retinol)
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'retinol', 25),  -- Retinol
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'betaCarotene', 5),  -- Betacaroteno
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'alphaCarotene', 0),  -- Alfacaroteno
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminAIu', 91),  -- Vitamina A (SI)
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'lycopene', 0),  -- Licopeno
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'luteinZeaxanthin', 0),  -- Luteína + zeaxantina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminE', 0.05),  -- Vitamina E (alfatocoferol)
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminD', 1.2),  -- Vitamina D (D2 + D3)
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminD3', 1.2),  -- Vitamina D3 (colecalciferol)
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminDIu', 48),  -- Vitamina D
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'vitaminK', 0.2),  -- Vitamina K (filoquinona)
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'saturatedFat', 1.886),  -- Gorduras saturadas
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'butyricAcid', 0.098),  -- Ácido graxo butírico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'caproicAcid', 0.058),  -- Ácido graxo capróico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'caprylicAcid', 0.034),  -- Ácido graxo caprílico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'capricAcid', 0.076),  -- Ácido graxo cáprico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'lauricAcid', 0.085),  -- Ácido graxo láurico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'myristicAcid', 0.305),  -- Ácido graxo mirístico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'palmiticAcid', 0.797),  -- Ácido graxo palmítico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'stearicAcid', 0.367),  -- Ácido graxo esteárico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'monounsaturatedFat', 0.875),  -- Gorduras monoinsaturadas
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'palmitoleicAcid', 0.068),  -- Ácido graxo palmítico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'oleicAcid', 0.762),  -- Ácido graxo oléico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'polyunsaturatedFat', 0.113),  -- Gorduras poliinsaturadas
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'linoleicAcid', 0.068),  -- Ácido graxo linoléico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'ala', 0.044),  -- Ácido graxo linolênico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'cholesterol', 12),  -- Colesterol
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'tryptophan', 0.054),  -- Triptofano
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'threonine', 0.174),  -- Treonina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'isoleucine', 0.234),  -- Isoleucina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'leucine', 0.378),  -- Leucina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'lysine', 0.306),  -- Lisina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'methionine', 0.097),  -- Metionina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'cysteine', 0.036),  -- Cisteína
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'phenylalanine', 0.186),  -- Fenilalanina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'tyrosine', 0.186),  -- Tirosina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'valine', 0.258),  -- Valina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'arginine', 0.14),  -- Arginina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'histidine', 0.105),  -- Histidina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'alanine', 0.133),  -- Alanina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'asparticAcid', 0.293),  -- Aspartato
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'glutamicAcid', 0.808),  -- Glutamato
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'glycine', 0.082),  -- Glicina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'proline', 0.374),  -- Prolina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'serine', 0.21),  -- Serina
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'alcohol', 0),  -- Álcool
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'caffeine', 0),  -- Cafeína
  ('2c089747-9d3a-5438-83c1-5ff73d4b27b3', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
