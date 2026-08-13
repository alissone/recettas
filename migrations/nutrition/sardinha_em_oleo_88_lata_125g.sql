-- Sardinha Em Oléo 88 Lata 125g
-- Marca: 88
-- Codigo: 3487372
-- Fonte: https://www.extramercado.com.br/produto/45185/sardinha-em-oleo-88-lata-125g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 60 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('b06f21f5-101d-50ca-9eb8-f450143802c9', null, 'Sardinha Em Oléo 88 Lata 125g', '88', 60, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'calcium', 221),  -- Cálcio
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'carbohydrates', 0),  -- Carboidratos
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'cholesterol', 70),  -- Colesterol
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'dha', 0.357),  -- DHA
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'epa', 0.463),  -- EPA
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'fiber', 0),  -- Fibra Alimentar
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'monounsaturatedFat', 1.9),  -- Gorduras Monoinsaturadas
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'polyunsaturatedFat', 3.3),  -- Gorduras Poliinsaturadas
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'saturatedFat', 1.3),  -- Gorduras Saturadas
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'fat', 6.5),  -- Gorduras Totais
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'transFat', 0),  -- Gorduras Trans
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'omega3', 1.101),  -- Omega 3
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'protein', 14),  -- Proteínas
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'sodium', 330),  -- Sódio
  ('b06f21f5-101d-50ca-9eb8-f450143802c9', 'calories', 114)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
