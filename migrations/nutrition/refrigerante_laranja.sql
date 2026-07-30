-- Refrigerante, laranja
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('914fa45b-8e01-5247-a413-480771d1acc2', null, 'Refrigerante, laranja', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'water', 87.6),  -- Água
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'calories', 48),  -- Valor energético (kcal)
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'kilojoules', 201),  -- Valor energético (kJ)
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'protein', 0),  -- Proteína
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'fat', 0),  -- Gorduras totais
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'ash', 0.1),  -- Cinzas
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'carbohydrates', 12.3),  -- Carboidratos (por diferença)
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'fiber', 0),  -- Fibra alimentar
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'calcium', 5),  -- Cálcio
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'iron', 0.06),  -- Ferro
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'magnesium', 1),  -- Magnésio
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'phosphorus', 1),  -- Fósforo
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'potassium', 2),  -- Potássio
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'sodium', 12),  -- Sódio
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'zinc', 0.1),  -- Zinco
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'copper', 0.015),  -- Cobre
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'manganese', 0.013),  -- Manganês
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'selenium', 0),  -- Selênio
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'fluoride', 80.6),  -- Flúor
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'vitaminB1', 0),  -- Tiamina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'vitaminB2', 0),  -- Riboflavina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'vitaminB3', 0),  -- Niacina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'vitaminB5', 0),  -- Ácido Pantotênico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'vitaminB6', 0),  -- Vitamina B6
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'vitaminB9', 0),  -- Ácido fólico, total
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'folicAcid', 0),  -- Ácido fólico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'foodFolate', 0),  -- Folato, alimento
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'folateDfe', 0),  -- Folato, equivalente à medida diária
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'choline', 0.6),  -- Colina, total
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'betaine', 0.1),  -- Betaína
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'vitaminB12', 0),  -- Vitamina B12
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'vitaminA', 0),  -- Vitamina A (atividade equivalente de retinol)
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'retinol', 0),  -- Retinol
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'vitaminAIu', 0),  -- Vitamina A (SI)
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'saturatedFat', 0),  -- Gorduras saturadas
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'myristicAcid', 0),  -- Ácido graxo mirístico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'palmiticAcid', 0),  -- Ácido graxo palmítico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'stearicAcid', 0),  -- Ácido graxo esteárico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'monounsaturatedFat', 0),  -- Gorduras monoinsaturadas
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'palmitoleicAcid', 0),  -- Ácido graxo palmítico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'oleicAcid', 0),  -- Ácido graxo oléico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'polyunsaturatedFat', 0),  -- Gorduras poliinsaturadas
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'linoleicAcid', 0),  -- Ácido graxo linoléico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'ala', 0),  -- Ácido graxo linolênico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'cholesterol', 0),  -- Colesterol
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'tryptophan', 0),  -- Triptofano
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'threonine', 0),  -- Treonina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'isoleucine', 0),  -- Isoleucina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'leucine', 0),  -- Leucina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'lysine', 0),  -- Lisina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'methionine', 0),  -- Metionina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'cysteine', 0),  -- Cisteína
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'phenylalanine', 0),  -- Fenilalanina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'tyrosine', 0),  -- Tirosina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'valine', 0),  -- Valina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'arginine', 0),  -- Arginina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'histidine', 0),  -- Histidina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'alanine', 0),  -- Alanina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'asparticAcid', 0),  -- Aspartato
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'glutamicAcid', 0),  -- Glutamato
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'glycine', 0),  -- Glicina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'proline', 0),  -- Prolina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'serine', 0),  -- Serina
  ('914fa45b-8e01-5247-a413-480771d1acc2', 'alcohol', 0)  -- Álcool
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
