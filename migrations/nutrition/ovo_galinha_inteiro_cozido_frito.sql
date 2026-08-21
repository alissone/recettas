-- Ovo, galinha, inteiro, cozido, frito
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.
--
-- Nutrientes do relatorio sem correspondencia no catalogo,
-- portanto NAO importados:
--   Ácido graxo pentadecanóico
--   Ácido graxo be-hênico
--   Ácido graxo lignocérico
--   Ácido graxo pentadecenóico
--   Ácido graxo heptadecenóico
--   Ácido graxo tetracosenóico, cis
--   Ácido eicosadienóico, cis, n-6
--   Ácido graxo eicosatrienóico, indiferenciado
--   22:4
--   Fitosterol

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('15cc7547-662d-55bf-803c-bf16bd4455aa', null, 'Ovo, galinha, inteiro, cozido, frito', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'water', 69.47),  -- Água
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'calories', 196),  -- Valor energético (kcal)
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'kilojoules', 821),  -- Valor energético (kJ)
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'protein', 13.61),  -- Proteína
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'fat', 14.84),  -- Gorduras totais
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'ash', 1.26),  -- Cinzas
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'carbohydrates', 0.83),  -- Carboidratos (por diferença)
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'fiber', 0),  -- Fibra alimentar
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'monosaccharides', 0.4),  -- Monossacarídeos
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'sucrose', 0),  -- Sacarose
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'glucose', 0.4),  -- Glicose
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'fructose', 0),  -- Frutose
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'lactose', 0),  -- Lactose
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'maltose', 0),  -- Maltose
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'galactose', 0),  -- Galactose
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'calcium', 62),  -- Cálcio
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'iron', 1.89),  -- Ferro
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'magnesium', 13),  -- Magnésio
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'phosphorus', 215),  -- Fósforo
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'potassium', 152),  -- Potássio
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'sodium', 207),  -- Sódio
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'zinc', 1.39),  -- Zinco
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'copper', 0.078),  -- Cobre
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'manganese', 0.03),  -- Manganês
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'selenium', 33.1),  -- Selênio
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'fluoride', 1.2),  -- Flúor
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminB1', 0.044),  -- Tiamina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminB2', 0.495),  -- Riboflavina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminB3', 0.082),  -- Niacina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminB5', 1.66),  -- Ácido Pantotênico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminB6', 0.184),  -- Vitamina B6
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminB9', 51),  -- Ácido fólico, total
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'folicAcid', 0),  -- Ácido fólico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'foodFolate', 51),  -- Folato, alimento
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'folateDfe', 51),  -- Folato, equivalente à medida diária
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'choline', 317.1),  -- Colina, total
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'betaine', 0.3),  -- Betaína
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminB12', 0.97),  -- Vitamina B12
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminA', 219),  -- Vitamina A (atividade equivalente de retinol)
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'retinol', 216),  -- Retinol
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'betaCarotene', 35),  -- Betacaroteno
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'alphaCarotene', 0),  -- Alfacaroteno
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'betaCryptoxanthin', 10),  -- Beta-criptoxantina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminAIu', 787),  -- Vitamina A (SI)
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'lycopene', 0),  -- Licopeno
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'luteinZeaxanthin', 543),  -- Luteína + zeaxantina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminE', 1.31),  -- Vitamina E (alfatocoferol)
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'betaTocopherol', 0.02),  -- Beta-tocoferol
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'gammaTocopherol', 0.54),  -- Gama-tocoferol
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'deltaTocopherol', 0.06),  -- Delta-tocoferol
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'alphaTocotrienol', 0.06),  -- Tocotrienol, alpha
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'betaTocotrienol', 0),  -- Tocotrienol, beta
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'gammaTocotrienol', 0.01),  -- Tocotrienol, gamma
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'deltaTocotrienol', 0),  -- Tocotrienol, delta
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminD', 2.2),  -- Vitamina D (D2 + D3)
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminD3', 2.2),  -- Vitamina D3 (colecalciferol)
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminDIu', 88),  -- Vitamina D
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'vitaminK', 5.6),  -- Vitamina K (filoquinona)
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'dihydrophylloquinone', 0.1),  -- Dihidrofiloquinona
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'saturatedFat', 4.323),  -- Gorduras saturadas
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'butyricAcid', 0.004),  -- Ácido graxo butírico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'caprylicAcid', 0.004),  -- Ácido graxo caprílico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'capricAcid', 0.006),  -- Ácido graxo cáprico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'myristicAcid', 0.047),  -- Ácido graxo mirístico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'palmiticAcid', 2.954),  -- Ácido graxo palmítico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'heptadecanoicAcid', 0.023),  -- Ácido graxo heptadecanóico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'stearicAcid', 1.268),  -- Ácido graxo esteárico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'arachidicAcid', 0.003),  -- Ácido graxo araquídico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'monounsaturatedFat', 6.182),  -- Gorduras monoinsaturadas
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'palmitoleicAcid', 0.228),  -- Ácido graxo palmítico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'oleicAcid', 5.904),  -- Ácido graxo oléico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'gadoleicAcid', 0.029),  -- Ácido graxo gadoléico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'polyunsaturatedFat', 3.251),  -- Gorduras poliinsaturadas
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'linoleicAcid', 2.781),  -- Ácido graxo linoléico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'ala', 0.137),  -- Ácido graxo linolênico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'arachidonicAcid', 0.203),  -- Ácido graxo aracdônico
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'dpa', 0.007),  -- Ácido docosapentaenóico (DPA)
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'dha', 0.063),  -- Ácido decosahexaenóico (DHA)
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'transFat', 0.041),  -- Gorduras trans
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'cholesterol', 401),  -- Colesterol
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'tryptophan', 0.181),  -- Triptofano
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'threonine', 0.602),  -- Treonina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'isoleucine', 0.728),  -- Isoleucina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'leucine', 1.177),  -- Leucina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'lysine', 0.989),  -- Lisina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'methionine', 0.411),  -- Metionina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'cysteine', 0.294),  -- Cisteína
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'phenylalanine', 0.736),  -- Fenilalanina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'tyrosine', 0.541),  -- Tirosina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'valine', 0.93),  -- Valina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'arginine', 0.887),  -- Arginina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'histidine', 0.335),  -- Histidina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'alanine', 0.795),  -- Alanina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'asparticAcid', 1.438),  -- Aspartato
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'glutamicAcid', 1.817),  -- Glutamato
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'glycine', 0.467),  -- Glicina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'proline', 0.558),  -- Prolina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'serine', 1.051),  -- Serina
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'alcohol', 0),  -- Álcool
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'caffeine', 0),  -- Cafeína
  ('15cc7547-662d-55bf-803c-bf16bd4455aa', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
