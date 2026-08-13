-- Biscoito Recheio Chocolate Vitarella Nikito Pacote 120g
-- Marca: Vitarella
-- Codigo: 1387527
-- Fonte: https://www.extramercado.com.br/produto/1656524/biscoito-recheio-chocolate-vitarella-nikito-pacote-120g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 30 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('7859002a-7720-5759-b1fa-fc76a2ddf0a1', null, 'Biscoito Recheio Chocolate Vitarella Nikito Pacote 120g', 'Vitarella', 30, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('7859002a-7720-5759-b1fa-fc76a2ddf0a1', 'carbohydrates', 20),  -- Carboidratos
  ('7859002a-7720-5759-b1fa-fc76a2ddf0a1', 'fiber', 0.6),  -- Fibra Alimentar
  ('7859002a-7720-5759-b1fa-fc76a2ddf0a1', 'saturatedFat', 2.4),  -- Gorduras Saturadas
  ('7859002a-7720-5759-b1fa-fc76a2ddf0a1', 'fat', 5),  -- Gorduras Totais
  ('7859002a-7720-5759-b1fa-fc76a2ddf0a1', 'transFat', 0),  -- Gorduras Trans
  ('7859002a-7720-5759-b1fa-fc76a2ddf0a1', 'protein', 1.9),  -- Proteínas
  ('7859002a-7720-5759-b1fa-fc76a2ddf0a1', 'sodium', 80),  -- Sódio
  ('7859002a-7720-5759-b1fa-fc76a2ddf0a1', 'calories', 133)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
