-- Leite, integral, 3,25% de gordura, sem adicao de vitamina A ou D
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
--   Ácido graxo tridecanóico
--   Ácido graxo pentadecanóico
--   Ácido graxo be-hênico
--   Ácido graxo lignocérico

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('198050d5-ea06-5a93-88d4-6d2cb1204faa', null, 'Leite, integral, 3,25% de gordura, sem adicao de vitamina A ou D', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'water', 88.13),  -- Água
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'calories', 61),  -- Valor energético (kcal)
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'kilojoules', 256),  -- Valor energético (kJ)
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'protein', 3.15),  -- Proteína
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'fat', 3.27),  -- Gorduras totais
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'ash', 0.67),  -- Cinzas
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'carbohydrates', 4.78),  -- Carboidratos (por diferença)
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'fiber', 0),  -- Fibra alimentar
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'monosaccharides', 5.05),  -- Monossacarídeos
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'sucrose', 0),  -- Sacarose
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'glucose', 0),  -- Glicose
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'fructose', 0),  -- Frutose
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'lactose', 5.05),  -- Lactose
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'maltose', 0),  -- Maltose
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'galactose', 0),  -- Galactose
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'calcium', 113),  -- Cálcio
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'iron', 0.03),  -- Ferro
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'magnesium', 10),  -- Magnésio
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'phosphorus', 84),  -- Fósforo
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'potassium', 132),  -- Potássio
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'sodium', 43),  -- Sódio
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'zinc', 0.37),  -- Zinco
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'copper', 0.025),  -- Cobre
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'manganese', 0.004),  -- Manganês
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'selenium', 3.7),  -- Selênio
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminC', 0),  -- Vitamina C, ácido ascórbico total
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminB1', 0.046),  -- Tiamina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminB2', 0.169),  -- Riboflavina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminB3', 0.089),  -- Niacina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminB5', 0.373),  -- Ácido Pantotênico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminB6', 0.036),  -- Vitamina B6
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminB9', 5),  -- Ácido fólico, total
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'folicAcid', 0),  -- Ácido fólico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'foodFolate', 5),  -- Folato, alimento
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'folateDfe', 5),  -- Folato, equivalente à medida diária
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'choline', 14.3),  -- Colina, total
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'betaine', 0.6),  -- Betaína
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminB12', 0.45),  -- Vitamina B12
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'addedVitaminB12', 0),  -- Vitamina B-12, adicionada
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminA', 46),  -- Vitamina A (atividade equivalente de retinol)
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'retinol', 45),  -- Retinol
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'betaCarotene', 7),  -- Betacaroteno
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'alphaCarotene', 0),  -- Alfacaroteno
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'betaCryptoxanthin', 0),  -- Beta-criptoxantina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminAIu', 162),  -- Vitamina A (SI)
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'lycopene', 0),  -- Licopeno
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'luteinZeaxanthin', 0),  -- Luteína + zeaxantina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminE', 0.07),  -- Vitamina E (alfatocoferol)
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'addedVitaminE', 0),  -- Vitamina E, adicionada
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'betaTocopherol', 0),  -- Beta-tocoferol
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'gammaTocopherol', 0),  -- Gama-tocoferol
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'deltaTocopherol', 0),  -- Delta-tocoferol
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'alphaTocotrienol', 0),  -- Tocotrienol, alpha
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'betaTocotrienol', 0),  -- Tocotrienol, beta
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'gammaTocotrienol', 0),  -- Tocotrienol, gamma
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'deltaTocotrienol', 0),  -- Tocotrienol, delta
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminD', 0.1),  -- Vitamina D (D2 + D3)
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminD3', 0.1),  -- Vitamina D3 (colecalciferol)
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminDIu', 2),  -- Vitamina D
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'vitaminK', 0.3),  -- Vitamina K (filoquinona)
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'dihydrophylloquinone', 0),  -- Dihidrofiloquinona
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'saturatedFat', 1.865),  -- Gorduras saturadas
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'butyricAcid', 0.075),  -- Ácido graxo butírico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'caproicAcid', 0.075),  -- Ácido graxo capróico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'caprylicAcid', 0.075),  -- Ácido graxo caprílico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'capricAcid', 0.075),  -- Ácido graxo cáprico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'lauricAcid', 0.077),  -- Ácido graxo láurico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'myristicAcid', 0.297),  -- Ácido graxo mirístico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'palmiticAcid', 0.829),  -- Ácido graxo palmítico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'heptadecanoicAcid', 0),  -- Ácido graxo heptadecanóico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'stearicAcid', 0.365),  -- Ácido graxo esteárico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'arachidicAcid', 0),  -- Ácido graxo araquídico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'monounsaturatedFat', 0.812),  -- Gorduras monoinsaturadas
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'palmitoleicAcid', 0),  -- Ácido graxo palmítico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'oleicAcid', 0.812),  -- Ácido graxo oléico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'gadoleicAcid', 0),  -- Ácido graxo gadoléico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'erucicAcid', 0),  -- Ácido graxo erúcico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'polyunsaturatedFat', 0.195),  -- Gorduras poliinsaturadas
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'linoleicAcid', 0.12),  -- Ácido graxo linoléico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'ala', 0.075),  -- Ácido graxo linolênico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'parinaricAcid', 0),  -- Ácido graxo parinárico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'arachidonicAcid', 0),  -- Ácido graxo aracdônico
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'epa', 0),  -- Ácido eicosapentaenoico (EPA)
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'dpa', 0),  -- Ácido docosapentaenóico (DPA)
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'dha', 0),  -- Ácido decosahexaenóico (DHA)
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'cholesterol', 10),  -- Colesterol
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'tryptophan', 0.04),  -- Triptofano
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'threonine', 0.134),  -- Treonina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'isoleucine', 0.163),  -- Isoleucina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'leucine', 0.299),  -- Leucina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'lysine', 0.264),  -- Lisina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'methionine', 0.083),  -- Metionina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'cysteine', 0.019),  -- Cisteína
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'phenylalanine', 0.163),  -- Fenilalanina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'tyrosine', 0.159),  -- Tirosina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'valine', 0.206),  -- Valina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'arginine', 0.09),  -- Arginina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'histidine', 0.095),  -- Histidina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'alanine', 0.107),  -- Alanina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'asparticAcid', 0.27),  -- Aspartato
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'glutamicAcid', 0.708),  -- Glutamato
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'glycine', 0.062),  -- Glicina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'proline', 0.311),  -- Prolina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'serine', 0.19),  -- Serina
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'alcohol', 0),  -- Álcool
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'caffeine', 0),  -- Cafeína
  ('198050d5-ea06-5a93-88d4-6d2cb1204faa', 'theobromine', 0)  -- Teobromina
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
