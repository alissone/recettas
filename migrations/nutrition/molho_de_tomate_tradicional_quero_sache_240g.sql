-- Molho de Tomate Tradicional Quero Sachê 240g
-- Marca: Quero
-- Codigo: 1405412
-- Fonte: https://www.extramercado.com.br/produto/1663432/molho-de-tomate-tradicional-quero-sache-240g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 60 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('1ce3ff2e-ee07-5cec-962a-c1ca112d7c7d', null, 'Molho de Tomate Tradicional Quero Sachê 240g', 'Quero', 60, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('1ce3ff2e-ee07-5cec-962a-c1ca112d7c7d', 'addedSugar', 1.7),  -- Açúcares Adicionados
  ('1ce3ff2e-ee07-5cec-962a-c1ca112d7c7d', 'sugar', 3.2),  -- Açúcares Totais
  ('1ce3ff2e-ee07-5cec-962a-c1ca112d7c7d', 'carbohydrates', 6.2),  -- Carboidratos
  ('1ce3ff2e-ee07-5cec-962a-c1ca112d7c7d', 'fiber', 0.6),  -- Fibra Alimentar
  ('1ce3ff2e-ee07-5cec-962a-c1ca112d7c7d', 'saturatedFat', 0),  -- Gorduras Saturadas
  ('1ce3ff2e-ee07-5cec-962a-c1ca112d7c7d', 'fat', 0),  -- Gorduras Totais
  ('1ce3ff2e-ee07-5cec-962a-c1ca112d7c7d', 'transFat', 0),  -- Gorduras Trans
  ('1ce3ff2e-ee07-5cec-962a-c1ca112d7c7d', 'protein', 0),  -- Proteínas
  ('1ce3ff2e-ee07-5cec-962a-c1ca112d7c7d', 'sodium', 360),  -- Sódio
  ('1ce3ff2e-ee07-5cec-962a-c1ca112d7c7d', 'calories', 26)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
