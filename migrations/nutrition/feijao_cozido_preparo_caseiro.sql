-- Feijao, cozido, preparo caseiro
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', null, 'Feijao, cozido, preparo caseiro', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'water', 65.17),  -- Água
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'calories', 155),  -- Valor energético (kcal)
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'kilojoules', 649),  -- Valor energético (kJ)
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'protein', 5.54),  -- Proteína
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'fat', 5.15),  -- Gorduras totais
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'ash', 2.51),  -- Cinzas
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'carbohydrates', 21.63),  -- Carboidratos (por diferença)
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'fiber', 5.5),  -- Fibra alimentar
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'calcium', 61),  -- Cálcio
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'iron', 1.99),  -- Ferro
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'magnesium', 43),  -- Magnésio
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'phosphorus', 109),  -- Fósforo
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'potassium', 358),  -- Potássio
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'sodium', 422),  -- Sódio
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'zinc', 0.73),  -- Zinco
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'copper', 0.159),  -- Cobre
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'manganese', 0.255),  -- Manganês
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'selenium', 5.7),  -- Selênio
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'vitaminC', 1.1),  -- Vitamina C, ácido ascórbico total
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'vitaminB1', 0.136),  -- Tiamina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'vitaminB2', 0.049),  -- Riboflavina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'vitaminB3', 0.408),  -- Niacina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'vitaminB5', 0.155),  -- Ácido Pantotênico
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'vitaminB6', 0.09),  -- Vitamina B6
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'vitaminB9', 48),  -- Ácido fólico, total
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'folicAcid', 0),  -- Ácido fólico
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'foodFolate', 48),  -- Folato, alimento
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'folateDfe', 48),  -- Folato, equivalente à medida diária
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'vitaminB12', 0),  -- Vitamina B12
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'vitaminA', 0),  -- Vitamina A (atividade equivalente de retinol)
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'retinol', 0),  -- Retinol
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'vitaminAIu', 0),  -- Vitamina A (SI)
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'vitaminDIu', 0),  -- Vitamina D
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'saturatedFat', 1.948),  -- Gorduras saturadas
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'capricAcid', 0.005),  -- Ácido graxo cáprico
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'lauricAcid', 0.009),  -- Ácido graxo láurico
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'myristicAcid', 0.061),  -- Ácido graxo mirístico
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'palmiticAcid', 1.227),  -- Ácido graxo palmítico
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'stearicAcid', 0.633),  -- Ácido graxo esteárico
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'monounsaturatedFat', 2.133),  -- Gorduras monoinsaturadas
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'palmitoleicAcid', 0.125),  -- Ácido graxo palmítico
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'oleicAcid', 1.953),  -- Ácido graxo oléico
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'gadoleicAcid', 0.046),  -- Ácido graxo gadoléico
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'polyunsaturatedFat', 0.74),  -- Gorduras poliinsaturadas
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'linoleicAcid', 0.593),  -- Ácido graxo linoléico
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'ala', 0.147),  -- Ácido graxo linolênico
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'cholesterol', 5),  -- Colesterol
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'tryptophan', 0.067),  -- Triptofano
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'threonine', 0.228),  -- Treonina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'isoleucine', 0.242),  -- Isoleucina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'leucine', 0.428),  -- Leucina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'lysine', 0.379),  -- Lisina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'methionine', 0.086),  -- Metionina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'cysteine', 0.062),  -- Cisteína
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'phenylalanine', 0.287),  -- Fenilalanina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'tyrosine', 0.155),  -- Tirosina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'valine', 0.282),  -- Valina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'arginine', 0.356),  -- Arginina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'histidine', 0.153),  -- Histidina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'alanine', 0.236),  -- Alanina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'asparticAcid', 0.637),  -- Aspartato
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'glutamicAcid', 0.841),  -- Glutamato
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'glycine', 0.232),  -- Glicina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'proline', 0.239),  -- Prolina
  ('cd5dbe9c-13de-5eff-8bed-bab4ad873b11', 'serine', 0.288)  -- Serina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
