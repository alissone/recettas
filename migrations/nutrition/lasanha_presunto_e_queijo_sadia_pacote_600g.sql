-- Lasanha Presunto e Queijo Sadia Pacote 600g
-- Marca: Sadia
-- Codigo: 1108325
-- Fonte: https://www.extramercado.com.br/produto/374205/lasanha-presunto-e-queijo-sadia-pacote-600g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('4ba23eab-fa02-5810-802c-6faa7fafadd8', null, 'Lasanha Presunto e Queijo Sadia Pacote 600g', 'Sadia', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('4ba23eab-fa02-5810-802c-6faa7fafadd8', 'addedSugar', 0.4),  -- Açúcares Adicionados
  ('4ba23eab-fa02-5810-802c-6faa7fafadd8', 'sugar', 2.4),  -- Açúcares Totais
  ('4ba23eab-fa02-5810-802c-6faa7fafadd8', 'carbohydrates', 13),  -- Carboidratos
  ('4ba23eab-fa02-5810-802c-6faa7fafadd8', 'fiber', 1),  -- Fibra Alimentar
  ('4ba23eab-fa02-5810-802c-6faa7fafadd8', 'saturatedFat', 2.1),  -- Gorduras Saturadas
  ('4ba23eab-fa02-5810-802c-6faa7fafadd8', 'fat', 4.4),  -- Gorduras Totais
  ('4ba23eab-fa02-5810-802c-6faa7fafadd8', 'transFat', 0),  -- Gorduras Trans
  ('4ba23eab-fa02-5810-802c-6faa7fafadd8', 'protein', 4.8),  -- Proteínas
  ('4ba23eab-fa02-5810-802c-6faa7fafadd8', 'sodium', 253),  -- Sódio
  ('4ba23eab-fa02-5810-802c-6faa7fafadd8', 'calories', 111)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
