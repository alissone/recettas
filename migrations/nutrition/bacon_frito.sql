-- Bacon, frito
-- Valores aproximados de referência (bacon frito, escorrido, não
-- escaneado de um produto específico).
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('36d0e6da-2f52-595f-bb74-44b913756669', null, 'Bacon, frito', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('36d0e6da-2f52-595f-bb74-44b913756669', 'calories', 541),  -- Valor energético
  ('36d0e6da-2f52-595f-bb74-44b913756669', 'protein', 37),  -- Proteína
  ('36d0e6da-2f52-595f-bb74-44b913756669', 'fat', 42),  -- Gorduras totais
  ('36d0e6da-2f52-595f-bb74-44b913756669', 'saturatedFat', 14),  -- Gorduras saturadas
  ('36d0e6da-2f52-595f-bb74-44b913756669', 'carbohydrates', 1.4),  -- Carboidratos
  ('36d0e6da-2f52-595f-bb74-44b913756669', 'sugar', 0),  -- Açúcares totais
  ('36d0e6da-2f52-595f-bb74-44b913756669', 'sodium', 1717),  -- Sódio
  ('36d0e6da-2f52-595f-bb74-44b913756669', 'cholesterol', 110)  -- Colesterol
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
