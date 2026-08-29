-- Maracujá, polpa
-- Valores aproximados de referência (polpa de maracujá com sementes,
-- não escaneada de um produto específico).
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('0f0b2258-f594-5cdd-9903-b7ef90519f55', null, 'Maracujá, polpa', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('0f0b2258-f594-5cdd-9903-b7ef90519f55', 'calories', 68),  -- Valor energético
  ('0f0b2258-f594-5cdd-9903-b7ef90519f55', 'protein', 1.5),  -- Proteína
  ('0f0b2258-f594-5cdd-9903-b7ef90519f55', 'fat', 1.2),  -- Gorduras totais
  ('0f0b2258-f594-5cdd-9903-b7ef90519f55', 'carbohydrates', 12.3),  -- Carboidratos
  ('0f0b2258-f594-5cdd-9903-b7ef90519f55', 'fiber', 1.9),  -- Fibra alimentar
  ('0f0b2258-f594-5cdd-9903-b7ef90519f55', 'sugar', 9),  -- Açúcares totais
  ('0f0b2258-f594-5cdd-9903-b7ef90519f55', 'sodium', 4),  -- Sódio
  ('0f0b2258-f594-5cdd-9903-b7ef90519f55', 'calcium', 4),  -- Cálcio
  ('0f0b2258-f594-5cdd-9903-b7ef90519f55', 'iron', 0.6),  -- Ferro
  ('0f0b2258-f594-5cdd-9903-b7ef90519f55', 'potassium', 172),  -- Potássio
  ('0f0b2258-f594-5cdd-9903-b7ef90519f55', 'vitaminC', 20),  -- Vitamina C
  ('0f0b2258-f594-5cdd-9903-b7ef90519f55', 'vitaminA', 55)  -- Vitamina A
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
