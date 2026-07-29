-- Banana, crua
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
values ('0216269d-1f77-53c8-adb8-4ab3db55e68e', null, 'Banana, crua', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'water', 74.91),  -- Água
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'calories', 89),  -- Valor energético (kcal)
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'kilojoules', 371),  -- Valor energético (kJ)
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'protein', 1.09),  -- Proteína
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'fat', 0.33),  -- Gorduras totais
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'ash', 0.82),  -- Cinzas
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'carbohydrates', 22.84),  -- Carboidratos (por diferença)
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'fiber', 2.6),  -- Fibra alimentar
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'monosaccharides', 12.23),  -- Monossacarídeos
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'sucrose', 2.39),  -- Sacarose
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'glucose', 4.98),  -- Glicose
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'fructose', 4.85),  -- Frutose
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'lactose', 0),  -- Lactose
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'maltose', 0.01),  -- Maltose
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'galactose', 0),  -- Galactose
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'starch', 5.38),  -- Amido
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'calcium', 5),  -- Cálcio
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'iron', 0.26),  -- Ferro
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'magnesium', 27),  -- Magnésio
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'phosphorus', 22),  -- Fósforo
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'potassium', 358),  -- Potássio
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'sodium', 1),  -- Sódio
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'zinc', 0.15),  -- Zinco
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'copper', 0.078),  -- Cobre
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'manganese', 0.27),  -- Manganês
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'selenium', 1),  -- Selênio
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'fluoride', 2.2),  -- Flúor
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'vitaminC', 8.7),  -- Vitamina C, ácido ascórbico total
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'vitaminB1', 0.031),  -- Tiamina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'vitaminB2', 0.073),  -- Riboflavina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'vitaminB3', 0.665),  -- Niacina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'vitaminB5', 0.334),  -- Ácido Pantotênico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'vitaminB6', 0.367),  -- Vitamina B6
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'vitaminB9', 20),  -- Ácido fólico, total
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'folicAcid', 0),  -- Ácido fólico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'foodFolate', 20),  -- Folato, alimento
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'folateDfe', 20),  -- Folato, equivalente à medida diária
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'choline', 9.8),  -- Colina, total
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'betaine', 0.1),  -- Betaína
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'vitaminB12', 0),  -- Vitamina B12
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'vitaminA', 3),  -- Vitamina A (atividade equivalente de retinol)
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'retinol', 0),  -- Retinol
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'betaCarotene', 26),  -- Betacaroteno
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'alphaCarotene', 25),  -- Alfacaroteno
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'vitaminAIu', 64),  -- Vitamina A (SI)
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'lycopene', 0),  -- Licopeno
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'luteinZeaxanthin', 22),  -- Luteína + zeaxantina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'vitaminE', 0.1),  -- Vitamina E (alfatocoferol)
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'betaTocopherol', 0),  -- Beta-tocoferol
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'gammaTocopherol', 0.02),  -- Gama-tocoferol
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'deltaTocopherol', 0.01),  -- Delta-tocoferol
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'alphaTocotrienol', 0.06),  -- Tocotrienol, alpha
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'betaTocotrienol', 0),  -- Tocotrienol, beta
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'gammaTocotrienol', 0),  -- Tocotrienol, gamma
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'deltaTocotrienol', 0),  -- Tocotrienol, delta
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'vitaminDIu', 0),  -- Vitamina D
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'vitaminK', 0.5),  -- Vitamina K (filoquinona)
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'dihydrophylloquinone', 0),  -- Dihidrofiloquinona
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'saturatedFat', 0.112),  -- Gorduras saturadas
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'capricAcid', 0.001),  -- Ácido graxo cáprico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'lauricAcid', 0.002),  -- Ácido graxo láurico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'myristicAcid', 0.002),  -- Ácido graxo mirístico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'palmiticAcid', 0.102),  -- Ácido graxo palmítico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'stearicAcid', 0.005),  -- Ácido graxo esteárico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'monounsaturatedFat', 0.032),  -- Gorduras monoinsaturadas
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'palmitoleicAcid', 0.01),  -- Ácido graxo palmítico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'oleicAcid', 0.022),  -- Ácido graxo oléico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'polyunsaturatedFat', 0.073),  -- Gorduras poliinsaturadas
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'linoleicAcid', 0.046),  -- Ácido graxo linoléico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'ala', 0.027),  -- Ácido graxo linolênico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'cholesterol', 0),  -- Colesterol
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'tryptophan', 0.009),  -- Triptofano
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'threonine', 0.028),  -- Treonina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'isoleucine', 0.028),  -- Isoleucina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'leucine', 0.068),  -- Leucina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'lysine', 0.05),  -- Lisina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'methionine', 0.008),  -- Metionina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'cysteine', 0.009),  -- Cisteína
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'phenylalanine', 0.049),  -- Fenilalanina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'tyrosine', 0.009),  -- Tirosina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'valine', 0.047),  -- Valina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'arginine', 0.049),  -- Arginina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'histidine', 0.077),  -- Histidina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'alanine', 0.04),  -- Alanina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'asparticAcid', 0.124),  -- Aspartato
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'glutamicAcid', 0.152),  -- Glutamato
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'glycine', 0.038),  -- Glicina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'proline', 0.028),  -- Prolina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'serine', 0.04),  -- Serina
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'alcohol', 0),  -- Álcool
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'caffeine', 0),  -- Cafeína
  ('0216269d-1f77-53c8-adb8-4ab3db55e68e', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
