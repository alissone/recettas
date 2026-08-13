-- Dr. Oetker Confeito Granulado Mesclado Sabor Chocolate e Baunilha Decoração e Finalização de Doces e Sobremesas 130g
-- Marca: Dr.Oetker
-- Codigo: 4939405
-- Fonte: https://www.extramercado.com.br/produto/58316/dr--oetker-confeito-granulado-mesclado-sabor-chocolate-e-baunilha-decoracao-e-finalizacao-de-doces-e-sobremesas-130g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 15 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('fd9cc485-a60d-51e1-8320-a6aa98094e08', null, 'Dr. Oetker Confeito Granulado Mesclado Sabor Chocolate e Baunilha Decoração e Finalização de Doces e Sobremesas 130g', 'Dr.Oetker', 15, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('fd9cc485-a60d-51e1-8320-a6aa98094e08', 'saturatedFat', 0.9),  -- Gorduras  saturadas
  ('fd9cc485-a60d-51e1-8320-a6aa98094e08', 'carbohydrates', 12),  -- Carboidratos
  ('fd9cc485-a60d-51e1-8320-a6aa98094e08', 'fat', 2.4),  -- Gorduras  totais
  ('fd9cc485-a60d-51e1-8320-a6aa98094e08', 'transFat', 1.2),  -- Gorduras  trans
  ('fd9cc485-a60d-51e1-8320-a6aa98094e08', 'calories', 72)  -- Valor  energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
