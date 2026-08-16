-- Margarina com Sal Light Zero Lactose QUALY Pote 250g
-- Marca: Qualy
-- Codigo: 3698532
-- Fonte: https://www.extramercado.com.br/produto/5575/margarina-com-sal-light-zero-lactose-qualy-pote-250g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 10 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('83a77730-32a3-565e-8ff1-1ba98b9654ad', null, 'Margarina com Sal Light Zero Lactose QUALY Pote 250g', 'Qualy', 10, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('83a77730-32a3-565e-8ff1-1ba98b9654ad', 'carbohydrates', 0),  -- Carboidratos
  ('83a77730-32a3-565e-8ff1-1ba98b9654ad', 'cholesterol', 0),  -- Colesterol
  ('83a77730-32a3-565e-8ff1-1ba98b9654ad', 'fiber', 0),  -- Fibra Alimentar
  ('83a77730-32a3-565e-8ff1-1ba98b9654ad', 'monounsaturatedFat', 1),  -- Gorduras Monoinsaturadas
  ('83a77730-32a3-565e-8ff1-1ba98b9654ad', 'polyunsaturatedFat', 1.7),  -- Gorduras Poliinsaturadas
  ('83a77730-32a3-565e-8ff1-1ba98b9654ad', 'saturatedFat', 0.9),  -- Gorduras Saturadas
  ('83a77730-32a3-565e-8ff1-1ba98b9654ad', 'fat', 3.5),  -- Gorduras Totais
  ('83a77730-32a3-565e-8ff1-1ba98b9654ad', 'transFat', 0),  -- Gorduras Trans
  ('83a77730-32a3-565e-8ff1-1ba98b9654ad', 'protein', 0),  -- Proteínas
  ('83a77730-32a3-565e-8ff1-1ba98b9654ad', 'sodium', 70),  -- Sódio
  ('83a77730-32a3-565e-8ff1-1ba98b9654ad', 'calories', 32),  -- Valor energético
  ('83a77730-32a3-565e-8ff1-1ba98b9654ad', 'vitaminA', 45)  -- Vitamina A
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
