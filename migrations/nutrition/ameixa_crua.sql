-- Ameixa, crua
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.
--
-- Nutrientes do relatorio sem correspondencia no catalogo,
-- portanto NAO importados:
--   Fitosterol

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', null, 'Ameixa, crua', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'water', 87.23),  -- Água
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'calories', 46),  -- Valor energético (kcal)
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'kilojoules', 192),  -- Valor energético (kJ)
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'protein', 0.7),  -- Proteína
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'fat', 0.28),  -- Gorduras totais
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'ash', 0.37),  -- Cinzas
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'carbohydrates', 11.42),  -- Carboidratos (por diferença)
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'fiber', 1.4),  -- Fibra alimentar
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'monosaccharides', 9.92),  -- Monossacarídeos
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'sucrose', 1.57),  -- Sacarose
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'glucose', 5.07),  -- Glicose
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'fructose', 3.07),  -- Frutose
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'lactose', 0),  -- Lactose
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'maltose', 0.08),  -- Maltose
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'galactose', 0.14),  -- Galactose
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'starch', 0),  -- Amido
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'calcium', 6),  -- Cálcio
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'iron', 0.17),  -- Ferro
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'magnesium', 7),  -- Magnésio
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'phosphorus', 16),  -- Fósforo
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'potassium', 157),  -- Potássio
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'sodium', 0),  -- Sódio
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'zinc', 0.1),  -- Zinco
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'copper', 0.057),  -- Cobre
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'manganese', 0.052),  -- Manganês
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'selenium', 0),  -- Selênio
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'fluoride', 2),  -- Flúor
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'vitaminC', 9.5),  -- Vitamina C, ácido ascórbico total
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'vitaminB1', 0.028),  -- Tiamina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'vitaminB2', 0.026),  -- Riboflavina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'vitaminB3', 0.417),  -- Niacina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'vitaminB5', 0.135),  -- Ácido Pantotênico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'vitaminB6', 0.029),  -- Vitamina B6
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'vitaminB9', 5),  -- Ácido fólico, total
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'folicAcid', 0),  -- Ácido fólico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'foodFolate', 5),  -- Folato, alimento
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'folateDfe', 5),  -- Folato, equivalente à medida diária
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'choline', 1.9),  -- Colina, total
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'vitaminB12', 0),  -- Vitamina B12
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'vitaminA', 17),  -- Vitamina A (atividade equivalente de retinol)
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'retinol', 0),  -- Retinol
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'betaCarotene', 190),  -- Betacaroteno
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'alphaCarotene', 0),  -- Alfacaroteno
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'betaCryptoxanthin', 35),  -- Beta-criptoxantina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'vitaminAIu', 345),  -- Vitamina A (SI)
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'lycopene', 0),  -- Licopeno
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'luteinZeaxanthin', 73),  -- Luteína + zeaxantina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'vitaminE', 0.26),  -- Vitamina E (alfatocoferol)
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'betaTocopherol', 0),  -- Beta-tocoferol
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'gammaTocopherol', 0.08),  -- Gama-tocoferol
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'deltaTocopherol', 0),  -- Delta-tocoferol
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'alphaTocotrienol', 0.04),  -- Tocotrienol, alpha
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'betaTocotrienol', 0),  -- Tocotrienol, beta
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'gammaTocotrienol', 0.01),  -- Tocotrienol, gamma
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'deltaTocotrienol', 0),  -- Tocotrienol, delta
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'vitaminDIu', 0),  -- Vitamina D
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'vitaminK', 6.4),  -- Vitamina K (filoquinona)
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'dihydrophylloquinone', 0),  -- Dihidrofiloquinona
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'saturatedFat', 0.017),  -- Gorduras saturadas
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'myristicAcid', 0),  -- Ácido graxo mirístico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'palmiticAcid', 0.014),  -- Ácido graxo palmítico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'stearicAcid', 0.003),  -- Ácido graxo esteárico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'monounsaturatedFat', 0.134),  -- Gorduras monoinsaturadas
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'palmitoleicAcid', 0.002),  -- Ácido graxo palmítico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'oleicAcid', 0.132),  -- Ácido graxo oléico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'polyunsaturatedFat', 0.044),  -- Gorduras poliinsaturadas
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'linoleicAcid', 0.044),  -- Ácido graxo linoléico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'ala', 0),  -- Ácido graxo linolênico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'cholesterol', 0),  -- Colesterol
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'tryptophan', 0.009),  -- Triptofano
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'threonine', 0.01),  -- Treonina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'isoleucine', 0.014),  -- Isoleucina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'leucine', 0.015),  -- Leucina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'lysine', 0.016),  -- Lisina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'methionine', 0.008),  -- Metionina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'cysteine', 0.002),  -- Cisteína
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'phenylalanine', 0.014),  -- Fenilalanina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'tyrosine', 0.008),  -- Tirosina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'valine', 0.016),  -- Valina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'arginine', 0.009),  -- Arginina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'histidine', 0.009),  -- Histidina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'alanine', 0.028),  -- Alanina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'asparticAcid', 0.352),  -- Aspartato
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'glutamicAcid', 0.035),  -- Glutamato
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'glycine', 0.009),  -- Glicina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'proline', 0.027),  -- Prolina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'serine', 0.023),  -- Serina
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'alcohol', 0),  -- Álcool
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'caffeine', 0),  -- Cafeína
  ('b8f44b8b-16cf-53c4-ad50-70e49a086a7e', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
