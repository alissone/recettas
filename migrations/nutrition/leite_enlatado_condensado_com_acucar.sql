-- Leite, enlatado, condensado, com acucar
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('201db0e9-33ac-5549-ab26-4b5536ce9897', null, 'Leite, enlatado, condensado, com acucar', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'water', 27.16),  -- Água
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'calories', 321),  -- Valor energético (kcal)
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'kilojoules', 1342),  -- Valor energético (kJ)
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'protein', 7.91),  -- Proteína
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'fat', 8.7),  -- Gorduras totais
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'ash', 1.83),  -- Cinzas
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'carbohydrates', 54.4),  -- Carboidratos (por diferença)
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'fiber', 0),  -- Fibra alimentar
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'monosaccharides', 54.4),  -- Monossacarídeos
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'calcium', 284),  -- Cálcio
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'iron', 0.19),  -- Ferro
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'magnesium', 26),  -- Magnésio
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'phosphorus', 253),  -- Fósforo
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'potassium', 371),  -- Potássio
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'sodium', 127),  -- Sódio
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'zinc', 0.94),  -- Zinco
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'copper', 0.015),  -- Cobre
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'manganese', 0.006),  -- Manganês
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'selenium', 14.8),  -- Selênio
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminC', 2.6),  -- Vitamina C, ácido ascórbico total
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminB1', 0.09),  -- Tiamina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminB2', 0.416),  -- Riboflavina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminB3', 0.21),  -- Niacina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminB5', 0.75),  -- Ácido Pantotênico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminB6', 0.051),  -- Vitamina B6
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminB9', 11),  -- Ácido fólico, total
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'folicAcid', 0),  -- Ácido fólico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'foodFolate', 11),  -- Folato, alimento
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'folateDfe', 11),  -- Folato, equivalente à medida diária
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'choline', 89.1),  -- Colina, total
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminB12', 0.44),  -- Vitamina B12
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminA', 74),  -- Vitamina A (atividade equivalente de retinol)
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'retinol', 73),  -- Retinol
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'betaCarotene', 14),  -- Betacaroteno
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'alphaCarotene', 0),  -- Alfacaroteno
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminAIu', 267),  -- Vitamina A (SI)
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'lycopene', 0),  -- Licopeno
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'luteinZeaxanthin', 0),  -- Luteína + zeaxantina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminE', 0.16),  -- Vitamina E (alfatocoferol)
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminD', 0.2),  -- Vitamina D (D2 + D3)
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminD3', 0.2),  -- Vitamina D3 (colecalciferol)
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminDIu', 6),  -- Vitamina D
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'vitaminK', 0.6),  -- Vitamina K (filoquinona)
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'saturatedFat', 5.486),  -- Gorduras saturadas
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'butyricAcid', 0.282),  -- Ácido graxo butírico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'caproicAcid', 0.167),  -- Ácido graxo capróico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'caprylicAcid', 0.097),  -- Ácido graxo caprílico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'capricAcid', 0.073),  -- Ácido graxo cáprico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'lauricAcid', 0.18),  -- Ácido graxo láurico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'myristicAcid', 0.783),  -- Ácido graxo mirístico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'palmiticAcid', 2.396),  -- Ácido graxo palmítico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'stearicAcid', 1.209),  -- Ácido graxo esteárico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'monounsaturatedFat', 2.427),  -- Gorduras monoinsaturadas
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'palmitoleicAcid', 0.137),  -- Ácido graxo palmítico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'oleicAcid', 2.188),  -- Ácido graxo oléico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'polyunsaturatedFat', 0.337),  -- Gorduras poliinsaturadas
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'linoleicAcid', 0.216),  -- Ácido graxo linoléico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'ala', 0.121),  -- Ácido graxo linolênico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'cholesterol', 34),  -- Colesterol
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'tryptophan', 0.112),  -- Triptofano
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'threonine', 0.357),  -- Treonina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'isoleucine', 0.479),  -- Isoleucina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'leucine', 0.775),  -- Leucina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'lysine', 0.627),  -- Lisina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'methionine', 0.198),  -- Metionina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'cysteine', 0.073),  -- Cisteína
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'phenylalanine', 0.382),  -- Fenilalanina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'tyrosine', 0.382),  -- Tirosina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'valine', 0.529),  -- Valina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'arginine', 0.286),  -- Arginina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'histidine', 0.214),  -- Histidina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'alanine', 0.273),  -- Alanina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'asparticAcid', 0.6),  -- Aspartato
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'glutamicAcid', 1.656),  -- Glutamato
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'glycine', 0.167),  -- Glicina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'proline', 0.766),  -- Prolina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'serine', 0.43),  -- Serina
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'alcohol', 0),  -- Álcool
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'caffeine', 0),  -- Cafeína
  ('201db0e9-33ac-5549-ab26-4b5536ce9897', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
