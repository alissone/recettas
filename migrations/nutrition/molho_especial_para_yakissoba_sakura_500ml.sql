-- Molho Especial para Yakissoba SAKURA 500ml
-- Marca: Sakura
-- Codigo: 1415667
-- Fonte: https://www.extramercado.com.br/produto/73998/molho-especial-para-yakissoba-sakura-500ml
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 10 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('3ebd32af-12ce-5f1d-b3d4-d74c132ecc6a', null, 'Molho Especial para Yakissoba SAKURA 500ml', 'Sakura', 10, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('3ebd32af-12ce-5f1d-b3d4-d74c132ecc6a', 'addedSugar', 6.8),  -- Açúcares Adicionados
  ('3ebd32af-12ce-5f1d-b3d4-d74c132ecc6a', 'sugar', 6.8),  -- Açúcares Totais
  ('3ebd32af-12ce-5f1d-b3d4-d74c132ecc6a', 'carbohydrates', 11),  -- Carboidratos
  ('3ebd32af-12ce-5f1d-b3d4-d74c132ecc6a', 'protein', 0.7),  -- Proteínas
  ('3ebd32af-12ce-5f1d-b3d4-d74c132ecc6a', 'sodium', 2633),  -- Sódio
  ('3ebd32af-12ce-5f1d-b3d4-d74c132ecc6a', 'calories', 47)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
