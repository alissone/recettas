-- Queijo, cheddar
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('0fabc870-8b1c-5120-842a-f58572a3d871', null, 'Queijo, cheddar', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'water', 36.75),  -- Água
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'calories', 403),  -- Valor energético (kcal)
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'kilojoules', 1684),  -- Valor energético (kJ)
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'protein', 24.9),  -- Proteína
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'fat', 33.14),  -- Gorduras totais
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'ash', 3.93),  -- Cinzas
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'carbohydrates', 1.28),  -- Carboidratos (por diferença)
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'fiber', 0),  -- Fibra alimentar
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'monosaccharides', 0.52),  -- Monossacarídeos
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'sucrose', 0.24),  -- Sacarose
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'lactose', 0.23),  -- Lactose
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'maltose', 0.15),  -- Maltose
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'calcium', 721),  -- Cálcio
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'iron', 0.68),  -- Ferro
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'magnesium', 28),  -- Magnésio
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'phosphorus', 512),  -- Fósforo
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'potassium', 98),  -- Potássio
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'sodium', 621),  -- Sódio
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'zinc', 3.11),  -- Zinco
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'copper', 0.031),  -- Cobre
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'manganese', 0.01),  -- Manganês
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'selenium', 13.9),  -- Selênio
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'fluoride', 34.9),  -- Flúor
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminB1', 0.027),  -- Tiamina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminB2', 0.375),  -- Riboflavina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminB3', 0.08),  -- Niacina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminB5', 0.413),  -- Ácido Pantotênico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminB6', 0.074),  -- Vitamina B6
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminB9', 18),  -- Ácido fólico, total
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'folicAcid', 0),  -- Ácido fólico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'foodFolate', 18),  -- Folato, alimento
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'folateDfe', 18),  -- Folato, equivalente à medida diária
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'choline', 16.5),  -- Colina, total
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'betaine', 0.7),  -- Betaína
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminB12', 0.83),  -- Vitamina B12
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminA', 265),  -- Vitamina A (atividade equivalente de retinol)
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'retinol', 258),  -- Retinol
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'betaCarotene', 85),  -- Betacaroteno
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'alphaCarotene', 0),  -- Alfacaroteno
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminAIu', 1002),  -- Vitamina A (SI)
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'lycopene', 0),  -- Licopeno
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'luteinZeaxanthin', 0),  -- Luteína + zeaxantina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminE', 0.29),  -- Vitamina E (alfatocoferol)
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'gammaTocopherol', 0),  -- Gama-tocoferol
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'deltaTocopherol', 0),  -- Delta-tocoferol
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminD', 0.6),  -- Vitamina D (D2 + D3)
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminD3', 0.6),  -- Vitamina D3 (colecalciferol)
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminDIu', 24),  -- Vitamina D
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'vitaminK', 2.8),  -- Vitamina K (filoquinona)
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'dihydrophylloquinone', 0),  -- Dihidrofiloquinona
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'saturatedFat', 21.092),  -- Gorduras saturadas
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'butyricAcid', 1.046),  -- Ácido graxo butírico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'caproicAcid', 0.529),  -- Ácido graxo capróico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'caprylicAcid', 0.279),  -- Ácido graxo caprílico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'capricAcid', 0.6),  -- Ácido graxo cáprico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'lauricAcid', 0.541),  -- Ácido graxo láurico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'myristicAcid', 3.33),  -- Ácido graxo mirístico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'palmiticAcid', 9.803),  -- Ácido graxo palmítico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'stearicAcid', 4.007),  -- Ácido graxo esteárico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'monounsaturatedFat', 9.391),  -- Gorduras monoinsaturadas
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'palmitoleicAcid', 1.004),  -- Ácido graxo palmítico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'oleicAcid', 7.905),  -- Ácido graxo oléico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'polyunsaturatedFat', 0.942),  -- Gorduras poliinsaturadas
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'linoleicAcid', 0.577),  -- Ácido graxo linoléico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'ala', 0.365),  -- Ácido graxo linolênico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'cholesterol', 105),  -- Colesterol
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'tryptophan', 0.32),  -- Triptofano
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'threonine', 0.886),  -- Treonina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'isoleucine', 1.546),  -- Isoleucina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'leucine', 2.385),  -- Leucina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'lysine', 2.072),  -- Lisina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'methionine', 0.652),  -- Metionina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'cysteine', 0.125),  -- Cisteína
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'phenylalanine', 1.311),  -- Fenilalanina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'tyrosine', 1.202),  -- Tirosina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'valine', 1.663),  -- Valina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'arginine', 0.941),  -- Arginina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'histidine', 0.874),  -- Histidina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'alanine', 0.703),  -- Alanina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'asparticAcid', 1.6),  -- Aspartato
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'glutamicAcid', 6.092),  -- Glutamato
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'glycine', 0.429),  -- Glicina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'proline', 2.806),  -- Prolina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'serine', 1.456),  -- Serina
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'alcohol', 0),  -- Álcool
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'caffeine', 0),  -- Cafeína
  ('0fabc870-8b1c-5120-842a-f58572a3d871', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
