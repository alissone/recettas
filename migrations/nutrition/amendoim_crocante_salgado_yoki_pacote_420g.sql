-- Amendoim Crocante Salgado Yoki Pacote 420g
-- Marca: Yoki
-- Codigo: 1410057
-- Fonte: https://www.extramercado.com.br/produto/1666425/amendoim-crocante-salgado-yoki-pacote-420g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 25 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('6a8f2144-a7d3-5657-a738-c605b42b662f', null, 'Amendoim Crocante Salgado Yoki Pacote 420g', 'Yoki', 25, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('6a8f2144-a7d3-5657-a738-c605b42b662f', 'addedSugar', 7.3),  -- Açúcares Adicionados
  ('6a8f2144-a7d3-5657-a738-c605b42b662f', 'sugar', 8.8),  -- Açúcares Totais
  ('6a8f2144-a7d3-5657-a738-c605b42b662f', 'carbohydrates', 42),  -- Carboidratos
  ('6a8f2144-a7d3-5657-a738-c605b42b662f', 'fiber', 5.9),  -- Fibra Alimentar
  ('6a8f2144-a7d3-5657-a738-c605b42b662f', 'saturatedFat', 4.7),  -- Gorduras Saturadas
  ('6a8f2144-a7d3-5657-a738-c605b42b662f', 'fat', 27),  -- Gorduras Totais
  ('6a8f2144-a7d3-5657-a738-c605b42b662f', 'transFat', 0),  -- Gorduras Trans
  ('6a8f2144-a7d3-5657-a738-c605b42b662f', 'protein', 20),  -- Proteínas
  ('6a8f2144-a7d3-5657-a738-c605b42b662f', 'sodium', 562),  -- Sódio
  ('6a8f2144-a7d3-5657-a738-c605b42b662f', 'calories', 491)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
