-- Leite Em Pó Nestlé Ninho 380g Integral Instantâneo
-- Marca: Ninho
-- Codigo: 1389757
-- Fonte: https://www.extramercado.com.br/produto/1657439/leite-em-po-nestle-ninho-380g-integral-instantaneo
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 25 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', null, 'Leite Em Pó Nestlé Ninho 380g Integral Instantâneo', 'Ninho', 25, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'addedSugar', 0),  -- Açúcares Adicionados
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'sugar', 4.5),  -- Açúcares Totais
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'calcium', 191),  -- Cálcio
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'carbohydrates', 4.7),  -- Carboidratos
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'iron', 1.4),  -- Ferro
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'fiber', 0),  -- Fibra Alimentar
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'saturatedFat', 2.2),  -- Gorduras Saturadas
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'fat', 3.4),  -- Gorduras Totais
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'transFat', 0.1),  -- Gorduras Trans
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'protein', 3.2),  -- Proteínas
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'sodium', 49),  -- Sódio
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'calories', 63),  -- Valor energético
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'vitaminA', 100),  -- Vitamina A
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'vitaminC', 9.5),  -- Vitamina C
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'vitaminD', 1.4),  -- Vitamina D
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'vitaminE', 1.9),  -- Vitamina E
  ('d0bc31cb-510f-5aeb-8be5-7922e4e9413b', 'zinc', 1.1)  -- Zinco
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
