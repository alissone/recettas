-- Macarrão Instantâneo de Galinha Nissin Miojo Lámen Pacote 85g
-- Marca: Nissin
-- Codigo: 1366334
-- Fonte: https://www.extramercado.com.br/produto/170163/macarrao-instantaneo-de-galinha-nissin-miojo-lamen-pacote-85g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 85 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('090450ef-3ff3-5b60-b9c9-908be3e02ecb', null, 'Macarrão Instantâneo de Galinha Nissin Miojo Lámen Pacote 85g', 'Nissin', 85, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('090450ef-3ff3-5b60-b9c9-908be3e02ecb', 'carbohydrates', 49),  -- Carboidratos
  ('090450ef-3ff3-5b60-b9c9-908be3e02ecb', 'fiber', 2.2),  -- Fibra Alimentar
  ('090450ef-3ff3-5b60-b9c9-908be3e02ecb', 'saturatedFat', 7.1),  -- Gorduras Saturadas
  ('090450ef-3ff3-5b60-b9c9-908be3e02ecb', 'fat', 16),  -- Gorduras Totais
  ('090450ef-3ff3-5b60-b9c9-908be3e02ecb', 'transFat', 0),  -- Gorduras Trans
  ('090450ef-3ff3-5b60-b9c9-908be3e02ecb', 'protein', 8.5),  -- Proteínas
  ('090450ef-3ff3-5b60-b9c9-908be3e02ecb', 'sodium', 1395),  -- Sódio
  ('090450ef-3ff3-5b60-b9c9-908be3e02ecb', 'calories', 374)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
