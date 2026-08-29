-- Seeds three "casa de sucos" style recipes: guaraná da Amazônia com
-- maracujá, uma porção de batata frita com queijo e bacon, e guaraná da
-- Amazônia com açaí. Ingredient nutrition for anything not already in
-- public.foods lives in migrations/nutrition/ (xarope_de_guarana,
-- farinha_de_castanha_de_caju, farinha_de_amendoim, maracuja_polpa,
-- guarana_po, gelo, abacate_cru, acai_polpa_congelada, bacon_frito) -
-- apply those first.
--
-- Recipe ids are explicit (not gen_random_uuid()) so this file can
-- insert the matching recipe_ingredients rows and is safe to re-run.

insert into public.recipes (id, user_id, name, prep_time, total_time, yield_amount, sections)
values (
  '1ffba6bb-cdd5-4d91-8b37-6fd55fa02540',
  null,
  'Guaraná da Amazônia com Maracujá',
  '10 min',
  '10 min',
  300,
  '[
    {
      "title": "Ingredientes (1 copo de 300 ml)",
      "items": [
        "50 ml de xarope de guaraná",
        "2 colheres (sopa) de leite em pó",
        "2 colheres (sopa) de farinha de castanha-de-caju",
        "2 colheres (sopa) de farinha de amendoim (ou amendoim torrado triturado)",
        "Polpa de meio maracujá pequeno (ou 2 colheres de sopa de suco concentrado de maracujá)",
        "1 pitada de guaraná em pó (opcional, para mais energia)",
        "Gelo picado (o suficiente para preencher o restante do copo e dar ponto cremoso)",
        "Um pedaço pequeno de abacate (opcional, ajuda a dar cremosidade)"
      ]
    },
    {
      "title": "Modo de preparo",
      "items": [
        "Coloque no liquidificador o xarope de guaraná, o leite em pó, a farinha de castanha-de-caju e a farinha de amendoim.",
        "Adicione a polpa de maracujá, o guaraná em pó e o pedaço de abacate.",
        "Complete com gelo picado até quase o topo do copo.",
        "Bata em velocidade alta até ficar cremoso e homogêneo.",
        "Sirva imediatamente em um copo de 300 ml."
      ]
    }
  ]'::jsonb
)
on conflict (id) do update set
  name = excluded.name,
  prep_time = excluded.prep_time,
  total_time = excluded.total_time,
  yield_amount = excluded.yield_amount,
  sections = excluded.sections;

insert into public.recipe_ingredients (recipe_id, food_id, amount, sort_order)
values
  ('1ffba6bb-cdd5-4d91-8b37-6fd55fa02540', '50fdd582-dc87-5a52-be6d-df8b7ab3df3a', 50, 10),  -- Xarope de guaraná
  ('1ffba6bb-cdd5-4d91-8b37-6fd55fa02540', 'd0bc31cb-510f-5aeb-8be5-7922e4e9413b', 20, 20),  -- Leite em pó
  ('1ffba6bb-cdd5-4d91-8b37-6fd55fa02540', '232e4f81-56ca-5930-beb0-2295c1e52454', 20, 30),  -- Farinha de castanha-de-caju
  ('1ffba6bb-cdd5-4d91-8b37-6fd55fa02540', 'e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 20, 40),  -- Farinha de amendoim
  ('1ffba6bb-cdd5-4d91-8b37-6fd55fa02540', '0f0b2258-f594-5cdd-9903-b7ef90519f55', 20, 50),  -- Maracujá, polpa
  ('1ffba6bb-cdd5-4d91-8b37-6fd55fa02540', '9aa437f1-22f5-59c5-a889-e0e16b73db7a', 1, 60),  -- Guaraná, pó
  ('1ffba6bb-cdd5-4d91-8b37-6fd55fa02540', '5cdb0f4b-630e-58c3-9368-d2c9c7af6c42', 130, 70),  -- Gelo
  ('1ffba6bb-cdd5-4d91-8b37-6fd55fa02540', 'a5672928-3175-556c-8336-27ccc342f6a4', 15, 80)  -- Abacate, cru
on conflict (recipe_id, food_id) do update set
  amount = excluded.amount,
  sort_order = excluded.sort_order;

insert into public.recipes (id, user_id, name, prep_time, total_time, sections)
values (
  '1670ea9c-c0ee-4444-91f1-298a7ee4d832',
  null,
  'Porção de Batata Frita com Queijo e Bacon',
  '10 min',
  '25 min',
  '[
    {
      "title": "Ingredientes (porção para 2 pessoas)",
      "items": [
        "400 g de batata frita",
        "80 g de queijo cheddar ralado ou fatiado",
        "50 g de bacon frito em cubinhos"
      ]
    },
    {
      "title": "Modo de preparo",
      "items": [
        "Frite ou asse as batatas até ficarem douradas e crocantes.",
        "Frite o bacon em cubinhos até dourar e escorra em papel toalha.",
        "Distribua as batatas em um prato ou travessa.",
        "Cubra com o queijo cheddar e leve ao forno ou micro-ondas por alguns minutos até derreter.",
        "Finalize espalhando o bacon frito por cima e sirva quente."
      ]
    }
  ]'::jsonb
)
on conflict (id) do update set
  name = excluded.name,
  prep_time = excluded.prep_time,
  total_time = excluded.total_time,
  sections = excluded.sections;

