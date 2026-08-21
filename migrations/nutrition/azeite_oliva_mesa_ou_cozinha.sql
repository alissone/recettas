-- Azeite, oliva, mesa ou cozinha
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.
--
-- Nutrientes do relatorio sem correspondencia no catalogo,
-- portanto NAO importados:
--   Ácido graxo be-hênico
--   Ácido graxo lignocérico
--   Ácido graxo heptadecenóico
--   Fitosterol

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', null, 'Azeite, oliva, mesa ou cozinha', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'water', 0),  -- Água
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'calories', 884),  -- Valor energético (kcal)
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'kilojoules', 3699),  -- Valor energético (kJ)
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'protein', 0),  -- Proteína
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'fat', 100),  -- Gorduras totais
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'ash', 0),  -- Cinzas
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'carbohydrates', 0),  -- Carboidratos (por diferença)
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'fiber', 0),  -- Fibra alimentar
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'monosaccharides', 0),  -- Monossacarídeos
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'calcium', 1),  -- Cálcio
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'iron', 0.56),  -- Ferro
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'magnesium', 0),  -- Magnésio
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'phosphorus', 0),  -- Fósforo
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'potassium', 1),  -- Potássio
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'sodium', 2),  -- Sódio
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'zinc', 0),  -- Zinco
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'copper', 0),  -- Cobre
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'manganese', 0),  -- Manganês
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'selenium', 0),  -- Selênio
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'vitaminB1', 0),  -- Tiamina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'vitaminB2', 0),  -- Riboflavina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'vitaminB3', 0),  -- Niacina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'vitaminB5', 0),  -- Ácido Pantotênico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'vitaminB6', 0),  -- Vitamina B6
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'vitaminB9', 0),  -- Ácido fólico, total
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'folicAcid', 0),  -- Ácido fólico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'foodFolate', 0),  -- Folato, alimento
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'folateDfe', 0),  -- Folato, equivalente à medida diária
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'choline', 0.3),  -- Colina, total
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'betaine', 0.1),  -- Betaína
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'vitaminB12', 0),  -- Vitamina B12
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'vitaminA', 0),  -- Vitamina A (atividade equivalente de retinol)
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'retinol', 0),  -- Retinol
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'betaCarotene', 0),  -- Betacaroteno
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'alphaCarotene', 0),  -- Alfacaroteno
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'vitaminAIu', 0),  -- Vitamina A (SI)
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'lycopene', 0),  -- Licopeno
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'luteinZeaxanthin', 0),  -- Luteína + zeaxantina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'vitaminE', 14.35),  -- Vitamina E (alfatocoferol)
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'betaTocopherol', 0.11),  -- Beta-tocoferol
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'gammaTocopherol', 0.83),  -- Gama-tocoferol
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'deltaTocopherol', 0),  -- Delta-tocoferol
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'vitaminDIu', 0),  -- Vitamina D
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'vitaminK', 60.2),  -- Vitamina K (filoquinona)
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'dihydrophylloquinone', 0),  -- Dihidrofiloquinona
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'saturatedFat', 13.808),  -- Gorduras saturadas
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'myristicAcid', 0),  -- Ácido graxo mirístico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'palmiticAcid', 11.29),  -- Ácido graxo palmítico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'heptadecanoicAcid', 0.022),  -- Ácido graxo heptadecanóico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'stearicAcid', 1.953),  -- Ácido graxo esteárico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'arachidicAcid', 0.414),  -- Ácido graxo araquídico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'monounsaturatedFat', 72.961),  -- Gorduras monoinsaturadas
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'palmitoleicAcid', 1.255),  -- Ácido graxo palmítico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'oleicAcid', 71.269),  -- Ácido graxo oléico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'gadoleicAcid', 0.311),  -- Ácido graxo gadoléico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'polyunsaturatedFat', 10.523),  -- Gorduras poliinsaturadas
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'linoleicAcid', 9.762),  -- Ácido graxo linoléico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'ala', 0.761),  -- Ácido graxo linolênico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'cholesterol', 0),  -- Colesterol
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'tryptophan', 0),  -- Triptofano
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'threonine', 0),  -- Treonina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'isoleucine', 0),  -- Isoleucina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'leucine', 0),  -- Leucina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'lysine', 0),  -- Lisina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'methionine', 0),  -- Metionina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'cysteine', 0),  -- Cisteína
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'phenylalanine', 0),  -- Fenilalanina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'tyrosine', 0),  -- Tirosina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'valine', 0),  -- Valina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'arginine', 0),  -- Arginina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'histidine', 0),  -- Histidina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'alanine', 0),  -- Alanina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'asparticAcid', 0),  -- Aspartato
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'glutamicAcid', 0),  -- Glutamato
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'glycine', 0),  -- Glicina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'proline', 0),  -- Prolina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'serine', 0),  -- Serina
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'alcohol', 0),  -- Álcool
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'caffeine', 0),  -- Cafeína
  ('b71a9f2b-1d87-5b2c-b9db-5c79aa728fc0', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
