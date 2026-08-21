-- Salgadinho de Trigo Cebola Torcida Pacote 35g
-- Marca: Torcida
-- Codigo: 1388667
-- Fonte: https://www.extramercado.com.br/produto/1654545/salgadinho-de-trigo-cebola-torcida-pacote-35g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 35 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('f3baae70-01e9-592b-a6e2-f84a1f59bacc', null, 'Salgadinho de Trigo Cebola Torcida Pacote 35g', 'Torcida', 35, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('f3baae70-01e9-592b-a6e2-f84a1f59bacc', 'addedSugar', 1.4),  -- Açúcares Adicionados
  ('f3baae70-01e9-592b-a6e2-f84a1f59bacc', 'carbohydrates', 51),  -- Carboidratos
  ('f3baae70-01e9-592b-a6e2-f84a1f59bacc', 'fiber', 1.7),  -- Fibra Alimentar
  ('f3baae70-01e9-592b-a6e2-f84a1f59bacc', 'protein', 9.5),  -- Proteínas
  ('f3baae70-01e9-592b-a6e2-f84a1f59bacc', 'calories', 567)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
