-- Refrigerante, uva
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', null, 'Refrigerante, uva', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'water', 88.8),  -- Água
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'calories', 43),  -- Valor energético (kcal)
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'kilojoules', 180),  -- Valor energético (kJ)
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'protein', 0),  -- Proteína
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'fat', 0),  -- Gorduras totais
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'ash', 0.1),  -- Cinzas
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'carbohydrates', 11.2),  -- Carboidratos (por diferença)
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'fiber', 0),  -- Fibra alimentar
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'calcium', 3),  -- Cálcio
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'iron', 0.08),  -- Ferro
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'magnesium', 1),  -- Magnésio
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'phosphorus', 0),  -- Fósforo
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'potassium', 1),  -- Potássio
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'sodium', 15),  -- Sódio
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'zinc', 0.07),  -- Zinco
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'copper', 0.022),  -- Cobre
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'manganese', 0.013),  -- Manganês
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'selenium', 0),  -- Selênio
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'fluoride', 86.3),  -- Flúor
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'vitaminB1', 0),  -- Tiamina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'vitaminB2', 0),  -- Riboflavina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'vitaminB3', 0),  -- Niacina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'vitaminB5', 0),  -- Ácido Pantotênico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'vitaminB6', 0),  -- Vitamina B6
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'vitaminB9', 0),  -- Ácido fólico, total
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'folicAcid', 0),  -- Ácido fólico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'foodFolate', 0),  -- Folato, alimento
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'folateDfe', 0),  -- Folato, equivalente à medida diária
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'vitaminB12', 0),  -- Vitamina B12
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'vitaminA', 0),  -- Vitamina A (atividade equivalente de retinol)
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'retinol', 0),  -- Retinol
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'vitaminAIu', 0),  -- Vitamina A (SI)
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'saturatedFat', 0),  -- Gorduras saturadas
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'myristicAcid', 0),  -- Ácido graxo mirístico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'palmiticAcid', 0),  -- Ácido graxo palmítico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'stearicAcid', 0),  -- Ácido graxo esteárico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'monounsaturatedFat', 0),  -- Gorduras monoinsaturadas
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'palmitoleicAcid', 0),  -- Ácido graxo palmítico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'oleicAcid', 0),  -- Ácido graxo oléico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'polyunsaturatedFat', 0),  -- Gorduras poliinsaturadas
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'linoleicAcid', 0),  -- Ácido graxo linoléico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'ala', 0),  -- Ácido graxo linolênico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'cholesterol', 0),  -- Colesterol
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'tryptophan', 0),  -- Triptofano
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'threonine', 0),  -- Treonina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'isoleucine', 0),  -- Isoleucina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'leucine', 0),  -- Leucina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'lysine', 0),  -- Lisina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'methionine', 0),  -- Metionina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'cysteine', 0),  -- Cisteína
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'phenylalanine', 0),  -- Fenilalanina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'tyrosine', 0),  -- Tirosina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'valine', 0),  -- Valina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'arginine', 0),  -- Arginina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'histidine', 0),  -- Histidina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'alanine', 0),  -- Alanina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'asparticAcid', 0),  -- Aspartato
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'glutamicAcid', 0),  -- Glutamato
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'glycine', 0),  -- Glicina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'proline', 0),  -- Prolina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'serine', 0),  -- Serina
  ('14b0065f-49cc-5c59-aa85-b4a1c3c3af5b', 'alcohol', 0)  -- Álcool
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
