-- Maionese Heinz Tradicional 390g
-- Marca: Heinz
-- Codigo: 1089986
-- Fonte: https://www.extramercado.com.br/produto/356974/maionese-heinz-tradicional-390g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 12 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('ed19bd6c-c3ec-53cb-a8d4-0c16af17101b', null, 'Maionese Heinz Tradicional 390g', 'Heinz', 12, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('ed19bd6c-c3ec-53cb-a8d4-0c16af17101b', 'addedSugar', 2),  -- Açúcares Adicionados
  ('ed19bd6c-c3ec-53cb-a8d4-0c16af17101b', 'sugar', 2.1),  -- Açúcares Totais
  ('ed19bd6c-c3ec-53cb-a8d4-0c16af17101b', 'carbohydrates', 2.6),  -- Carboidratos
  ('ed19bd6c-c3ec-53cb-a8d4-0c16af17101b', 'fiber', 0),  -- Fibra Alimentar
  ('ed19bd6c-c3ec-53cb-a8d4-0c16af17101b', 'saturatedFat', 13),  -- Gorduras Saturadas
  ('ed19bd6c-c3ec-53cb-a8d4-0c16af17101b', 'fat', 68),  -- Gorduras Totais
  ('ed19bd6c-c3ec-53cb-a8d4-0c16af17101b', 'transFat', 1),  -- Gorduras Trans
  ('ed19bd6c-c3ec-53cb-a8d4-0c16af17101b', 'protein', 1.4),  -- Proteínas
  ('ed19bd6c-c3ec-53cb-a8d4-0c16af17101b', 'sodium', 590),  -- Sódio
  ('ed19bd6c-c3ec-53cb-a8d4-0c16af17101b', 'calories', 629)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
