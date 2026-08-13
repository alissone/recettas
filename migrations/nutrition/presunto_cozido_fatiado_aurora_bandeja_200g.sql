-- Presunto Cozido Fatiado Aurora Bandeja 200g
-- Marca: Aurora
-- Codigo: 0080002
-- Fonte: https://www.extramercado.com.br/produto/30259/presunto-cozido-fatiado-aurora-bandeja-200g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 30 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('2f43195f-1442-58e2-b07e-cb5ebeca98ed', null, 'Presunto Cozido Fatiado Aurora Bandeja 200g', 'Aurora', 30, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('2f43195f-1442-58e2-b07e-cb5ebeca98ed', 'sodium', 414),  -- Sódio
  ('2f43195f-1442-58e2-b07e-cb5ebeca98ed', 'saturatedFat', 0.9),  -- Gorduras saturadas
  ('2f43195f-1442-58e2-b07e-cb5ebeca98ed', 'carbohydrates', 0),  -- Carboidratos
  ('2f43195f-1442-58e2-b07e-cb5ebeca98ed', 'transFat', 0),  -- Gorduras Trans
  ('2f43195f-1442-58e2-b07e-cb5ebeca98ed', 'protein', 4.8),  -- Proteínas
  ('2f43195f-1442-58e2-b07e-cb5ebeca98ed', 'calories', 48),  -- Valor Energético
  ('2f43195f-1442-58e2-b07e-cb5ebeca98ed', 'fiber', 0),  -- Fibra alimentar
  ('2f43195f-1442-58e2-b07e-cb5ebeca98ed', 'fat', 3)  -- Gorduras totais
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
