-- Açaí, polpa, congelada
-- Valores aproximados de referência (polpa de açaí congelada, sem
-- adição de guaraná ou açúcar, não escaneado de um produto específico).
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('600dbcc1-1225-5f04-afdc-8d883f5cb9c6', null, 'Açaí, polpa, congelada', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('600dbcc1-1225-5f04-afdc-8d883f5cb9c6', 'calories', 60),  -- Valor energético
  ('600dbcc1-1225-5f04-afdc-8d883f5cb9c6', 'protein', 0.8),  -- Proteína
  ('600dbcc1-1225-5f04-afdc-8d883f5cb9c6', 'fat', 4),  -- Gorduras totais
  ('600dbcc1-1225-5f04-afdc-8d883f5cb9c6', 'saturatedFat', 0.9),  -- Gorduras saturadas
  ('600dbcc1-1225-5f04-afdc-8d883f5cb9c6', 'monounsaturatedFat', 2.7),  -- Gorduras monoinsaturadas
  ('600dbcc1-1225-5f04-afdc-8d883f5cb9c6', 'polyunsaturatedFat', 0.3),  -- Gorduras poli-insaturadas
  ('600dbcc1-1225-5f04-afdc-8d883f5cb9c6', 'carbohydrates', 6),  -- Carboidratos
  ('600dbcc1-1225-5f04-afdc-8d883f5cb9c6', 'fiber', 2.6),  -- Fibra alimentar
  ('600dbcc1-1225-5f04-afdc-8d883f5cb9c6', 'sugar', 3),  -- Açúcares totais
  ('600dbcc1-1225-5f04-afdc-8d883f5cb9c6', 'sodium', 3),  -- Sódio
  ('600dbcc1-1225-5f04-afdc-8d883f5cb9c6', 'calcium', 30),  -- Cálcio
  ('600dbcc1-1225-5f04-afdc-8d883f5cb9c6', 'iron', 0.6),  -- Ferro
  ('600dbcc1-1225-5f04-afdc-8d883f5cb9c6', 'vitaminC', 3)  -- Vitamina C
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
