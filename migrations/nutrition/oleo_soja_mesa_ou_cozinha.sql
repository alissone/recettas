-- Oleo, soja, mesa ou cozinha
-- Fonte: Tabela de Composicao Quimica dos Alimentos (SR25), UNIFESP.
-- Gerado por scripts/nutrition_report_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.
--
-- Nutrientes do relatorio sem correspondencia no catalogo,
-- portanto NAO importados:
--   Menaquinona
--   Ácido graxo pentadecanóico
--   Ácido graxo be-hênico
--   Ácido graxo pentadecenóico
--   Ácido graxo heptadecenóico
--   Ácido graxo linoléico, trans
--   Ácido graxo gama linoléico
--   Ácido eicosadienóico, cis, n-6
--   Ácido graxo eicosatrienóico, indiferenciado

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('64a1264d-7b18-51de-8455-426c9b98cee8', null, 'Oleo, soja, mesa ou cozinha', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'water', 0),  -- Água
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'calories', 884),  -- Valor energético (kcal)
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'kilojoules', 3699),  -- Valor energético (kJ)
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'protein', 0),  -- Proteína
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'fat', 100),  -- Gorduras totais
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'ash', 0),  -- Cinzas
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'carbohydrates', 0),  -- Carboidratos (por diferença)
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'fiber', 0),  -- Fibra alimentar
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'monosaccharides', 0),  -- Monossacarídeos
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'calcium', 0),  -- Cálcio
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'iron', 0.05),  -- Ferro
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'magnesium', 0),  -- Magnésio
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'phosphorus', 0),  -- Fósforo
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'potassium', 0),  -- Potássio
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'sodium', 0),  -- Sódio
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'zinc', 0.01),  -- Zinco
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'copper', 0),  -- Cobre
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'manganese', 0),  -- Manganês
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'selenium', 0),  -- Selênio
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'vitaminB1', 0),  -- Tiamina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'vitaminB2', 0),  -- Riboflavina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'vitaminB3', 0),  -- Niacina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'vitaminB5', 0),  -- Ácido Pantotênico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'vitaminB6', 0),  -- Vitamina B6
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'vitaminB9', 0),  -- Ácido fólico, total
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'folicAcid', 0),  -- Ácido fólico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'foodFolate', 0),  -- Folato, alimento
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'folateDfe', 0),  -- Folato, equivalente à medida diária
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'choline', 0.2),  -- Colina, total
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'betaine', 0),  -- Betaína
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'vitaminB12', 0),  -- Vitamina B12
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'vitaminA', 0),  -- Vitamina A (atividade equivalente de retinol)
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'retinol', 0),  -- Retinol
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'betaCarotene', 0),  -- Betacaroteno
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'alphaCarotene', 0),  -- Alfacaroteno
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'vitaminAIu', 0),  -- Vitamina A (SI)
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'lycopene', 0),  -- Licopeno
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'luteinZeaxanthin', 0),  -- Luteína + zeaxantina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'vitaminE', 8.18),  -- Vitamina E (alfatocoferol)
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'betaTocopherol', 0.9),  -- Beta-tocoferol
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'gammaTocopherol', 64.26),  -- Gama-tocoferol
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'deltaTocopherol', 21.3),  -- Delta-tocoferol
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'alphaTocotrienol', 0.04),  -- Tocotrienol, alpha
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'betaTocotrienol', 0.03),  -- Tocotrienol, beta
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'gammaTocotrienol', 0),  -- Tocotrienol, gamma
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'deltaTocotrienol', 0.01),  -- Tocotrienol, delta
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'vitaminD', 0),  -- Vitamina D (D2 + D3)
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'vitaminDIu', 0),  -- Vitamina D
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'vitaminK', 183.9),  -- Vitamina K (filoquinona)
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'dihydrophylloquinone', 0),  -- Dihidrofiloquinona
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'saturatedFat', 15.65),  -- Gorduras saturadas
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'myristicAcid', 0),  -- Ácido graxo mirístico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'palmiticAcid', 10.455),  -- Ácido graxo palmítico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'heptadecanoicAcid', 0.034),  -- Ácido graxo heptadecanóico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'stearicAcid', 4.435),  -- Ácido graxo esteárico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'arachidicAcid', 0.361),  -- Ácido graxo araquídico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'monounsaturatedFat', 22.783),  -- Gorduras monoinsaturadas
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'palmitoleicAcid', 0),  -- Ácido graxo palmítico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'oleicAcid', 22.55),  -- Ácido graxo oléico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'oleicAcidCis', 22.55),  -- Ácido graxo oléico, cis
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'oleicAcidTrans', 0),  -- Ácido graxo oléico, trans
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'gadoleicAcid', 0.233),  -- Ácido graxo gadoléico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'polyunsaturatedFat', 57.74),  -- Gorduras poliinsaturadas
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'linoleicAcid', 50.952),  -- Ácido graxo linoléico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'linoleicAcidCis', 50.418),  -- Ácido graxo linoléico, cis, n-6
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'ala', 6.789),  -- Ácido graxo linolênico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'transFat', 0.533),  -- Gorduras trans
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'transMonoenoicFat', 0),  -- Gorduras trans, monoenóico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'transPolyenoicFat', 0.533),  -- Gorduras trans, polienóico
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'cholesterol', 0),  -- Colesterol
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'stigmasterol', 59),  -- Estigmasterol
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'campesterol', 62),  -- Campesterol
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'betaSitosterol', 172),  -- Beta-sisterol
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'tryptophan', 0),  -- Triptofano
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'threonine', 0),  -- Treonina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'isoleucine', 0),  -- Isoleucina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'leucine', 0),  -- Leucina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'lysine', 0),  -- Lisina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'methionine', 0),  -- Metionina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'cysteine', 0),  -- Cisteína
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'phenylalanine', 0),  -- Fenilalanina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'tyrosine', 0),  -- Tirosina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'valine', 0),  -- Valina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'arginine', 0),  -- Arginina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'histidine', 0),  -- Histidina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'alanine', 0),  -- Alanina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'asparticAcid', 0),  -- Aspartato
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'glutamicAcid', 0),  -- Glutamato
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'glycine', 0),  -- Glicina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'proline', 0),  -- Prolina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'serine', 0),  -- Serina
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'alcohol', 0),  -- Álcool
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'caffeine', 0),  -- Cafeína
  ('64a1264d-7b18-51de-8455-426c9b98cee8', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
