-- Farinha de amendoim
-- Valores aproximados de referência (amendoim torrado moído/em farinha
-- - perfil nutricional próximo ao do amendoim torrado sem sal, não
-- escaneado de um produto específico).
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', null, 'Farinha de amendoim', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'calories', 585),  -- Valor energético
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'protein', 23.7),  -- Proteína
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'fat', 49.7),  -- Gorduras totais
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'saturatedFat', 6.9),  -- Gorduras saturadas
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'monounsaturatedFat', 24.6),  -- Gorduras monoinsaturadas
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'polyunsaturatedFat', 15.8),  -- Gorduras poli-insaturadas
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'carbohydrates', 21.3),  -- Carboidratos
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'fiber', 8.5),  -- Fibra alimentar
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'sugar', 4.7),  -- Açúcares totais
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'sodium', 6),  -- Sódio
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'calcium', 54),  -- Cálcio
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'iron', 2.3),  -- Ferro
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'magnesium', 176),  -- Magnésio
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'potassium', 658),  -- Potássio
  ('e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 'zinc', 3.3)  -- Zinco
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
