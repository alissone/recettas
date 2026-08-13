-- Tapioca Da Terrinha Pacote 500g
-- Marca: da Terrinha
-- Codigo: 1021136
-- Fonte: https://www.extramercado.com.br/produto/302369/tapioca-da-terrinha-pacote-500g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 30 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('4a5c3d26-691e-5566-ab60-69b57084ec40', null, 'Tapioca Da Terrinha Pacote 500g', 'da Terrinha', 30, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('4a5c3d26-691e-5566-ab60-69b57084ec40', 'carbohydrates', 52),  -- Carboidratos
  ('4a5c3d26-691e-5566-ab60-69b57084ec40', 'fiber', 0.5),  -- Fibra Alimentar
  ('4a5c3d26-691e-5566-ab60-69b57084ec40', 'saturatedFat', 0.5),  -- Gorduras Saturadas
  ('4a5c3d26-691e-5566-ab60-69b57084ec40', 'fat', 0.5),  -- Gorduras Totais
  ('4a5c3d26-691e-5566-ab60-69b57084ec40', 'transFat', 0.5),  -- Gorduras Trans
  ('4a5c3d26-691e-5566-ab60-69b57084ec40', 'protein', 0.5),  -- Proteínas
  ('4a5c3d26-691e-5566-ab60-69b57084ec40', 'sodium', 190),  -- Sódio
  ('4a5c3d26-691e-5566-ab60-69b57084ec40', 'calories', 227)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
