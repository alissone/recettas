-- Amendoim Japonês Elma Chips Pacote 145G
-- Marca: Elma Chips
-- Codigo: 1207192
-- Fonte: https://www.extramercado.com.br/produto/448630/amendoim-japones-elma-chips-pacote-145g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 25 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.
--
-- Nutrientes da embalagem sem correspondencia no catalogo,
-- portanto NAO importados:
--   Açúcares

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('aba23a32-27ed-5a4c-88ec-257ff9d35fcd', null, 'Amendoim Japonês Elma Chips Pacote 145G', 'Elma Chips', 25, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('aba23a32-27ed-5a4c-88ec-257ff9d35fcd', 'addedSugar', 7.2),  -- Açúcares Adicionados
  ('aba23a32-27ed-5a4c-88ec-257ff9d35fcd', 'sugar', 9.7),  -- Açúcares Totais
  ('aba23a32-27ed-5a4c-88ec-257ff9d35fcd', 'carbohydrates', 39),  -- Carboidratos
  ('aba23a32-27ed-5a4c-88ec-257ff9d35fcd', 'fiber', 6),  -- Fibra Alimentar
  ('aba23a32-27ed-5a4c-88ec-257ff9d35fcd', 'saturatedFat', 4),  -- Gorduras Saturadas
  ('aba23a32-27ed-5a4c-88ec-257ff9d35fcd', 'fat', 31),  -- Gorduras Totais
  ('aba23a32-27ed-5a4c-88ec-257ff9d35fcd', 'transFat', 0),  -- Gorduras Trans
  ('aba23a32-27ed-5a4c-88ec-257ff9d35fcd', 'protein', 18),  -- Proteínas
  ('aba23a32-27ed-5a4c-88ec-257ff9d35fcd', 'sodium', 529),  -- Sódio
  ('aba23a32-27ed-5a4c-88ec-257ff9d35fcd', 'calories', 507)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
