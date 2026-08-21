-- Bebida Láctea UHT Chocolate Nescau Caixa 1L Tamanho Família
-- Marca: Nescau
-- Codigo: 0213264
-- Fonte: https://www.extramercado.com.br/produto/57730/bebida-lactea-uht-chocolate-nescau-caixa-1l-tamanho-familia
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 200 ml. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.
--
-- Nutrientes da embalagem sem correspondencia no catalogo,
-- portanto NAO importados:
--   Açúcares

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', null, 'Bebida Láctea UHT Chocolate Nescau Caixa 1L Tamanho Família', 'Nescau', 200, 'ml')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'addedSugar', 5.1),  -- Açúcares Adicionados
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'sugar', 11),  -- Açúcares Totais
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'calcium', 90),  -- Cálcio
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'carbohydrates', 11),  -- Carboidratos
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'cholesterol', 11),  -- Colesterol
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'iron', 1.3),  -- Ferro
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'fiber', 0.5),  -- Fibra Alimentar
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'monounsaturatedFat', 0.6),  -- Gorduras Monoinsaturadas
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'polyunsaturatedFat', 0.1),  -- Gorduras Poliinsaturadas
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'saturatedFat', 1),  -- Gorduras Saturadas
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'fat', 1.5),  -- Gorduras Totais
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'transFat', 0),  -- Gorduras Trans
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'vitaminB3', 2.9),  -- Niacina
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'protein', 2),  -- Proteínas
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'vitaminB2', 0.25),  -- Riboflavina
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'sodium', 64),  -- Sódio
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'calories', 67),  -- Valor energético
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'vitaminA', 72),  -- Vitamina A
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'vitaminB12', 0.23),  -- Vitamina B12
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'vitaminB6', 0.13),  -- Vitamina B6
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'vitaminC', 3.4),  -- Vitamina C
  ('a4fd3c67-ad97-540a-bca9-8b16ca5c1eb3', 'vitaminD', 1.4)  -- Vitamina D
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
