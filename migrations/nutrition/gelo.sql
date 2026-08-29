-- Gelo
-- Água congelada - sem valor calórico ou nutricional relevante.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, base_amount, base_unit)
values ('5cdb0f4b-630e-58c3-9368-d2c9c7af6c42', null, 'Gelo', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('5cdb0f4b-630e-58c3-9368-d2c9c7af6c42', 'calories', 0),  -- Valor energético
  ('5cdb0f4b-630e-58c3-9368-d2c9c7af6c42', 'water', 100)  -- Água
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
