-- Pack Biscoito Original Club Social Pacote 144g 6 Unidades
-- Marca: Club Social
-- Codigo: 1106919
-- Fonte: https://www.extramercado.com.br/produto/373088/pack-biscoito-original-club-social-pacote-144g-6-unidades
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 24 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.
--
-- Nutrientes da embalagem sem correspondencia no catalogo,
-- portanto NAO importados:
--   Açúcares

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('4371eb74-4cd9-5aa4-bfb5-c0d67ae23f1f', null, 'Pack Biscoito Original Club Social Pacote 144g 6 Unidades', 'Club Social', 24, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('4371eb74-4cd9-5aa4-bfb5-c0d67ae23f1f', 'addedSugar', 7.5),  -- Açúcares Adicionados
  ('4371eb74-4cd9-5aa4-bfb5-c0d67ae23f1f', 'sugar', 8),  -- Açúcares Totais
  ('4371eb74-4cd9-5aa4-bfb5-c0d67ae23f1f', 'carbohydrates', 63),  -- Carboidratos
  ('4371eb74-4cd9-5aa4-bfb5-c0d67ae23f1f', 'fiber', 2.2),  -- Fibra Alimentar
  ('4371eb74-4cd9-5aa4-bfb5-c0d67ae23f1f', 'saturatedFat', 4.1),  -- Gorduras Saturadas
  ('4371eb74-4cd9-5aa4-bfb5-c0d67ae23f1f', 'fat', 18),  -- Gorduras Totais
  ('4371eb74-4cd9-5aa4-bfb5-c0d67ae23f1f', 'transFat', 0.2),  -- Gorduras Trans
  ('4371eb74-4cd9-5aa4-bfb5-c0d67ae23f1f', 'protein', 8.1),  -- Proteínas
  ('4371eb74-4cd9-5aa4-bfb5-c0d67ae23f1f', 'sodium', 759),  -- Sódio
  ('4371eb74-4cd9-5aa4-bfb5-c0d67ae23f1f', 'calories', 451)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
