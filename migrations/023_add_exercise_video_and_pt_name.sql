-- Video-backed exercises: assets/exercises/*.mp4 are bundled with the app
-- itself (a Flutter asset), unlike image_path which is an object key in
-- the Supabase "habits" storage bucket. video_path is therefore a plain
-- relative asset path, not a signed-URL target.
--
-- name_pt is the Portuguese display name shown first in the gym gallery;
-- name keeps the English MuscleWiki name shown underneath it.
alter table public.exercises
  add column name_pt text,
  add column video_path text;
