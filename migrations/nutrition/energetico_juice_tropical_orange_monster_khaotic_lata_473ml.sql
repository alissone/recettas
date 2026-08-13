-- Energético Juice Tropical Orange Monster Khaotic Lata 473ml
-- Marca: Monster
-- Codigo: 1368585
-- Fonte: https://www.extramercado.com.br/produto/1634608/energetico-juice-tropical-orange-monster-khaotic-lata-473ml
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 200 ml. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.
--
-- Nutrientes da embalagem sem correspondencia no catalogo,
-- portanto NAO importados:
--   Inositol
--   Taurina

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('0d55b1ae-5a6b-5a21-97f0-e820999684b2', null, 'Energético Juice Tropical Orange Monster Khaotic Lata 473ml', 'Monster', 200, 'ml')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('0d55b1ae-5a6b-5a21-97f0-e820999684b2', 'addedSugar', 14),  -- Açúcares Adicionados
  ('0d55b1ae-5a6b-5a21-97f0-e820999684b2', 'sugar', 14),  -- Açúcares Totais
  ('0d55b1ae-5a6b-5a21-97f0-e820999684b2', 'caffeine', 66),  -- Cafeína
  ('0d55b1ae-5a6b-5a21-97f0-e820999684b2', 'carbohydrates', 15),  -- Carboidratos
  ('0d55b1ae-5a6b-5a21-97f0-e820999684b2', 'sodium', 68),  -- Sódio
  ('0d55b1ae-5a6b-5a21-97f0-e820999684b2', 'calories', 60),  -- Valor energético
  ('0d55b1ae-5a6b-5a21-97f0-e820999684b2', 'vitaminB12', 2.4),  -- Vitamina B12
  ('0d55b1ae-5a6b-5a21-97f0-e820999684b2', 'vitaminB2', 1.2),  -- Vitamina B2
  ('0d55b1ae-5a6b-5a21-97f0-e820999684b2', 'vitaminB3', 15),  -- Vitamina B3
  ('0d55b1ae-5a6b-5a21-97f0-e820999684b2', 'vitaminB6', 1.3)  -- Vitamina B6
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
