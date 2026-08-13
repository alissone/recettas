-- Macarrão com Ovos Penne Rigate Barilla Pacote 500g
-- Marca: Barilla
-- Codigo: 1022954
-- Fonte: https://www.extramercado.com.br/produto/305743/macarrao-com-ovos-penne-rigate-barilla-pacote-500g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 80 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('b339adcc-404c-580d-8473-84e45f5fd948', null, 'Macarrão com Ovos Penne Rigate Barilla Pacote 500g', 'Barilla', 80, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('b339adcc-404c-580d-8473-84e45f5fd948', 'addedSugar', 0),  -- Açúcares Adicionados
  ('b339adcc-404c-580d-8473-84e45f5fd948', 'sugar', 3.1),  -- Açúcares Totais
  ('b339adcc-404c-580d-8473-84e45f5fd948', 'carbohydrates', 73),  -- Carboidratos
  ('b339adcc-404c-580d-8473-84e45f5fd948', 'fiber', 2.1),  -- Fibra Alimentar
  ('b339adcc-404c-580d-8473-84e45f5fd948', 'saturatedFat', 0.4),  -- Gorduras Saturadas
  ('b339adcc-404c-580d-8473-84e45f5fd948', 'fat', 1.6),  -- Gorduras Totais
  ('b339adcc-404c-580d-8473-84e45f5fd948', 'transFat', 0),  -- Gorduras Trans
  ('b339adcc-404c-580d-8473-84e45f5fd948', 'protein', 12),  -- Proteínas
  ('b339adcc-404c-580d-8473-84e45f5fd948', 'sodium', 0),  -- Sódio
  ('b339adcc-404c-580d-8473-84e45f5fd948', 'calories', 354)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
