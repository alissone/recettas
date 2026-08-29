-- Abacate, cru
-- Valores aproximados de referência (abacate cru, polpa).
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('a5672928-3175-556c-8336-27ccc342f6a4', null, 'Abacate, cru', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'calories', 160),  -- Valor energético
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'protein', 2),  -- Proteína
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'fat', 14.7),  -- Gorduras totais
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'saturatedFat', 2.1),  -- Gorduras saturadas
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'monounsaturatedFat', 9.8),  -- Gorduras monoinsaturadas
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'polyunsaturatedFat', 1.8),  -- Gorduras poli-insaturadas
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'carbohydrates', 8.5),  -- Carboidratos
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'fiber', 6.7),  -- Fibra alimentar
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'sugar', 0.7),  -- Açúcares totais
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'sodium', 7),  -- Sódio
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'potassium', 485),  -- Potássio
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'magnesium', 29),  -- Magnésio
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'vitaminC', 10),  -- Vitamina C
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'vitaminE', 2.1),  -- Vitamina E
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'vitaminK', 21),  -- Vitamina K
  ('a5672928-3175-556c-8336-27ccc342f6a4', 'vitaminB9', 81)  -- Vitamina B9 (folato)
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