insert into public.recipe_ingredients (recipe_id, food_id, amount, sort_order)
values
  ('1670ea9c-c0ee-4444-91f1-298a7ee4d832', '45816689-2854-5764-a6f3-6ce56d4ca112', 400, 10),  -- Prato rapido, batata, batata frita em oleo vegetal
  ('1670ea9c-c0ee-4444-91f1-298a7ee4d832', '0fabc870-8b1c-5120-842a-f58572a3d871', 80, 20),  -- Queijo, cheddar
  ('1670ea9c-c0ee-4444-91f1-298a7ee4d832', '36d0e6da-2f52-595f-bb74-44b913756669', 50, 30)  -- Bacon, frito
on conflict (recipe_id, food_id) do update set
  amount = excluded.amount,
  sort_order = excluded.sort_order;

insert into public.recipes (id, user_id, name, prep_time, total_time, yield_amount, sections)
values (
  '52bb24a4-4e79-4cf2-9b7c-8e9134344061',
  null,
  'Guaraná da Amazônia com Açaí',
  '10 min',
  '10 min',
  300,
  '[
    {
      "title": "Ingredientes (1 copo de 300 ml)",
      "items": [
        "50 ml de xarope de guaraná",
        "2 colheres (sopa) de leite em pó",
        "2 colheres (sopa) de farinha de castanha-de-caju",
        "2 colheres (sopa) de farinha de amendoim (ou amendoim torrado triturado)",
        "100 g de polpa de açaí congelada",
        "1 pitada de guaraná em pó (opcional, para mais energia)",
        "Gelo picado (o suficiente para dar ponto cremoso)"
      ]
    },
    {
      "title": "Modo de preparo",
      "items": [
        "Coloque no liquidificador o xarope de guaraná, o leite em pó, a farinha de castanha-de-caju e a farinha de amendoim.",
        "Adicione a polpa de açaí e o guaraná em pó.",
        "Complete com gelo picado até quase o topo do copo.",
        "Bata em velocidade alta até ficar cremoso e homogêneo.",
        "Sirva imediatamente em um copo de 300 ml."
      ]
    }
  ]'::jsonb
)
on conflict (id) do update set
  name = excluded.name,
  prep_time = excluded.prep_time,
  total_time = excluded.total_time,
  yield_amount = excluded.yield_amount,
  sections = excluded.sections;

insert into public.recipe_ingredients (recipe_id, food_id, amount, sort_order)
values
  ('52bb24a4-4e79-4cf2-9b7c-8e9134344061', '50fdd582-dc87-5a52-be6d-df8b7ab3df3a', 50, 10),  -- Xarope de guaraná
  ('52bb24a4-4e79-4cf2-9b7c-8e9134344061', 'd0bc31cb-510f-5aeb-8be5-7922e4e9413b', 20, 20),  -- Leite em pó
  ('52bb24a4-4e79-4cf2-9b7c-8e9134344061', '232e4f81-56ca-5930-beb0-2295c1e52454', 20, 30),  -- Farinha de castanha-de-caju
  ('52bb24a4-4e79-4cf2-9b7c-8e9134344061', 'e9d05906-9ec9-56f4-b9fb-95ce01d491b5', 20, 40),  -- Farinha de amendoim
  ('52bb24a4-4e79-4cf2-9b7c-8e9134344061', '600dbcc1-1225-5f04-afdc-8d883f5cb9c6', 100, 50),  -- Açaí, polpa, congelada
  ('52bb24a4-4e79-4cf2-9b7c-8e9134344061', '9aa437f1-22f5-59c5-a889-e0e16b73db7a', 1, 60),  -- Guaraná, pó
  ('52bb24a4-4e79-4cf2-9b7c-8e9134344061', '5cdb0f4b-630e-58c3-9368-d2c9c7af6c42', 90, 70)  -- Gelo
on conflict (recipe_id, food_id) do update set
  amount = excluded.amount,
  sort_order = excluded.sort_order;
