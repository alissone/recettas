-- Creme de Avelã Nutella Pote 140g
-- Marca: Nutella
-- Codigo: 5160990
-- Fonte: https://www.extramercado.com.br/produto/222314/creme-de-avela-nutella-pote-140g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 20 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('912e5910-2978-50ba-a630-2f9d0ba19c23', null, 'Creme de Avelã Nutella Pote 140g', 'Nutella', 20, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('912e5910-2978-50ba-a630-2f9d0ba19c23', 'carbohydrates', 60),  -- Carboidratos
  ('912e5910-2978-50ba-a630-2f9d0ba19c23', 'fiber', 3),  -- Fibra Alimentar
  ('912e5910-2978-50ba-a630-2f9d0ba19c23', 'saturatedFat', 10.5),  -- Gorduras Saturadas
  ('912e5910-2978-50ba-a630-2f9d0ba19c23', 'fat', 31),  -- Gorduras Totais
  ('912e5910-2978-50ba-a630-2f9d0ba19c23', 'transFat', 0),  -- Gorduras Trans
  ('912e5910-2978-50ba-a630-2f9d0ba19c23', 'protein', 6.5),  -- Proteínas
  ('912e5910-2978-50ba-a630-2f9d0ba19c23', 'sodium', 42),  -- Sódio
  ('912e5910-2978-50ba-a630-2f9d0ba19c23', 'calories', 535)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
