-- Suco Uva Del Valle Caixa 1l
-- Marca: del Valle
-- Codigo: 1072614
-- Fonte: https://www.extramercado.com.br/produto/343416/suco-uva-del-valle-caixa-1l
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 200 ml. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.
--
-- Nutrientes da embalagem sem correspondencia no catalogo,
-- portanto NAO importados:
--   Açúcares

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('b0d7a0eb-d63c-5ddb-9c40-89ae5d187afa', null, 'Suco Uva Del Valle Caixa 1l', 'del Valle', 200, 'ml')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('b0d7a0eb-d63c-5ddb-9c40-89ae5d187afa', 'addedSugar', 0),  -- Açúcares Adicionados
  ('b0d7a0eb-d63c-5ddb-9c40-89ae5d187afa', 'sugar', 14),  -- Açúcares Totais
  ('b0d7a0eb-d63c-5ddb-9c40-89ae5d187afa', 'carbohydrates', 14),  -- Carboidratos
  ('b0d7a0eb-d63c-5ddb-9c40-89ae5d187afa', 'fiber', 2.5),  -- Fibra Alimentar
  ('b0d7a0eb-d63c-5ddb-9c40-89ae5d187afa', 'saturatedFat', 0),  -- Gorduras Saturadas
  ('b0d7a0eb-d63c-5ddb-9c40-89ae5d187afa', 'fat', 0),  -- Gorduras Totais
  ('b0d7a0eb-d63c-5ddb-9c40-89ae5d187afa', 'sodium', 3.1),  -- Sódio
  ('b0d7a0eb-d63c-5ddb-9c40-89ae5d187afa', 'calories', 58),  -- Valor energético
  ('b0d7a0eb-d63c-5ddb-9c40-89ae5d187afa', 'vitaminC', 6.7)  -- Vitamina C
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
