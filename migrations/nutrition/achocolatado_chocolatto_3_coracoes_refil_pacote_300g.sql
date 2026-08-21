-- Achocolatado Chocolatto 3 Corações Refil Pacote 300g
-- Marca: 3 Corações
-- Codigo: 1609028
-- Fonte: https://www.extramercado.com.br/produto/355953/achocolatado-chocolatto-3-coracoes-refil-pacote-300g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 20 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.
--
-- Nutrientes da embalagem sem correspondencia no catalogo,
-- portanto NAO importados:
--   Açúcares
--   Vitamina D3

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('581bdf17-84fe-5e90-9906-53a81dbc372d', null, 'Achocolatado Chocolatto 3 Corações Refil Pacote 300g', '3 Corações', 20, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'addedSugar', 15),  -- Açúcares Adicionados
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'sugar', 15),  -- Açúcares Totais
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'vitaminB7', 4.5),  -- Biotina
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'calcium', 4),  -- Cálcio
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'carbohydrates', 18),  -- Carboidratos
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'iron', 2.1),  -- Ferro
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'fiber', 0.7),  -- Fibra Alimentar
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'saturatedFat', 0.2),  -- Gorduras Saturadas
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'fat', 0.3),  -- Gorduras Totais
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'transFat', 0),  -- Gorduras Trans
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'protein', 0.5),  -- Proteínas
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'sodium', 11),  -- Sódio
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'calories', 77),  -- Valor energético
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'vitaminB1', 0.18),  -- Vitamina B1
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'vitaminB12', 0.36),  -- Vitamina B12
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'vitaminB2', 0.18),  -- Vitamina B2
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'vitaminB5', 0.75),  -- Vitamina B5
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'vitaminB6', 0.2),  -- Vitamina B6
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'vitaminB9', 36),  -- Vitamina B9
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'vitaminD', 2.3),  -- Vitamina D
  ('581bdf17-84fe-5e90-9906-53a81dbc372d', 'zinc', 1.7)  -- Zinco
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
