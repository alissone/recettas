-- Xarope de guaraná
-- Valores aproximados de referência (xarope concentrado de guaraná
-- amazônico, tipo vendido em casas de sucos - não escaneado de um
-- produto especifico, pois rótulos variam muito de marca para marca).
--
-- Valores por 100 ml. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('50fdd582-dc87-5a52-be6d-df8b7ab3df3a', null, 'Xarope de guaraná', 100, 'ml')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('50fdd582-dc87-5a52-be6d-df8b7ab3df3a', 'calories', 290),  -- Valor energético
  ('50fdd582-dc87-5a52-be6d-df8b7ab3df3a', 'carbohydrates', 72),  -- Carboidratos
  ('50fdd582-dc87-5a52-be6d-df8b7ab3df3a', 'sugar', 68),  -- Açúcares totais
  ('50fdd582-dc87-5a52-be6d-df8b7ab3df3a', 'addedSugar', 65),  -- Açúcares adicionados
  ('50fdd582-dc87-5a52-be6d-df8b7ab3df3a', 'protein', 0.2),  -- Proteína
  ('50fdd582-dc87-5a52-be6d-df8b7ab3df3a', 'fat', 0),  -- Gorduras totais
  ('50fdd582-dc87-5a52-be6d-df8b7ab3df3a', 'sodium', 15),  -- Sódio
  ('50fdd582-dc87-5a52-be6d-df8b7ab3df3a', 'caffeine', 90)  -- Cafeína
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
