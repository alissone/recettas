-- Salsicha Hot-Dog Sadia 500g 10 Unidades
-- Marca: Sadia
-- Codigo: 1171433
-- Fonte: https://www.extramercado.com.br/produto/114859/salsicha-hot-dog-sadia-500g-10-unidades
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 50 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('c235493b-4718-5cb9-8d7d-2e2145bb12fc', null, 'Salsicha Hot-Dog Sadia 500g 10 Unidades', 'Sadia', 50, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('c235493b-4718-5cb9-8d7d-2e2145bb12fc', 'addedSugar', 0),  -- Açúcares Adicionados
  ('c235493b-4718-5cb9-8d7d-2e2145bb12fc', 'sugar', 0),  -- Açúcares Totais
  ('c235493b-4718-5cb9-8d7d-2e2145bb12fc', 'carbohydrates', 2.8),  -- Carboidratos
  ('c235493b-4718-5cb9-8d7d-2e2145bb12fc', 'fiber', 0),  -- Fibra Alimentar
  ('c235493b-4718-5cb9-8d7d-2e2145bb12fc', 'saturatedFat', 5.9),  -- Gorduras Saturadas
  ('c235493b-4718-5cb9-8d7d-2e2145bb12fc', 'fat', 16),  -- Gorduras Totais
  ('c235493b-4718-5cb9-8d7d-2e2145bb12fc', 'transFat', 0),  -- Gorduras Trans
  ('c235493b-4718-5cb9-8d7d-2e2145bb12fc', 'protein', 13),  -- Proteínas
  ('c235493b-4718-5cb9-8d7d-2e2145bb12fc', 'sodium', 976),  -- Sódio
  ('c235493b-4718-5cb9-8d7d-2e2145bb12fc', 'calories', 207)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
