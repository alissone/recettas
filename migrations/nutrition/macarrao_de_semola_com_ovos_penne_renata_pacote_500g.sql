-- Macarrão de Sêmola com Ovos Penne Renata Pacote 500g
-- Marca: Renata
-- Codigo: 0734974
-- Fonte: https://www.extramercado.com.br/produto/52919/macarrao-de-semola-com-ovos-penne-renata-pacote-500g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 80 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('0e042902-3466-5b43-b27e-84f8b534d9fe', null, 'Macarrão de Sêmola com Ovos Penne Renata Pacote 500g', 'Renata', 80, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('0e042902-3466-5b43-b27e-84f8b534d9fe', 'carbohydrates', 59),  -- Carboidratos
  ('0e042902-3466-5b43-b27e-84f8b534d9fe', 'fiber', 2),  -- Fibra Alimentar
  ('0e042902-3466-5b43-b27e-84f8b534d9fe', 'saturatedFat', 0),  -- Gorduras Saturadas
  ('0e042902-3466-5b43-b27e-84f8b534d9fe', 'fat', 1.4),  -- Gorduras Totais
  ('0e042902-3466-5b43-b27e-84f8b534d9fe', 'transFat', 0),  -- Gorduras Trans
  ('0e042902-3466-5b43-b27e-84f8b534d9fe', 'protein', 8.8),  -- Proteínas
  ('0e042902-3466-5b43-b27e-84f8b534d9fe', 'sodium', 6),  -- Sódio
  ('0e042902-3466-5b43-b27e-84f8b534d9fe', 'calories', 284)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
