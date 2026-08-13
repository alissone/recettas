-- Mistura para Bolo de Chocolate com Avelã Dona Benta Pacote 450g
-- Marca: Dona Benta
-- Codigo: 1111527
-- Fonte: https://www.extramercado.com.br/produto/376467/mistura-para-bolo-de-chocolate-com-avela-dona-benta-pacote-450g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 38 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('15d9a0f2-aaea-50dd-bd5e-e9d20271a33f', null, 'Mistura para Bolo de Chocolate com Avelã Dona Benta Pacote 450g', 'Dona Benta', 38, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('15d9a0f2-aaea-50dd-bd5e-e9d20271a33f', 'addedSugar', 30),  -- Açúcares Adicionados
  ('15d9a0f2-aaea-50dd-bd5e-e9d20271a33f', 'sugar', 30),  -- Açúcares Totais
  ('15d9a0f2-aaea-50dd-bd5e-e9d20271a33f', 'carbohydrates', 51),  -- Carboidratos
  ('15d9a0f2-aaea-50dd-bd5e-e9d20271a33f', 'fiber', 2.5),  -- Fibra Alimentar
  ('15d9a0f2-aaea-50dd-bd5e-e9d20271a33f', 'saturatedFat', 2.6),  -- Gorduras Saturadas
  ('15d9a0f2-aaea-50dd-bd5e-e9d20271a33f', 'fat', 12),  -- Gorduras Totais
  ('15d9a0f2-aaea-50dd-bd5e-e9d20271a33f', 'transFat', 1.6),  -- Gorduras Trans
  ('15d9a0f2-aaea-50dd-bd5e-e9d20271a33f', 'protein', 7.2),  -- Proteínas
  ('15d9a0f2-aaea-50dd-bd5e-e9d20271a33f', 'sodium', 365),  -- Sódio
  ('15d9a0f2-aaea-50dd-bd5e-e9d20271a33f', 'calories', 341)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
