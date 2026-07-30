-- Mel, coado ou por extracao
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', null, 'Mel, coado ou por extracao', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'water', 17.1),  -- Água
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'calories', 304),  -- Valor energético (kcal)
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'kilojoules', 1272),  -- Valor energético (kJ)
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'protein', 0.3),  -- Proteína
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'fat', 0),  -- Gorduras totais
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'ash', 0.2),  -- Cinzas
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'carbohydrates', 82.4),  -- Carboidratos (por diferença)
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'fiber', 0.2),  -- Fibra alimentar
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'monosaccharides', 82.12),  -- Monossacarídeos
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'sucrose', 0.89),  -- Sacarose
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'glucose', 35.75),  -- Glicose
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'fructose', 40.94),  -- Frutose
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'maltose', 1.44),  -- Maltose
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'galactose', 3.1),  -- Galactose
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'calcium', 6),  -- Cálcio
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'iron', 0.42),  -- Ferro
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'magnesium', 2),  -- Magnésio
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'phosphorus', 4),  -- Fósforo
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'potassium', 52),  -- Potássio
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'sodium', 4),  -- Sódio
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'zinc', 0.22),  -- Zinco
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'copper', 0.036),  -- Cobre
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'manganese', 0.08),  -- Manganês
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'selenium', 0.8),  -- Selênio
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'fluoride', 7),  -- Flúor
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'vitaminC', 0.5),  -- Vitamina C, ácido ascórbico total
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'vitaminB1', 0),  -- Tiamina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'vitaminB2', 0.038),  -- Riboflavina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'vitaminB3', 0.121),  -- Niacina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'vitaminB5', 0.068),  -- Ácido Pantotênico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'vitaminB6', 0.024),  -- Vitamina B6
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'vitaminB9', 2),  -- Ácido fólico, total
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'folicAcid', 0),  -- Ácido fólico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'foodFolate', 2),  -- Folato, alimento
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'folateDfe', 2),  -- Folato, equivalente à medida diária
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'choline', 2.2),  -- Colina, total
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'betaine', 1.7),  -- Betaína
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'vitaminB12', 0),  -- Vitamina B12
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'vitaminA', 0),  -- Vitamina A (atividade equivalente de retinol)
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'retinol', 0),  -- Retinol
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'betaCarotene', 0),  -- Betacaroteno
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'alphaCarotene', 0),  -- Alfacaroteno
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'vitaminAIu', 0),  -- Vitamina A (SI)
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'lycopene', 0),  -- Licopeno
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'luteinZeaxanthin', 0),  -- Luteína + zeaxantina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'vitaminE', 0),  -- Vitamina E (alfatocoferol)
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'vitaminDIu', 0),  -- Vitamina D
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'vitaminK', 0),  -- Vitamina K (filoquinona)
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'saturatedFat', 0),  -- Gorduras saturadas
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'myristicAcid', 0),  -- Ácido graxo mirístico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'palmiticAcid', 0),  -- Ácido graxo palmítico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'stearicAcid', 0),  -- Ácido graxo esteárico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'monounsaturatedFat', 0),  -- Gorduras monoinsaturadas
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'palmitoleicAcid', 0),  -- Ácido graxo palmítico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'oleicAcid', 0),  -- Ácido graxo oléico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'polyunsaturatedFat', 0),  -- Gorduras poliinsaturadas
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'linoleicAcid', 0),  -- Ácido graxo linoléico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'ala', 0),  -- Ácido graxo linolênico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'cholesterol', 0),  -- Colesterol
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'tryptophan', 0.004),  -- Triptofano
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'threonine', 0.004),  -- Treonina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'isoleucine', 0.008),  -- Isoleucina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'leucine', 0.01),  -- Leucina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'lysine', 0.008),  -- Lisina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'methionine', 0.001),  -- Metionina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'cysteine', 0.003),  -- Cisteína
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'phenylalanine', 0.011),  -- Fenilalanina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'tyrosine', 0.008),  -- Tirosina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'valine', 0.009),  -- Valina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'arginine', 0.005),  -- Arginina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'histidine', 0.001),  -- Histidina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'alanine', 0.006),  -- Alanina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'asparticAcid', 0.027),  -- Aspartato
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'glutamicAcid', 0.018),  -- Glutamato
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'glycine', 0.007),  -- Glicina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'proline', 0.09),  -- Prolina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'serine', 0.006),  -- Serina
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'alcohol', 0),  -- Álcool
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'caffeine', 0),  -- Cafeína
  ('9ef7a04e-ea19-5b9e-bf5b-39c32e21face', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
