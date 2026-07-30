-- Prato rapido, batata, batata frita em oleo vegetal
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
--   Ácido graxo palmitoléico, trans
--   Ácido graxo heptadecenóico
--   Ácido graxo erúcico, cis
--   Ácido graxo erúcico, trans
--   Ácido graxo tetracosenóico, cis
--   Ácido graxo linoléico, trans, não definido totalmente
--   Ácido graxo gama linoléico
--   Ácido eicosadienóico, cis, n-6
--   Ácido graxo eicosatrienóico, indiferenciado
--   Ácido graxo eicosatrienóico, n-3
--   Ácido graxo eicosatrienóico, n-6
--   22:4
--   Fitosterol

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('45816689-2854-5764-a6f3-6ce56d4ca112', null, 'Prato rapido, batata, batata frita em oleo vegetal', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'water', 38.55),  -- Água
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'calories', 312),  -- Valor energético (kcal)
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'kilojoules', 1305),  -- Valor energético (kJ)
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'protein', 3.43),  -- Proteína
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'fat', 14.73),  -- Gorduras totais
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'ash', 1.85),  -- Cinzas
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'carbohydrates', 41.44),  -- Carboidratos (por diferença)
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'fiber', 3.8),  -- Fibra alimentar
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'monosaccharides', 0.3),  -- Monossacarídeos
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'calcium', 18),  -- Cálcio
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'iron', 0.81),  -- Ferro
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'magnesium', 35),  -- Magnésio
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'phosphorus', 125),  -- Fósforo
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'potassium', 579),  -- Potássio
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'sodium', 210),  -- Sódio
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'zinc', 0.5),  -- Zinco
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'copper', 0.124),  -- Cobre
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'manganese', 0.247),  -- Manganês
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'selenium', 0.9),  -- Selênio
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'vitaminC', 4.7),  -- Vitamina C, ácido ascórbico total
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'vitaminB1', 0.17),  -- Tiamina
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'vitaminB2', 0.039),  -- Riboflavina
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'vitaminB3', 3.004),  -- Niacina
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'vitaminB5', 0.58),  -- Ácido Pantotênico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'vitaminB6', 0.372),  -- Vitamina B6
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'vitaminB9', 30),  -- Ácido fólico, total
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'folicAcid', 0),  -- Ácido fólico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'foodFolate', 30),  -- Folato, alimento
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'folateDfe', 30),  -- Folato, equivalente à medida diária
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'choline', 36.8),  -- Colina, total
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'betaine', 0.4),  -- Betaína
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'vitaminB12', 0),  -- Vitamina B12
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'vitaminA', 0),  -- Vitamina A (atividade equivalente de retinol)
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'retinol', 0),  -- Retinol
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'betaCarotene', 0),  -- Betacaroteno
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'alphaCarotene', 0),  -- Alfacaroteno
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'vitaminAIu', 0),  -- Vitamina A (SI)
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'lycopene', 0),  -- Licopeno
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'luteinZeaxanthin', 27),  -- Luteína + zeaxantina
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'vitaminE', 1.67),  -- Vitamina E (alfatocoferol)
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'betaTocopherol', 0.05),  -- Beta-tocoferol
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'gammaTocopherol', 3.63),  -- Gama-tocoferol
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'deltaTocopherol', 0.9),  -- Delta-tocoferol
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'alphaTocotrienol', 0.02),  -- Tocotrienol, alpha
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'betaTocotrienol', 0.09),  -- Tocotrienol, beta
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'gammaTocotrienol', 0.03),  -- Tocotrienol, gamma
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'deltaTocotrienol', 0.03),  -- Tocotrienol, delta
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'vitaminDIu', 0),  -- Vitamina D
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'vitaminK', 11.2),  -- Vitamina K (filoquinona)
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'dihydrophylloquinone', 42.8),  -- Dihidrofiloquinona
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'saturatedFat', 2.336),  -- Gorduras saturadas
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'butyricAcid', 0.08),  -- Ácido graxo butírico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'caprylicAcid', 0.014),  -- Ácido graxo caprílico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'capricAcid', 0.013),  -- Ácido graxo cáprico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'lauricAcid', 0.004),  -- Ácido graxo láurico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'myristicAcid', 0.018),  -- Ácido graxo mirístico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'palmiticAcid', 1.22),  -- Ácido graxo palmítico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'heptadecanoicAcid', 0.011),  -- Ácido graxo heptadecanóico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'stearicAcid', 0.838),  -- Ácido graxo esteárico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'arachidicAcid', 0.07),  -- Ácido graxo araquídico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'monounsaturatedFat', 5.969),  -- Gorduras monoinsaturadas
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'palmitoleicAcid', 0.026),  -- Ácido graxo palmítico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'palmitoleicAcidCis', 0.026),  -- Ácido graxo palmítico, cis
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'oleicAcid', 5.821),  -- Ácido graxo oléico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'oleicAcidCis', 5.796),  -- Ácido graxo oléico, cis
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'oleicAcidTrans', 0.026),  -- Ácido graxo oléico, trans
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'gadoleicAcid', 0.107),  -- Ácido graxo gadoléico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'erucicAcid', 0.004),  -- Ácido graxo erúcico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'polyunsaturatedFat', 5.398),  -- Gorduras poliinsaturadas
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'linoleicAcid', 4.948),  -- Ácido graxo linoléico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'linoleicAcidCis', 4.898),  -- Ácido graxo linoléico, cis, n-6
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'conjugatedLinoleicAcid', 0.017),  -- Ácido graxo linoléico, conjugado
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'ala', 0.436),  -- Ácido graxo linolênico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'arachidonicAcid', 0.004),  -- Ácido graxo aracdônico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'transFat', 0.06),  -- Gorduras trans
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'transMonoenoicFat', 0.027),  -- Gorduras trans, monoenóico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'transPolyenoicFat', 0.033),  -- Gorduras trans, polienóico
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'cholesterol', 0),  -- Colesterol
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'alcohol', 0),  -- Álcool
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'caffeine', 0),  -- Cafeína
  ('45816689-2854-5764-a6f3-6ce56d4ca112', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
