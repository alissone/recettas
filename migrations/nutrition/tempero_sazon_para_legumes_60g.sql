-- Tempero SAZÓN® para Legumes 60g
-- Marca: Sazon
-- Codigo: 0125604
-- Fonte: https://www.extramercado.com.br/produto/134547/tempero-sazon%C2%AE%C2%A0para-legumes-60g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 5 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('89fb2ce8-c739-5caf-b1ab-226ff572aaff', null, 'Tempero SAZÓN® para Legumes 60g', 'Sazon', 5, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('89fb2ce8-c739-5caf-b1ab-226ff572aaff', 'addedSugar', 0.1),  -- Açúcares Adicionados
  ('89fb2ce8-c739-5caf-b1ab-226ff572aaff', 'sugar', 0.9),  -- Açúcares Totais
  ('89fb2ce8-c739-5caf-b1ab-226ff572aaff', 'carbohydrates', 5),  -- Carboidratos
  ('89fb2ce8-c739-5caf-b1ab-226ff572aaff', 'fiber', 1.3),  -- Fibra Alimentar
  ('89fb2ce8-c739-5caf-b1ab-226ff572aaff', 'saturatedFat', 0.2),  -- Gorduras Saturadas
  ('89fb2ce8-c739-5caf-b1ab-226ff572aaff', 'fat', 0),  -- Gorduras Totais
  ('89fb2ce8-c739-5caf-b1ab-226ff572aaff', 'protein', 0.9),  -- Proteínas
  ('89fb2ce8-c739-5caf-b1ab-226ff572aaff', 'sodium', 985),  -- Sódio
  ('89fb2ce8-c739-5caf-b1ab-226ff572aaff', 'calories', 220)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
