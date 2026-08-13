-- Farofa de Mandioca Tradicional Yoki Pacote 400g
-- Marca: Yoki
-- Codigo: 1366900
-- Fonte: https://www.extramercado.com.br/produto/1605902/farofa-de-mandioca-tradicional-yoki-pacote-400g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 35 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('2b7fdea7-7ece-5f09-83e6-5f07d9473887', null, 'Farofa de Mandioca Tradicional Yoki Pacote 400g', 'Yoki', 35, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('2b7fdea7-7ece-5f09-83e6-5f07d9473887', 'carbohydrates', 73),  -- Carboidratos
  ('2b7fdea7-7ece-5f09-83e6-5f07d9473887', 'fiber', 5.1),  -- Fibra Alimentar
  ('2b7fdea7-7ece-5f09-83e6-5f07d9473887', 'saturatedFat', 3.7),  -- Gorduras Saturadas
  ('2b7fdea7-7ece-5f09-83e6-5f07d9473887', 'fat', 3),  -- Gorduras Totais
  ('2b7fdea7-7ece-5f09-83e6-5f07d9473887', 'protein', 1.6),  -- Proteínas
  ('2b7fdea7-7ece-5f09-83e6-5f07d9473887', 'sodium', 184),  -- Sódio
  ('2b7fdea7-7ece-5f09-83e6-5f07d9473887', 'calories', 377)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
