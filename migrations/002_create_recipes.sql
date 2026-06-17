-- Create recipes table
create table public.recipes (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  image text,
  prep_time text,
  total_time text,
  sections jsonb not null default '[]'::jsonb,
  created_at timestamptz default now()
);

alter table public.recipes enable row level security;

create policy "Recipes are viewable by everyone"
  on public.recipes for select
  using (true);

-- Seed with the Cold Proof Artisan Bread recipe
insert into public.recipes (name, image, prep_time, total_time, sections)
values (
  'Cold Proof Artisan Bread',
  'https://images.unsplash.com/photo-1509440159596-0249088772ff?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1000&q=80',
  '30 min',
  '24 hours',
  '[
    {
      "title": "Ingredients",
      "items": [
        "500g bread flour (strong white flour)",
        "350mL warm water",
        "10g salt",
        "3g active dry yeast",
        "15mL olive oil",
        "5g sugar"
      ]
    },
    {
      "title": "Mixing Instructions",
      "items": [
        "In a large bowl, dissolve the yeast and sugar in warm water. Let it sit for 5 minutes until foamy.",
        "Add the flour and salt to the yeast mixture.",
        "Mix with a wooden spoon or your hands until a shaggy dough forms.",
        "Drizzle olive oil over the dough and mix until incorporated.",
        "The dough will be sticky and rough - this is normal for no-knead bread.",
        "Cover the bowl with plastic wrap or a damp towel."
      ]
    },
    {
      "title": "Before Refrigerating",
      "items": [
        "Let the dough rest at room temperature for 2 hours.",
        "During this time, the dough should roughly double in size.",
        "If your kitchen is cold, it might take up to 3 hours.",
        "Gently deflate the dough by folding it over itself a few times.",
        "Shape it into a rough ball and place it in an oiled bowl.",
        "Cover tightly with plastic wrap, ensuring no air can get in."
      ]
    },
    {
      "title": "After Refrigerating",
      "items": [
        "Remove the dough from the fridge after 12-72 hours of cold fermentation.",
        "Let it come to room temperature for 1-2 hours.",
        "Turn the dough onto a floured surface.",
        "Gently shape it into a round boule or oval batard.",
        "Place on parchment paper and cover with a kitchen towel.",
        "Let it rise for 45-60 minutes until it springs back slowly when poked.",
        "Preheat your oven to 450°F (230°C) with a Dutch oven inside."
      ]
    },
    {
      "title": "Baking Instructions",
      "items": [
        "Carefully remove the hot Dutch oven from the oven.",
        "Score the top of the dough with a sharp knife or razor blade.",
        "Lift the dough using the parchment paper and lower it into the Dutch oven.",
        "Cover with the lid and bake for 30 minutes.",
        "Remove the lid and bake for another 15-20 minutes until golden brown.",
        "The internal temperature should reach 200°F (93°C).",
        "Cool on a wire rack for at least 1 hour before slicing."
      ]
    }
  ]'::jsonb
);
