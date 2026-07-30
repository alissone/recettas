-- Batata frita, congelada, preparo caseiro, no forno, sem sal
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
--   Ácido graxo pentadecenóico
--   Ácido graxo heptadecenóico
--   Ácido graxo gama linoléico
--   Ácido eicosadienóico, cis, n-6
--   Ácido graxo eicosatrienóico, indiferenciado

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('542817d5-3753-5ad5-86d2-c9134727f693', null, 'Batata frita, congelada, preparo caseiro, no forno, sem sal', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'water', 62.48),  -- Água
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'calories', 164),  -- Valor energético (kcal)
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'kilojoules', 688),  -- Valor energético (kJ)
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'protein', 2.66),  -- Proteína
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'fat', 5.22),  -- Gorduras totais
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'ash', 1.9),  -- Cinzas
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'carbohydrates', 27.74),  -- Carboidratos (por diferença)
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'fiber', 2.8),  -- Fibra alimentar
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'monosaccharides', 0.28),  -- Monossacarídeos
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'sucrose', 0.18),  -- Sacarose
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'glucose', 0.11),  -- Glicose
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'fructose', 0),  -- Frutose
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'lactose', 0),  -- Lactose
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'maltose', 0),  -- Maltose
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'galactose', 0),  -- Galactose
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'starch', 20.13),  -- Amido
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'calcium', 12),  -- Cálcio
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'iron', 0.74),  -- Ferro
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'magnesium', 26),  -- Magnésio
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'phosphorus', 97),  -- Fósforo
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'potassium', 451),  -- Potássio
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'sodium', 388),  -- Sódio
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'zinc', 0.38),  -- Zinco
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'copper', 0.135),  -- Cobre
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'manganese', 0.21),  -- Manganês
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'selenium', 0.2),  -- Selênio
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'fluoride', 25.6),  -- Flúor
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'vitaminC', 13.3),  -- Vitamina C, ácido ascórbico total
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'vitaminB1', 0.128),  -- Tiamina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'vitaminB2', 0.031),  -- Riboflavina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'vitaminB3', 2.218),  -- Niacina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'vitaminB5', 0.522),  -- Ácido Pantotênico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'vitaminB6', 0.184),  -- Vitamina B6
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'vitaminB9', 28),  -- Ácido fólico, total
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'folicAcid', 0),  -- Ácido fólico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'foodFolate', 28),  -- Folato, alimento
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'folateDfe', 28),  -- Folato, equivalente à medida diária
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'choline', 23.7),  -- Colina, total
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'betaine', 0.7),  -- Betaína
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'vitaminB12', 0),  -- Vitamina B12
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'vitaminA', 0),  -- Vitamina A (atividade equivalente de retinol)
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'retinol', 0),  -- Retinol
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'betaCarotene', 3),  -- Betacaroteno
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'alphaCarotene', 0),  -- Alfacaroteno
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'vitaminAIu', 5),  -- Vitamina A (SI)
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'lycopene', 0),  -- Licopeno
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'luteinZeaxanthin', 16),  -- Luteína + zeaxantina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'vitaminE', 0.11),  -- Vitamina E (alfatocoferol)
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'betaTocopherol', 0),  -- Beta-tocoferol
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'gammaTocopherol', 0.36),  -- Gama-tocoferol
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'deltaTocopherol', 0.49),  -- Delta-tocoferol
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'alphaTocotrienol', 0.02),  -- Tocotrienol, alpha
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'betaTocotrienol', 0),  -- Tocotrienol, beta
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'gammaTocotrienol', 0),  -- Tocotrienol, gamma
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'deltaTocotrienol', 0),  -- Tocotrienol, delta
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'vitaminDIu', 0),  -- Vitamina D
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'vitaminK', 2.5),  -- Vitamina K (filoquinona)
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'dihydrophylloquinone', 15.1),  -- Dihidrofiloquinona
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'saturatedFat', 1.029),  -- Gorduras saturadas
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'myristicAcid', 0),  -- Ácido graxo mirístico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'palmiticAcid', 0.548),  -- Ácido graxo palmítico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'heptadecanoicAcid', 0.001),  -- Ácido graxo heptadecanóico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'stearicAcid', 0.445),  -- Ácido graxo esteárico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'arachidicAcid', 0.018),  -- Ácido graxo araquídico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'monounsaturatedFat', 3.237),  -- Gorduras monoinsaturadas
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'palmitoleicAcid', 0.005),  -- Ácido graxo palmítico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'oleicAcid', 3.224),  -- Ácido graxo oléico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'gadoleicAcid', 0.008),  -- Ácido graxo gadoléico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'polyunsaturatedFat', 0.321),  -- Gorduras poliinsaturadas
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'linoleicAcid', 0.279),  -- Ácido graxo linoléico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'ala', 0.021),  -- Ácido graxo linolênico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'cholesterol', 0),  -- Colesterol
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'tryptophan', 0.024),  -- Triptofano
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'threonine', 0.092),  -- Treonina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'isoleucine', 0.093),  -- Isoleucina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'leucine', 0.156),  -- Leucina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'lysine', 0.156),  -- Lisina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'methionine', 0.042),  -- Metionina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'cysteine', 0.042),  -- Cisteína
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'phenylalanine', 0.113),  -- Fenilalanina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'tyrosine', 0.091),  -- Tirosina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'valine', 0.147),  -- Valina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'arginine', 0.153),  -- Arginina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'histidine', 0.054),  -- Histidina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'alanine', 0.108),  -- Alanina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'asparticAcid', 0.589),  -- Aspartato
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'glutamicAcid', 0.474),  -- Glutamato
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'glycine', 0.087),  -- Glicina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'proline', 0.098),  -- Prolina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'serine', 0.116),  -- Serina
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'alcohol', 0),  -- Álcool
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'caffeine', 0),  -- Cafeína
  ('542817d5-3753-5ad5-86d2-c9134727f693', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
