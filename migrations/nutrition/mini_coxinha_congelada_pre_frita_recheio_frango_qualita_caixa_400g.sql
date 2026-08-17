-- Mini Coxinha Congelada Pré-Frita Recheio Frango Qualitá Caixa 400g
-- Marca: Qualitá
-- Codigo: 1282529
-- Fonte: https://www.extramercado.com.br/produto/742015/mini-coxinha-congelada-pre-frita-recheio-frango-qualita-caixa-400g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 40 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('10058e99-e713-5a65-a612-99bbef253dbd', null, 'Mini Coxinha Congelada Pré-Frita Recheio Frango Qualitá Caixa 400g', 'Qualitá', 40, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('10058e99-e713-5a65-a612-99bbef253dbd', 'carbohydrates', 9.6),  -- Carboidratos
  ('10058e99-e713-5a65-a612-99bbef253dbd', 'fiber', 2),  -- Fibra Alimentar
  ('10058e99-e713-5a65-a612-99bbef253dbd', 'saturatedFat', 1),  -- Gorduras Saturadas
  ('10058e99-e713-5a65-a612-99bbef253dbd', 'fat', 4.8),  -- Gorduras Totais
  ('10058e99-e713-5a65-a612-99bbef253dbd', 'transFat', 0),  -- Gorduras Trans
  ('10058e99-e713-5a65-a612-99bbef253dbd', 'protein', 4),  -- Proteínas
  ('10058e99-e713-5a65-a612-99bbef253dbd', 'sodium', 254),  -- Sódio
  ('10058e99-e713-5a65-a612-99bbef253dbd', 'calories', 98)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
