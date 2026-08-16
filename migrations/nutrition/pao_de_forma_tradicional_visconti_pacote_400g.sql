-- Pão de Forma Tradicional Visconti Pacote 400g
-- Marca: Visconti
-- Codigo: 1135666
-- Fonte: https://www.extramercado.com.br/produto/412359/pao-de-forma-tradicional-visconti-pacote-400g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 50 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('e2c0a278-011b-5ca1-bd41-74bcb58e261d', null, 'Pão de Forma Tradicional Visconti Pacote 400g', 'Visconti', 50, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('e2c0a278-011b-5ca1-bd41-74bcb58e261d', 'addedSugar', 3.8),  -- Açúcares Adicionados
  ('e2c0a278-011b-5ca1-bd41-74bcb58e261d', 'sugar', 11),  -- Açúcares Totais
  ('e2c0a278-011b-5ca1-bd41-74bcb58e261d', 'carbohydrates', 50),  -- Carboidratos
  ('e2c0a278-011b-5ca1-bd41-74bcb58e261d', 'cholesterol', 0),  -- Colesterol
  ('e2c0a278-011b-5ca1-bd41-74bcb58e261d', 'fiber', 2.5),  -- Fibra Alimentar
  ('e2c0a278-011b-5ca1-bd41-74bcb58e261d', 'monounsaturatedFat', 0.5),  -- Gorduras Monoinsaturadas
  ('e2c0a278-011b-5ca1-bd41-74bcb58e261d', 'polyunsaturatedFat', 0.5),  -- Gorduras Poliinsaturadas
  ('e2c0a278-011b-5ca1-bd41-74bcb58e261d', 'saturatedFat', 1.2),  -- Gorduras Saturadas
  ('e2c0a278-011b-5ca1-bd41-74bcb58e261d', 'fat', 4.3),  -- Gorduras Totais
  ('e2c0a278-011b-5ca1-bd41-74bcb58e261d', 'transFat', 0),  -- Gorduras Trans
  ('e2c0a278-011b-5ca1-bd41-74bcb58e261d', 'protein', 9),  -- Proteínas
  ('e2c0a278-011b-5ca1-bd41-74bcb58e261d', 'sodium', 474),  -- Sódio
  ('e2c0a278-011b-5ca1-bd41-74bcb58e261d', 'calories', 275)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
