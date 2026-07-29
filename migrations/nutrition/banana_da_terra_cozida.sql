-- Banana-da-terra, cozida
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', null, 'Banana-da-terra, cozida', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'water', 67.3),  -- Água
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'calories', 116),  -- Valor energético (kcal)
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'kilojoules', 485),  -- Valor energético (kJ)
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'protein', 0.79),  -- Proteína
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'fat', 0.18),  -- Gorduras totais
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'ash', 0.58),  -- Cinzas
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'carbohydrates', 31.15),  -- Carboidratos (por diferença)
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'fiber', 2.3),  -- Fibra alimentar
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'monosaccharides', 14),  -- Monossacarídeos
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'calcium', 2),  -- Cálcio
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'iron', 0.58),  -- Ferro
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'magnesium', 32),  -- Magnésio
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'phosphorus', 28),  -- Fósforo
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'potassium', 465),  -- Potássio
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'sodium', 5),  -- Sódio
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'zinc', 0.13),  -- Zinco
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'copper', 0.066),  -- Cobre
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'selenium', 1.4),  -- Selênio
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'vitaminC', 10.9),  -- Vitamina C, ácido ascórbico total
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'vitaminB1', 0.046),  -- Tiamina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'vitaminB2', 0.052),  -- Riboflavina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'vitaminB3', 0.756),  -- Niacina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'vitaminB5', 0.233),  -- Ácido Pantotênico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'vitaminB6', 0.24),  -- Vitamina B6
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'vitaminB9', 26),  -- Ácido fólico, total
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'folicAcid', 0),  -- Ácido fólico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'foodFolate', 26),  -- Folato, alimento
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'folateDfe', 26),  -- Folato, equivalente à medida diária
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'choline', 12.7),  -- Colina, total
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'vitaminB12', 0),  -- Vitamina B12
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'vitaminA', 45),  -- Vitamina A (atividade equivalente de retinol)
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'retinol', 0),  -- Retinol
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'betaCarotene', 369),  -- Betacaroteno
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'alphaCarotene', 353),  -- Alfacaroteno
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'vitaminAIu', 909),  -- Vitamina A (SI)
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'lycopene', 0),  -- Licopeno
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'luteinZeaxanthin', 28),  -- Luteína + zeaxantina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'vitaminE', 0.13),  -- Vitamina E (alfatocoferol)
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'vitaminDIu', 0),  -- Vitamina D
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'vitaminK', 0.7),  -- Vitamina K (filoquinona)
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'saturatedFat', 0.069),  -- Gorduras saturadas
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'lauricAcid', 0.001),  -- Ácido graxo láurico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'myristicAcid', 0.001),  -- Ácido graxo mirístico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'palmiticAcid', 0.047),  -- Ácido graxo palmítico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'stearicAcid', 0.002),  -- Ácido graxo esteárico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'monounsaturatedFat', 0.015),  -- Gorduras monoinsaturadas
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'palmitoleicAcid', 0.005),  -- Ácido graxo palmítico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'oleicAcid', 0.01),  -- Ácido graxo oléico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'polyunsaturatedFat', 0.033),  -- Gorduras poliinsaturadas
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'linoleicAcid', 0.021),  -- Ácido graxo linoléico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'ala', 0.012),  -- Ácido graxo linolênico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'cholesterol', 0),  -- Colesterol
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'tryptophan', 0.009),  -- Triptofano
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'threonine', 0.021),  -- Treonina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'isoleucine', 0.022),  -- Isoleucina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'leucine', 0.036),  -- Leucina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'lysine', 0.037),  -- Lisina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'methionine', 0.01),  -- Metionina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'cysteine', 0.012),  -- Cisteína
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'phenylalanine', 0.027),  -- Fenilalanina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'tyrosine', 0.02),  -- Tirosina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'valine', 0.028),  -- Valina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'arginine', 0.066),  -- Arginina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'histidine', 0.039),  -- Histidina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'alanine', 0.031),  -- Alanina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'asparticAcid', 0.065),  -- Aspartato
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'glutamicAcid', 0.07),  -- Glutamato
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'glycine', 0.027),  -- Glicina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'proline', 0.03),  -- Prolina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'serine', 0.025),  -- Serina
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'alcohol', 0),  -- Álcool
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'caffeine', 0),  -- Cafeína
  ('47604e86-3a61-5617-9a4b-0c0a3eddecdf', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
