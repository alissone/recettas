-- Arroz, branco, grao longo, normal, cozido, nao enriquecido, com sal
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', null, 'Arroz, branco, grao longo, normal, cozido, nao enriquecido, com sal', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'water', 68.44),  -- Água
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'calories', 130),  -- Valor energético (kcal)
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'kilojoules', 544),  -- Valor energético (kJ)
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'protein', 2.69),  -- Proteína
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'fat', 0.28),  -- Gorduras totais
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'ash', 0.41),  -- Cinzas
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'carbohydrates', 28.17),  -- Carboidratos (por diferença)
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'fiber', 0.4),  -- Fibra alimentar
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'monosaccharides', 0.05),  -- Monossacarídeos
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'calcium', 10),  -- Cálcio
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'iron', 0.2),  -- Ferro
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'magnesium', 12),  -- Magnésio
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'phosphorus', 43),  -- Fósforo
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'potassium', 35),  -- Potássio
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'sodium', 382),  -- Sódio
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'zinc', 0.49),  -- Zinco
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'copper', 0.069),  -- Cobre
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'manganese', 0.472),  -- Manganês
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'selenium', 7.5),  -- Selênio
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'vitaminB1', 0.02),  -- Tiamina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'vitaminB2', 0.013),  -- Riboflavina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'vitaminB3', 0.4),  -- Niacina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'vitaminB5', 0.39),  -- Ácido Pantotênico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'vitaminB6', 0.093),  -- Vitamina B6
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'vitaminB9', 3),  -- Ácido fólico, total
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'folicAcid', 0),  -- Ácido fólico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'foodFolate', 3),  -- Folato, alimento
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'folateDfe', 3),  -- Folato, equivalente à medida diária
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'choline', 2.1),  -- Colina, total
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'vitaminB12', 0),  -- Vitamina B12
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'vitaminA', 0),  -- Vitamina A (atividade equivalente de retinol)
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'retinol', 0),  -- Retinol
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'betaCarotene', 0),  -- Betacaroteno
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'alphaCarotene', 0),  -- Alfacaroteno
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'vitaminAIu', 0),  -- Vitamina A (SI)
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'lycopene', 0),  -- Licopeno
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'luteinZeaxanthin', 0),  -- Luteína + zeaxantina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'vitaminE', 0.04),  -- Vitamina E (alfatocoferol)
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'vitaminDIu', 0),  -- Vitamina D
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'vitaminK', 0),  -- Vitamina K (filoquinona)
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'saturatedFat', 0.077),  -- Gorduras saturadas
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'myristicAcid', 0.002),  -- Ácido graxo mirístico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'palmiticAcid', 0.069),  -- Ácido graxo palmítico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'stearicAcid', 0.005),  -- Ácido graxo esteárico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'monounsaturatedFat', 0.088),  -- Gorduras monoinsaturadas
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'palmitoleicAcid', 0.001),  -- Ácido graxo palmítico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'oleicAcid', 0.087),  -- Ácido graxo oléico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'polyunsaturatedFat', 0.076),  -- Gorduras poliinsaturadas
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'linoleicAcid', 0.062),  -- Ácido graxo linoléico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'ala', 0.013),  -- Ácido graxo linolênico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'cholesterol', 0),  -- Colesterol
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'tryptophan', 0.031),  -- Triptofano
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'threonine', 0.096),  -- Treonina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'isoleucine', 0.116),  -- Isoleucina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'leucine', 0.222),  -- Leucina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'lysine', 0.097),  -- Lisina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'methionine', 0.063),  -- Metionina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'cysteine', 0.055),  -- Cisteína
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'phenylalanine', 0.144),  -- Fenilalanina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'tyrosine', 0.09),  -- Tirosina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'valine', 0.164),  -- Valina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'arginine', 0.224),  -- Arginina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'histidine', 0.063),  -- Histidina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'alanine', 0.156),  -- Alanina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'asparticAcid', 0.253),  -- Aspartato
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'glutamicAcid', 0.524),  -- Glutamato
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'glycine', 0.122),  -- Glicina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'proline', 0.127),  -- Prolina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'serine', 0.141),  -- Serina
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'alcohol', 0),  -- Álcool
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'caffeine', 0),  -- Cafeína
  ('c44a3168-d4f1-59b7-b4c4-b8e0cdc8c88f', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
