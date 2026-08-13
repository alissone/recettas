-- Requeijão Cremoso Tradicional Vigor Copo 200g
-- Marca: Vigor
-- Codigo: 3244463
-- Fonte: https://www.extramercado.com.br/produto/69603/requeijao-cremoso-tradicional-vigor-copo-200g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 30 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('485814be-3dbc-50b4-b025-7746b716eafc', null, 'Requeijão Cremoso Tradicional Vigor Copo 200g', 'Vigor', 30, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('485814be-3dbc-50b4-b025-7746b716eafc', 'addedSugar', 0),  -- Açúcares Adicionados
  ('485814be-3dbc-50b4-b025-7746b716eafc', 'sugar', 3.3),  -- Açúcares Totais
  ('485814be-3dbc-50b4-b025-7746b716eafc', 'carbohydrates', 3.3),  -- Carboidratos
  ('485814be-3dbc-50b4-b025-7746b716eafc', 'fiber', 0),  -- Fibra Alimentar
  ('485814be-3dbc-50b4-b025-7746b716eafc', 'saturatedFat', 16),  -- Gorduras Saturadas
  ('485814be-3dbc-50b4-b025-7746b716eafc', 'fat', 24),  -- Gorduras Totais
  ('485814be-3dbc-50b4-b025-7746b716eafc', 'transFat', 0.6),  -- Gorduras Trans
  ('485814be-3dbc-50b4-b025-7746b716eafc', 'protein', 7.5),  -- Proteínas
  ('485814be-3dbc-50b4-b025-7746b716eafc', 'sodium', 491),  -- Sódio
  ('485814be-3dbc-50b4-b025-7746b716eafc', 'calories', 259)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
