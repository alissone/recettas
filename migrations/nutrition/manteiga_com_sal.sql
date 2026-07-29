-- Manteiga, com sal
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', null, 'Manteiga, com sal', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'water', 15.87),  -- Água
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'calories', 717),  -- Valor energético (kcal)
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'kilojoules', 3000),  -- Valor energético (kJ)
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'protein', 0.85),  -- Proteína
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'fat', 81.11),  -- Gorduras totais
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'ash', 2.11),  -- Cinzas
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'carbohydrates', 0.06),  -- Carboidratos (por diferença)
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'fiber', 0),  -- Fibra alimentar
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'monosaccharides', 0.06),  -- Monossacarídeos
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'calcium', 24),  -- Cálcio
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'iron', 0.02),  -- Ferro
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'magnesium', 2),  -- Magnésio
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'phosphorus', 24),  -- Fósforo
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'potassium', 24),  -- Potássio
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'sodium', 643),  -- Sódio
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'zinc', 0.09),  -- Zinco
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'copper', 0),  -- Cobre
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'manganese', 0),  -- Manganês
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'selenium', 1),  -- Selênio
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'fluoride', 2.8),  -- Flúor
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminB1', 0.005),  -- Tiamina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminB2', 0.034),  -- Riboflavina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminB3', 0.042),  -- Niacina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminB5', 0.11),  -- Ácido Pantotênico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminB6', 0.003),  -- Vitamina B6
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminB9', 3),  -- Ácido fólico, total
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'folicAcid', 0),  -- Ácido fólico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'foodFolate', 3),  -- Folato, alimento
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'folateDfe', 3),  -- Folato, equivalente à medida diária
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'choline', 18.8),  -- Colina, total
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'betaine', 0.3),  -- Betaína
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminB12', 0.17),  -- Vitamina B12
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminA', 684),  -- Vitamina A (atividade equivalente de retinol)
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'retinol', 671),  -- Retinol
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'betaCarotene', 158),  -- Betacaroteno
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'alphaCarotene', 0),  -- Alfacaroteno
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminAIu', 2499),  -- Vitamina A (SI)
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'lycopene', 0),  -- Licopeno
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'luteinZeaxanthin', 0),  -- Luteína + zeaxantina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminE', 2.32),  -- Vitamina E (alfatocoferol)
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'betaTocopherol', 0),  -- Beta-tocoferol
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'gammaTocopherol', 0),  -- Gama-tocoferol
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'deltaTocopherol', 0),  -- Delta-tocoferol
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'alphaTocotrienol', 0),  -- Tocotrienol, alpha
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'betaTocotrienol', 0),  -- Tocotrienol, beta
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'gammaTocotrienol', 0),  -- Tocotrienol, gamma
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'deltaTocotrienol', 0),  -- Tocotrienol, delta
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminD', 1.5),  -- Vitamina D (D2 + D3)
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminD3', 1.5),  -- Vitamina D3 (colecalciferol)
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminDIu', 60),  -- Vitamina D
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'vitaminK', 7),  -- Vitamina K (filoquinona)
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'saturatedFat', 51.368),  -- Gorduras saturadas
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'butyricAcid', 3.226),  -- Ácido graxo butírico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'caproicAcid', 2.007),  -- Ácido graxo capróico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'caprylicAcid', 1.19),  -- Ácido graxo caprílico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'capricAcid', 2.529),  -- Ácido graxo cáprico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'lauricAcid', 2.587),  -- Ácido graxo láurico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'myristicAcid', 7.436),  -- Ácido graxo mirístico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'palmiticAcid', 21.697),  -- Ácido graxo palmítico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'heptadecanoicAcid', 0.56),  -- Ácido graxo heptadecanóico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'stearicAcid', 9.999),  -- Ácido graxo esteárico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'arachidicAcid', 0.138),  -- Ácido graxo araquídico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'monounsaturatedFat', 21.021),  -- Gorduras monoinsaturadas
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'palmitoleicAcid', 0.961),  -- Ácido graxo palmítico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'palmitoleicAcidCis', 0.961),  -- Ácido graxo palmítico, cis
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'oleicAcid', 19.961),  -- Ácido graxo oléico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'oleicAcidCis', 16.978),  -- Ácido graxo oléico, cis
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'oleicAcidTrans', 2.982),  -- Ácido graxo oléico, trans
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'gadoleicAcid', 0.1),  -- Ácido graxo gadoléico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'polyunsaturatedFat', 3.043),  -- Gorduras poliinsaturadas
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'linoleicAcid', 2.728),  -- Ácido graxo linoléico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'linoleicAcidCis', 2.166),  -- Ácido graxo linoléico, cis, n-6
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'conjugatedLinoleicAcid', 0.267),  -- Ácido graxo linoléico, conjugado
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'linoleicAcidIsomers', 0.296),  -- Ácido graxo linoléico, isômeros juntos
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'ala', 0.315),  -- Ácido graxo linolênico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'transFat', 3.278),  -- Gorduras trans
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'transMonoenoicFat', 2.982),  -- Gorduras trans, monoenóico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'transPolyenoicFat', 0.296),  -- Gorduras trans, polienóico
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'cholesterol', 215),  -- Colesterol
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'stigmasterol', 0),  -- Estigmasterol
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'campesterol', 0),  -- Campesterol
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'betaSitosterol', 4),  -- Beta-sisterol
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'tryptophan', 0.012),  -- Triptofano
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'threonine', 0.038),  -- Treonina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'isoleucine', 0.051),  -- Isoleucina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'leucine', 0.083),  -- Leucina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'lysine', 0.067),  -- Lisina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'methionine', 0.021),  -- Metionina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'cysteine', 0.008),  -- Cisteína
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'phenylalanine', 0.041),  -- Fenilalanina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'tyrosine', 0.041),  -- Tirosina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'valine', 0.057),  -- Valina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'arginine', 0.031),  -- Arginina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'histidine', 0.023),  -- Histidina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'alanine', 0.029),  -- Alanina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'asparticAcid', 0.064),  -- Aspartato
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'glutamicAcid', 0.178),  -- Glutamato
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'glycine', 0.018),  -- Glicina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'proline', 0.082),  -- Prolina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'serine', 0.046),  -- Serina
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'alcohol', 0),  -- Álcool
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'caffeine', 0),  -- Cafeína
  ('ea8ce03e-c9b8-5ded-b77e-a949e36efb56', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
