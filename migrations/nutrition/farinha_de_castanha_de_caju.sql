-- Farinha de castanha-de-caju
-- Valores aproximados de referência (castanha-de-caju moída/em pó -
-- perfil nutricional próximo ao da castanha crua, não escaneado de um
-- produto específico).
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('232e4f81-56ca-5930-beb0-2295c1e52454', null, 'Farinha de castanha-de-caju', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'calories', 553),  -- Valor energético
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'protein', 18.2),  -- Proteína
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'fat', 43.9),  -- Gorduras totais
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'saturatedFat', 7.8),  -- Gorduras saturadas
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'monounsaturatedFat', 23.8),  -- Gorduras monoinsaturadas
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'polyunsaturatedFat', 7.8),  -- Gorduras poli-insaturadas
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'carbohydrates', 30.2),  -- Carboidratos
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'fiber', 3.3),  -- Fibra alimentar
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'sugar', 5.9),  -- Açúcares totais
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'sodium', 12),  -- Sódio
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'calcium', 37),  -- Cálcio
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'iron', 6.7),  -- Ferro
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'magnesium', 292),  -- Magnésio
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'potassium', 660),  -- Potássio
  ('232e4f81-56ca-5930-beb0-2295c1e52454', 'zinc', 5.8)  -- Zinco
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
