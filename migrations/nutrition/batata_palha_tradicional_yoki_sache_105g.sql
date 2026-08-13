-- Batata Palha Tradicional Yoki Sachê 105g
-- Marca: Yoki
-- Codigo: 1253154
-- Fonte: https://www.extramercado.com.br/produto/517252/batata-palha-tradicional-yoki-sache-105g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 25 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('38a41000-8c47-548b-ac57-220bfc1c7bf4', null, 'Batata Palha Tradicional Yoki Sachê 105g', 'Yoki', 25, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('38a41000-8c47-548b-ac57-220bfc1c7bf4', 'addedSugar', 0),  -- Açúcares Adicionados
  ('38a41000-8c47-548b-ac57-220bfc1c7bf4', 'sugar', 2.4),  -- Açúcares Totais
  ('38a41000-8c47-548b-ac57-220bfc1c7bf4', 'carbohydrates', 44),  -- Carboidratos
  ('38a41000-8c47-548b-ac57-220bfc1c7bf4', 'fiber', 3.6),  -- Fibra Alimentar
  ('38a41000-8c47-548b-ac57-220bfc1c7bf4', 'saturatedFat', 17),  -- Gorduras Saturadas
  ('38a41000-8c47-548b-ac57-220bfc1c7bf4', 'fat', 40),  -- Gorduras Totais
  ('38a41000-8c47-548b-ac57-220bfc1c7bf4', 'transFat', 0.4),  -- Gorduras Trans
  ('38a41000-8c47-548b-ac57-220bfc1c7bf4', 'protein', 5.4),  -- Proteínas
  ('38a41000-8c47-548b-ac57-220bfc1c7bf4', 'sodium', 215),  -- Sódio
  ('38a41000-8c47-548b-ac57-220bfc1c7bf4', 'calories', 558)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
