-- Filé de Peito de Frango Congelado sem Pele sem Osso Sadia 1kg
-- Marca: Sadia
-- Codigo: 1799316
-- Fonte: https://www.extramercado.com.br/produto/65885/file-de-peito-de-frango-congelado-sem-pele-sem-osso-sadia-1kg
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 100 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('ee762321-4b1f-57a6-a869-c217f36ac52e', null, 'Filé de Peito de Frango Congelado sem Pele sem Osso Sadia 1kg', 'Sadia', 100, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('ee762321-4b1f-57a6-a869-c217f36ac52e', 'addedSugar', 0),  -- Açúcares Adicionados
  ('ee762321-4b1f-57a6-a869-c217f36ac52e', 'sugar', 0),  -- Açúcares Totais
  ('ee762321-4b1f-57a6-a869-c217f36ac52e', 'carbohydrates', 0),  -- Carboidratos
  ('ee762321-4b1f-57a6-a869-c217f36ac52e', 'fiber', 0),  -- Fibra Alimentar
  ('ee762321-4b1f-57a6-a869-c217f36ac52e', 'saturatedFat', 2.1),  -- Gorduras Saturadas
  ('ee762321-4b1f-57a6-a869-c217f36ac52e', 'fat', 6.6),  -- Gorduras Totais
  ('ee762321-4b1f-57a6-a869-c217f36ac52e', 'transFat', 0),  -- Gorduras Trans
  ('ee762321-4b1f-57a6-a869-c217f36ac52e', 'protein', 16.6),  -- Proteínas
  ('ee762321-4b1f-57a6-a869-c217f36ac52e', 'sodium', 52.5),  -- Sódio
  ('ee762321-4b1f-57a6-a869-c217f36ac52e', 'calories', 139)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
