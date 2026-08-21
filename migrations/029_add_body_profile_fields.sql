-- Intake fields for a future RMR/TDEE estimate. Nothing reads these yet -
-- this migration only makes room for the full-screen form on Profile to
-- save them; height_cm and weight_kg already exist from migration 027 and
-- are reused rather than duplicated.
alter table public.profiles
  add column sex text check (sex in ('male', 'female')),
  add column age integer,
  add column goal text check (goal in ('maintain', 'lose', 'gain')),
  add column goal_rate text check (goal_rate in ('slow', 'moderate', 'fast')),
  add column weightlifting_days_per_week integer,
  add column weightlifting_minutes_per_session integer,
  add column cardio_days_per_week integer,
  add column cardio_type text,
  add column cardio_minutes_per_session integer,
  add column average_daily_steps integer,
  add column occupation_activity text
    check (occupation_activity in ('sedentary', 'standing', 'physical')),
  add column body_fat_percent numeric,
  add column cardio_intensity text
    check (cardio_intensity in ('easy', 'moderate', 'hard')),
  add column cardio_heart_rate integer,
  add column lifting_intensity text
    check (lifting_intensity in ('light', 'moderate', 'hard'));
