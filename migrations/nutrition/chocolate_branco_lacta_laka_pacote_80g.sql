-- Chocolate Branco Lacta Laka Pacote 80g
-- Marca: Lacta
-- Codigo: 1363939
-- Fonte: https://www.extramercado.com.br/produto/1555473/chocolate-branco-lacta-laka-pacote-80g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 25 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('f84086b7-c47c-53cc-a602-afb01ab86318', null, 'Chocolate Branco Lacta Laka Pacote 80g', 'Lacta', 25, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('f84086b7-c47c-53cc-a602-afb01ab86318', 'addedSugar', 43),  -- Açúcares Adicionados
  ('f84086b7-c47c-53cc-a602-afb01ab86318', 'sugar', 60),  -- Açúcares Totais
  ('f84086b7-c47c-53cc-a602-afb01ab86318', 'carbohydrates', 60),  -- Carboidratos
  ('f84086b7-c47c-53cc-a602-afb01ab86318', 'fiber', 0),  -- Fibra Alimentar
  ('f84086b7-c47c-53cc-a602-afb01ab86318', 'saturatedFat', 18),  -- Gorduras Saturadas
  ('f84086b7-c47c-53cc-a602-afb01ab86318', 'fat', 31),  -- Gorduras Totais
  ('f84086b7-c47c-53cc-a602-afb01ab86318', 'transFat', 0.3),  -- Gorduras Trans
  ('f84086b7-c47c-53cc-a602-afb01ab86318', 'protein', 5.5),  -- Proteínas
  ('f84086b7-c47c-53cc-a602-afb01ab86318', 'sodium', 144),  -- Sódio
  ('f84086b7-c47c-53cc-a602-afb01ab86318', 'calories', 541)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
