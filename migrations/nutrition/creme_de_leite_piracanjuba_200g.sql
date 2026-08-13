-- Creme De Leite Piracanjuba 200g
-- Marca: Piracanjuba
-- Codigo: 4479024
-- Fonte: https://www.extramercado.com.br/produto/143696/creme-de-leite-piracanjuba-200g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 15 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('30f9c41c-fa8c-5ace-92b0-40b98f00ce13', null, 'Creme De Leite Piracanjuba 200g', 'Piracanjuba', 15, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('30f9c41c-fa8c-5ace-92b0-40b98f00ce13', 'addedSugar', 0),  -- Açúcares Adicionados
  ('30f9c41c-fa8c-5ace-92b0-40b98f00ce13', 'sugar', 4.6),  -- Açúcares Totais
  ('30f9c41c-fa8c-5ace-92b0-40b98f00ce13', 'carbohydrates', 4.6),  -- Carboidratos
  ('30f9c41c-fa8c-5ace-92b0-40b98f00ce13', 'fiber', 0),  -- Fibra Alimentar
  ('30f9c41c-fa8c-5ace-92b0-40b98f00ce13', 'saturatedFat', 9.3),  -- Gorduras Saturadas
  ('30f9c41c-fa8c-5ace-92b0-40b98f00ce13', 'fat', 15),  -- Gorduras Totais
  ('30f9c41c-fa8c-5ace-92b0-40b98f00ce13', 'transFat', 0),  -- Gorduras Trans
  ('30f9c41c-fa8c-5ace-92b0-40b98f00ce13', 'protein', 3.1),  -- Proteínas
  ('30f9c41c-fa8c-5ace-92b0-40b98f00ce13', 'sodium', 80),  -- Sódio
  ('30f9c41c-fa8c-5ace-92b0-40b98f00ce13', 'calories', 166)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
