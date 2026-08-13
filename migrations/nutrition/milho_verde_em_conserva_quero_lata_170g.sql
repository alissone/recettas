-- Milho Verde em Conserva Quero Lata 170g
-- Marca: Quero
-- Codigo: 1208421
-- Fonte: https://www.extramercado.com.br/produto/462595/milho-verde-em-conserva-quero-lata-170g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 170 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('5a886fbf-bf0f-5c8b-b43c-f1bad9043969', null, 'Milho Verde em Conserva Quero Lata 170g', 'Quero', 170, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('5a886fbf-bf0f-5c8b-b43c-f1bad9043969', 'addedSugar', 0),  -- Açúcares Adicionados
  ('5a886fbf-bf0f-5c8b-b43c-f1bad9043969', 'sugar', 4),  -- Açúcares Totais
  ('5a886fbf-bf0f-5c8b-b43c-f1bad9043969', 'carbohydrates', 14),  -- Carboidratos
  ('5a886fbf-bf0f-5c8b-b43c-f1bad9043969', 'fiber', 3.5),  -- Fibra Alimentar
  ('5a886fbf-bf0f-5c8b-b43c-f1bad9043969', 'saturatedFat', 0.4),  -- Gorduras Saturadas
  ('5a886fbf-bf0f-5c8b-b43c-f1bad9043969', 'fat', 1.6),  -- Gorduras Totais
  ('5a886fbf-bf0f-5c8b-b43c-f1bad9043969', 'transFat', 0),  -- Gorduras Trans
  ('5a886fbf-bf0f-5c8b-b43c-f1bad9043969', 'protein', 3.4),  -- Proteínas
  ('5a886fbf-bf0f-5c8b-b43c-f1bad9043969', 'sodium', 115),  -- Sódio
  ('5a886fbf-bf0f-5c8b-b43c-f1bad9043969', 'calories', 91)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
