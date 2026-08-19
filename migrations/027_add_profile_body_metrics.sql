-- Height and weight, entered once in the Profile screen, feed the weight
-- and BMI projections on the Nutrition screen's calorie trend.
alter table public.profiles
  add column height_cm numeric,
  add column weight_kg numeric;
