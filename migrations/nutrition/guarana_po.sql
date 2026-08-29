-- Guaraná, pó
-- Valores aproximados de referência (semente de guaraná moída em pó,
-- rica em cafeína, não escaneado de um produto específico).
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('9aa437f1-22f5-59c5-a889-e0e16b73db7a', null, 'Guaraná, pó', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('9aa437f1-22f5-59c5-a889-e0e16b73db7a', 'calories', 350),  -- Valor energético
  ('9aa437f1-22f5-59c5-a889-e0e16b73db7a', 'protein', 6),  -- Proteína
  ('9aa437f1-22f5-59c5-a889-e0e16b73db7a', 'fat', 2),  -- Gorduras totais
  ('9aa437f1-22f5-59c5-a889-e0e16b73db7a', 'carbohydrates', 78),  -- Carboidratos
  ('9aa437f1-22f5-59c5-a889-e0e16b73db7a', 'fiber', 6),  -- Fibra alimentar
  ('9aa437f1-22f5-59c5-a889-e0e16b73db7a', 'sodium', 5),  -- Sódio
  ('9aa437f1-22f5-59c5-a889-e0e16b73db7a', 'caffeine', 3800)  -- Cafeína
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
