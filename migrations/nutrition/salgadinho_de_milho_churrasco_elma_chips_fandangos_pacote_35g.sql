-- Salgadinho de Milho Churrasco Elma Chips Fandangos Pacote 35g
-- Marca: Fandangos
-- Codigo: 1393186
-- Fonte: https://www.extramercado.com.br/produto/1657389/salgadinho-de-milho-churrasco-elma-chips-fandangos-pacote-35g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 35 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('812e6583-0a08-508c-aff7-9540d501c1d6', null, 'Salgadinho de Milho Churrasco Elma Chips Fandangos Pacote 35g', 'Fandangos', 35, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('812e6583-0a08-508c-aff7-9540d501c1d6', 'addedSugar', 0),  -- Açúcares Adicionados
  ('812e6583-0a08-508c-aff7-9540d501c1d6', 'sugar', 0.1),  -- Açúcares Totais
  ('812e6583-0a08-508c-aff7-9540d501c1d6', 'carbohydrates', 56),  -- Carboidratos
  ('812e6583-0a08-508c-aff7-9540d501c1d6', 'fiber', 3.1),  -- Fibra Alimentar
  ('812e6583-0a08-508c-aff7-9540d501c1d6', 'saturatedFat', 3.3),  -- Gorduras Saturadas
  ('812e6583-0a08-508c-aff7-9540d501c1d6', 'fat', 19),  -- Gorduras Totais
  ('812e6583-0a08-508c-aff7-9540d501c1d6', 'transFat', 0.3),  -- Gorduras Trans
  ('812e6583-0a08-508c-aff7-9540d501c1d6', 'protein', 6.5),  -- Proteínas
  ('812e6583-0a08-508c-aff7-9540d501c1d6', 'sodium', 277),  -- Sódio
  ('812e6583-0a08-508c-aff7-9540d501c1d6', 'calories', 423)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
