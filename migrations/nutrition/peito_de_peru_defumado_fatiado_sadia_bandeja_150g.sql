-- Peito De Peru Defumado Fatiado Sadia Bandeja 150g
-- Marca: Sadia
-- Codigo: 0024297
-- Fonte: https://www.extramercado.com.br/produto/102519/peito-de-peru-defumado-fatiado-sadia-bandeja-150g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 60 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.
--
-- Nutrientes da embalagem sem correspondencia no catalogo,
-- portanto NAO importados:
--   Gordura Trans
--   Valor calórico

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('f19657e8-de30-5cab-96bf-b8750e8bc8d4', null, 'Peito De Peru Defumado Fatiado Sadia Bandeja 150g', 'Sadia', 60, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('f19657e8-de30-5cab-96bf-b8750e8bc8d4', 'sodium', 523000),  -- Sódio
  ('f19657e8-de30-5cab-96bf-b8750e8bc8d4', 'cholesterol', 15),  -- Colesterol
  ('f19657e8-de30-5cab-96bf-b8750e8bc8d4', 'saturatedFat', 0.2),  -- Gorduras saturadas
  ('f19657e8-de30-5cab-96bf-b8750e8bc8d4', 'carbohydrates', 0),  -- Carboidratos
  ('f19657e8-de30-5cab-96bf-b8750e8bc8d4', 'protein', 11),  -- Proteínas
  ('f19657e8-de30-5cab-96bf-b8750e8bc8d4', 'fiber', 0),  -- Fibra alimentar
  ('f19657e8-de30-5cab-96bf-b8750e8bc8d4', 'fat', 0.8)  -- Gorduras totais
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
