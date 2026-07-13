-- Adds a category label to accelerometer recordings so bursts can be
-- tagged as fall / no-fall training data.
alter table public.accel_recordings
  add column category text not null default 'no_fall'
  check (category in ('no_fall', 'phone_fall', 'user_fall'));
