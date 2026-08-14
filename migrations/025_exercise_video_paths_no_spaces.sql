-- video_player's Android backend (ExoPlayer's AssetDataSource) fails to
-- open bundled asset videos whose path contains spaces
-- (FileNotFoundException even though the file is present in
-- flutter_assets). The fix is to avoid spaces in video asset filenames;
-- assets/exercises/*.mp4 were renamed accordingly (spaces -> underscores),
-- so the already-seeded rows from migration 024 need their video_path
-- updated to match.
update public.exercises
set video_path = replace(video_path, ' ', '_')
where video_path like 'assets/exercises/%';
