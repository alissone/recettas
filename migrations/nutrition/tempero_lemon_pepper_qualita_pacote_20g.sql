-- Tempero Lemon Pepper Qualitá Pacote 20g
-- Marca: Qualitá
-- Codigo: 1150737
-- Fonte: https://www.extramercado.com.br/produto/407943/tempero-lemon-pepper-qualita-pacote-20g
-- Gerado por scripts/product_page_to_sql.py - nao editar a mao.
--
-- Valores por 5 g. O id vem de um
-- uuid5 do nome, entao reaplicar este arquivo atualiza a mesma linha
-- em vez de duplicar o alimento.

insert into public.foods (id, user_id, name, brand, base_amount, base_unit)
values ('3a0bc286-3744-53bb-8d92-d96d5068d1a6', null, 'Tempero Lemon Pepper Qualitá Pacote 20g', 'Qualitá', 5, 'g')
on conflict (id) do update set
  name = excluded.name,
  brand = excluded.brand,
  base_amount = excluded.base_amount,
  base_unit = excluded.base_unit;

insert into public.food_nutrients (food_id, nutrient_id, amount)
values
  ('3a0bc286-3744-53bb-8d92-d96d5068d1a6', 'carbohydrates', 220),  -- Carboidratos
  ('3a0bc286-3744-53bb-8d92-d96d5068d1a6', 'fiber', 0),  -- Fibra Alimentar
  ('3a0bc286-3744-53bb-8d92-d96d5068d1a6', 'saturatedFat', 0),  -- Gorduras Saturadas
  ('3a0bc286-3744-53bb-8d92-d96d5068d1a6', 'fat', 0),  -- Gorduras Totais
  ('3a0bc286-3744-53bb-8d92-d96d5068d1a6', 'transFat', 0),  -- Gorduras Trans
  ('3a0bc286-3744-53bb-8d92-d96d5068d1a6', 'protein', 0),  -- Proteínas
  ('3a0bc286-3744-53bb-8d92-d96d5068d1a6', 'sodium', 673),  -- Sódio
  ('3a0bc286-3744-53bb-8d92-d96d5068d1a6', 'calories', 120)  -- Valor energético
on conflict (food_id, nutrient_id) do update set
  amount = excluded.amount;
