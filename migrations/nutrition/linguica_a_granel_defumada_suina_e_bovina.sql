-- Linguica a granel defumada, suina e bovina
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
--   Ácido graxo gama linoléico
--   Ácido eicosadienóico, cis, n-6
--   Ácido graxo eicosatrienóico, indiferenciado

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', null, 'Linguica a granel defumada, suina e bovina', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'water', 53.97),  -- Água
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'calories', 320),  -- Valor energético (kcal)
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'kilojoules', 1338),  -- Valor energético (kJ)
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'protein', 12),  -- Proteína
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'fat', 28.73),  -- Gorduras totais
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'ash', 2.89),  -- Cinzas
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'carbohydrates', 2.42),  -- Carboidratos (por diferença)
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'fiber', 0),  -- Fibra alimentar
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'monosaccharides', 0),  -- Monossacarídeos
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'calcium', 12),  -- Cálcio
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'iron', 0.75),  -- Ferro
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'magnesium', 13),  -- Magnésio
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'phosphorus', 121),  -- Fósforo
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'potassium', 179),  -- Potássio
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'sodium', 911),  -- Sódio
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'zinc', 1.26),  -- Zinco
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'copper', 0.077),  -- Cobre
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'manganese', 0.048),  -- Manganês
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'selenium', 0),  -- Selênio
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'vitaminB1', 0.192),  -- Tiamina
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'vitaminB2', 0.106),  -- Riboflavina
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'vitaminB3', 2.94),  -- Niacina
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'vitaminB5', 0.525),  -- Ácido Pantotênico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'vitaminB6', 0.163),  -- Vitamina B6
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'vitaminB9', 2),  -- Ácido fólico, total
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'folicAcid', 0),  -- Ácido fólico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'foodFolate', 2),  -- Folato, alimento
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'folateDfe', 2),  -- Folato, equivalente à medida diária
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'choline', 50.7),  -- Colina, total
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'betaine', 2.1),  -- Betaína
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'vitaminB12', 0.58),  -- Vitamina B12
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'vitaminA', 13),  -- Vitamina A (atividade equivalente de retinol)
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'retinol', 11),  -- Retinol
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'betaCarotene', 11),  -- Betacaroteno
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'alphaCarotene', 11),  -- Alfacaroteno
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'betaCryptoxanthin', 11),  -- Beta-criptoxantina
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'vitaminAIu', 74),  -- Vitamina A (SI)
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'lycopene', 11),  -- Licopeno
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'luteinZeaxanthin', 0),  -- Luteína + zeaxantina
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'vitaminE', 0.13),  -- Vitamina E (alfatocoferol)
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'betaTocopherol', 0),  -- Beta-tocoferol
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'gammaTocopherol', 0.08),  -- Gama-tocoferol
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'deltaTocopherol', 0),  -- Delta-tocoferol
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'alphaTocotrienol', 0),  -- Tocotrienol, alpha
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'betaTocotrienol', 0),  -- Tocotrienol, beta
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'gammaTocotrienol', 0),  -- Tocotrienol, gamma
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'deltaTocotrienol', 0),  -- Tocotrienol, delta
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'vitaminD', 1.1),  -- Vitamina D (D2 + D3)
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'vitaminDIu', 44),  -- Vitamina D
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'vitaminK', 0),  -- Vitamina K (filoquinona)
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'saturatedFat', 9.769),  -- Gorduras saturadas
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'butyricAcid', 0),  -- Ácido graxo butírico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'caproicAcid', 0),  -- Ácido graxo capróico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'caprylicAcid', 0),  -- Ácido graxo caprílico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'capricAcid', 0),  -- Ácido graxo cáprico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'lauricAcid', 0),  -- Ácido graxo láurico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'myristicAcid', 0.399),  -- Ácido graxo mirístico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'palmiticAcid', 6.119),  -- Ácido graxo palmítico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'heptadecanoicAcid', 0.117),  -- Ácido graxo heptadecanóico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'stearicAcid', 3.088),  -- Ácido graxo esteárico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'arachidicAcid', 0.046),  -- Ácido graxo araquídico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'monounsaturatedFat', 12.238),  -- Gorduras monoinsaturadas
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'palmitoleicAcid', 0.744),  -- Ácido graxo palmítico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'oleicAcid', 11.262),  -- Ácido graxo oléico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'gadoleicAcid', 0.232),  -- Ácido graxo gadoléico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'polyunsaturatedFat', 3.927),  -- Gorduras poliinsaturadas
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'linoleicAcid', 3.481),  -- Ácido graxo linoléico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'ala', 0.207),  -- Ácido graxo linolênico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'arachidonicAcid', 0.088),  -- Ácido graxo aracdônico
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'transFat', 0),  -- Gorduras trans
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'cholesterol', 58),  -- Colesterol
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'alcohol', 0),  -- Álcool
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'caffeine', 0),  -- Cafeína
  ('a14f19b7-0c5d-5a1e-b595-4e0912ef301c', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
