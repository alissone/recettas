-- Melancia, crua
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
values ('a409757b-a290-569b-846d-ecc22cca218e', null, 'Melancia, crua', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('a409757b-a290-569b-846d-ecc22cca218e', 'water', 91.45),  -- Água
  ('a409757b-a290-569b-846d-ecc22cca218e', 'calories', 30),  -- Valor energético (kcal)
  ('a409757b-a290-569b-846d-ecc22cca218e', 'kilojoules', 127),  -- Valor energético (kJ)
  ('a409757b-a290-569b-846d-ecc22cca218e', 'protein', 0.61),  -- Proteína
  ('a409757b-a290-569b-846d-ecc22cca218e', 'fat', 0.15),  -- Gorduras totais
  ('a409757b-a290-569b-846d-ecc22cca218e', 'ash', 0.25),  -- Cinzas
  ('a409757b-a290-569b-846d-ecc22cca218e', 'carbohydrates', 7.55),  -- Carboidratos (por diferença)
  ('a409757b-a290-569b-846d-ecc22cca218e', 'fiber', 0.4),  -- Fibra alimentar
  ('a409757b-a290-569b-846d-ecc22cca218e', 'monosaccharides', 6.2),  -- Monossacarídeos
  ('a409757b-a290-569b-846d-ecc22cca218e', 'sucrose', 1.21),  -- Sacarose
  ('a409757b-a290-569b-846d-ecc22cca218e', 'glucose', 1.58),  -- Glicose
  ('a409757b-a290-569b-846d-ecc22cca218e', 'fructose', 3.36),  -- Frutose
  ('a409757b-a290-569b-846d-ecc22cca218e', 'lactose', 0),  -- Lactose
  ('a409757b-a290-569b-846d-ecc22cca218e', 'maltose', 0.06),  -- Maltose
  ('a409757b-a290-569b-846d-ecc22cca218e', 'galactose', 0),  -- Galactose
  ('a409757b-a290-569b-846d-ecc22cca218e', 'starch', 0),  -- Amido
  ('a409757b-a290-569b-846d-ecc22cca218e', 'calcium', 7),  -- Cálcio
  ('a409757b-a290-569b-846d-ecc22cca218e', 'iron', 0.24),  -- Ferro
  ('a409757b-a290-569b-846d-ecc22cca218e', 'magnesium', 10),  -- Magnésio
  ('a409757b-a290-569b-846d-ecc22cca218e', 'phosphorus', 11),  -- Fósforo
  ('a409757b-a290-569b-846d-ecc22cca218e', 'potassium', 112),  -- Potássio
  ('a409757b-a290-569b-846d-ecc22cca218e', 'sodium', 1),  -- Sódio
  ('a409757b-a290-569b-846d-ecc22cca218e', 'zinc', 0.1),  -- Zinco
  ('a409757b-a290-569b-846d-ecc22cca218e', 'copper', 0.042),  -- Cobre
  ('a409757b-a290-569b-846d-ecc22cca218e', 'manganese', 0.038),  -- Manganês
  ('a409757b-a290-569b-846d-ecc22cca218e', 'selenium', 0.4),  -- Selênio
  ('a409757b-a290-569b-846d-ecc22cca218e', 'fluoride', 1.5),  -- Flúor
  ('a409757b-a290-569b-846d-ecc22cca218e', 'vitaminC', 8.1),  -- Vitamina C, ácido ascórbico total
  ('a409757b-a290-569b-846d-ecc22cca218e', 'vitaminB1', 0.033),  -- Tiamina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'vitaminB2', 0.021),  -- Riboflavina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'vitaminB3', 0.178),  -- Niacina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'vitaminB5', 0.221),  -- Ácido Pantotênico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'vitaminB6', 0.045),  -- Vitamina B6
  ('a409757b-a290-569b-846d-ecc22cca218e', 'vitaminB9', 3),  -- Ácido fólico, total
  ('a409757b-a290-569b-846d-ecc22cca218e', 'folicAcid', 0),  -- Ácido fólico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'foodFolate', 3),  -- Folato, alimento
  ('a409757b-a290-569b-846d-ecc22cca218e', 'folateDfe', 3),  -- Folato, equivalente à medida diária
  ('a409757b-a290-569b-846d-ecc22cca218e', 'choline', 4.1),  -- Colina, total
  ('a409757b-a290-569b-846d-ecc22cca218e', 'betaine', 0.3),  -- Betaína
  ('a409757b-a290-569b-846d-ecc22cca218e', 'vitaminB12', 0),  -- Vitamina B12
  ('a409757b-a290-569b-846d-ecc22cca218e', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('a409757b-a290-569b-846d-ecc22cca218e', 'vitaminA', 28),  -- Vitamina A (atividade equivalente de retinol)
  ('a409757b-a290-569b-846d-ecc22cca218e', 'retinol', 0),  -- Retinol
  ('a409757b-a290-569b-846d-ecc22cca218e', 'betaCarotene', 303),  -- Betacaroteno
  ('a409757b-a290-569b-846d-ecc22cca218e', 'alphaCarotene', 0),  -- Alfacaroteno
  ('a409757b-a290-569b-846d-ecc22cca218e', 'betaCryptoxanthin', 78),  -- Beta-criptoxantina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'vitaminAIu', 569),  -- Vitamina A (SI)
  ('a409757b-a290-569b-846d-ecc22cca218e', 'lycopene', 4532),  -- Licopeno
  ('a409757b-a290-569b-846d-ecc22cca218e', 'luteinZeaxanthin', 8),  -- Luteína + zeaxantina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'vitaminE', 0.05),  -- Vitamina E (alfatocoferol)
  ('a409757b-a290-569b-846d-ecc22cca218e', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('a409757b-a290-569b-846d-ecc22cca218e', 'betaTocopherol', 0),  -- Beta-tocoferol
  ('a409757b-a290-569b-846d-ecc22cca218e', 'gammaTocopherol', 0),  -- Gama-tocoferol
  ('a409757b-a290-569b-846d-ecc22cca218e', 'deltaTocopherol', 0),  -- Delta-tocoferol
  ('a409757b-a290-569b-846d-ecc22cca218e', 'alphaTocotrienol', 0.01),  -- Tocotrienol, alpha
  ('a409757b-a290-569b-846d-ecc22cca218e', 'betaTocotrienol', 0),  -- Tocotrienol, beta
  ('a409757b-a290-569b-846d-ecc22cca218e', 'gammaTocotrienol', 0),  -- Tocotrienol, gamma
  ('a409757b-a290-569b-846d-ecc22cca218e', 'deltaTocotrienol', 0),  -- Tocotrienol, delta
  ('a409757b-a290-569b-846d-ecc22cca218e', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('a409757b-a290-569b-846d-ecc22cca218e', 'vitaminDIu', 0),  -- Vitamina D
  ('a409757b-a290-569b-846d-ecc22cca218e', 'vitaminK', 0.1),  -- Vitamina K (filoquinona)
  ('a409757b-a290-569b-846d-ecc22cca218e', 'dihydrophylloquinone', 0),  -- Dihidrofiloquinona
  ('a409757b-a290-569b-846d-ecc22cca218e', 'saturatedFat', 0.016),  -- Gorduras saturadas
  ('a409757b-a290-569b-846d-ecc22cca218e', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'capricAcid', 0.001),  -- Ácido graxo cáprico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'lauricAcid', 0.001),  -- Ácido graxo láurico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'myristicAcid', 0),  -- Ácido graxo mirístico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'palmiticAcid', 0.008),  -- Ácido graxo palmítico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'stearicAcid', 0.006),  -- Ácido graxo esteárico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'monounsaturatedFat', 0.037),  -- Gorduras monoinsaturadas
  ('a409757b-a290-569b-846d-ecc22cca218e', 'palmitoleicAcid', 0),  -- Ácido graxo palmítico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'oleicAcid', 0.037),  -- Ácido graxo oléico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'polyunsaturatedFat', 0.05),  -- Gorduras poliinsaturadas
  ('a409757b-a290-569b-846d-ecc22cca218e', 'linoleicAcid', 0.05),  -- Ácido graxo linoléico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'ala', 0),  -- Ácido graxo linolênico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('a409757b-a290-569b-846d-ecc22cca218e', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('a409757b-a290-569b-846d-ecc22cca218e', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('a409757b-a290-569b-846d-ecc22cca218e', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('a409757b-a290-569b-846d-ecc22cca218e', 'cholesterol', 0),  -- Colesterol
  ('a409757b-a290-569b-846d-ecc22cca218e', 'tryptophan', 0.007),  -- Triptofano
  ('a409757b-a290-569b-846d-ecc22cca218e', 'threonine', 0.027),  -- Treonina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'isoleucine', 0.019),  -- Isoleucina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'leucine', 0.018),  -- Leucina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'lysine', 0.062),  -- Lisina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'methionine', 0.006),  -- Metionina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'cysteine', 0.002),  -- Cisteína
  ('a409757b-a290-569b-846d-ecc22cca218e', 'phenylalanine', 0.015),  -- Fenilalanina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'tyrosine', 0.012),  -- Tirosina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'valine', 0.016),  -- Valina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'arginine', 0.059),  -- Arginina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'histidine', 0.006),  -- Histidina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'alanine', 0.017),  -- Alanina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'asparticAcid', 0.039),  -- Aspartato
  ('a409757b-a290-569b-846d-ecc22cca218e', 'glutamicAcid', 0.063),  -- Glutamato
  ('a409757b-a290-569b-846d-ecc22cca218e', 'glycine', 0.01),  -- Glicina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'proline', 0.024),  -- Prolina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'serine', 0.016),  -- Serina
  ('a409757b-a290-569b-846d-ecc22cca218e', 'alcohol', 0),  -- Álcool
  ('a409757b-a290-569b-846d-ecc22cca218e', 'caffeine', 0),  -- Cafeína
  ('a409757b-a290-569b-846d-ecc22cca218e', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
