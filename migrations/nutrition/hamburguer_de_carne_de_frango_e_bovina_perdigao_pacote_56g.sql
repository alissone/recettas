-- Hambúrguer de Carne de Frango e Bovina Perdigão Pacote 56g
-- Marca: Perdigão
-- Codigo: 4827313
-- Fonte: https://www.extramercado.com.br/produto/150925/hamburguer-de-carne-de-frango-e-bovina-perdigao-pacote-56g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 56 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('3c741ad6-d762-575c-bd30-bf43c724afce', null, 'Hambúrguer de Carne de Frango e Bovina Perdigão Pacote 56g', 'Perdigão', 56, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('3c741ad6-d762-575c-bd30-bf43c724afce', 'addedSugar', 0),  -- Açúcares Adicionados
  ('3c741ad6-d762-575c-bd30-bf43c724afce', 'sugar', 0),  -- Açúcares Totais
  ('3c741ad6-d762-575c-bd30-bf43c724afce', 'carbohydrates', 1.4),  -- Carboidratos
  ('3c741ad6-d762-575c-bd30-bf43c724afce', 'fiber', 1),  -- Fibra Alimentar
  ('3c741ad6-d762-575c-bd30-bf43c724afce', 'saturatedFat', 2.9),  -- Gorduras Saturadas
  ('3c741ad6-d762-575c-bd30-bf43c724afce', 'fat', 8.8),  -- Gorduras Totais
  ('3c741ad6-d762-575c-bd30-bf43c724afce', 'transFat', 0),  -- Gorduras Trans
  ('3c741ad6-d762-575c-bd30-bf43c724afce', 'protein', 15),  -- Proteínas
  ('3c741ad6-d762-575c-bd30-bf43c724afce', 'sodium', 700),  -- Sódio
  ('3c741ad6-d762-575c-bd30-bf43c724afce', 'calories', 145)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
