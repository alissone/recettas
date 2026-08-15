#!/usr/bin/env bash
# Extracts a still "poster" frame from every assets/exercises/*.mp4 into
# assets/exercise_posters/<same name>.jpg. The gym gallery shows those
# posters on every card and only plays the video under your finger, so a
# video without a poster shows a blank placeholder icon instead.
#
# Run after dropping new videos into assets/exercises/. Existing posters
# are skipped unless --force is passed.
#
#   ./scripts/generate_exercise_posters.sh
#   ./scripts/generate_exercise_posters.sh --force
#   FFMPEG="C:/dev/ffmpeg.exe" ./scripts/generate_exercise_posters.sh
#
# Videos whose filenames contain spaces break video_player on Android
# (ExoPlayer's AssetDataSource throws FileNotFoundException), so this
# also renames any new video to use underscores before extracting. If it
# renames anything, update the matching exercises.video_path rows in
# Supabase - see migrations/025_exercise_video_paths_no_spaces.sql.

set -euo pipefail

force=0
if [ "${1:-}" = "--force" ]; then
  force=1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
video_dir="$repo_root/assets/exercises"
poster_dir="$repo_root/assets/exercise_posters"

# Prefer $FFMPEG, then this machine's known install, then PATH.
if [ -n "${FFMPEG:-}" ]; then
  ffmpeg_bin="$FFMPEG"
elif [ -x "C:/dev/ffmpeg.exe" ]; then
  ffmpeg_bin="C:/dev/ffmpeg.exe"
elif command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg_bin="ffmpeg"
else
  echo "ffmpeg not found. Set FFMPEG=<path> or add it to PATH." >&2
  exit 1
fi

if [ ! -d "$video_dir" ]; then
  echo "Video directory not found: $video_dir" >&2
  exit 1
fi
mkdir -p "$poster_dir"

# Spaces in asset filenames break playback on Android - rename first.
renamed=0
for video in "$video_dir"/*.mp4; do
  [ -e "$video" ] || continue
  name="$(basename "$video")"
  case "$name" in
    *\ *)
      clean="${name// /_}"
      if [ -e "$video_dir/$clean" ]; then
        echo "SKIP rename (target exists): $name"
      else
        mv -- "$video" "$video_dir/$clean"
        echo "RENAMED $name -> $clean"
        renamed=$((renamed + 1))
      fi
      ;;
  esac
done

made=0
skipped=0
failed=0

for video in "$video_dir"/*.mp4; do
  [ -e "$video" ] || continue
  base="$(basename "$video" .mp4)"
  poster="$poster_dir/$base.jpg"

  if [ -s "$poster" ] && [ "$force" -eq 0 ]; then
    skipped=$((skipped + 1))
    continue
  fi

  # "thumbnail" picks a representative frame rather than frame 0, which
  # in these clips is often a near-black fade-in.
  if "$ffmpeg_bin" -nostdin -loglevel error -y -i "$video" \
      -vf "thumbnail,scale=480:-2" -frames:v 1 -q:v 4 "$poster" 2>/dev/null \
      && [ -s "$poster" ]; then
    echo "OK   $base"
    made=$((made + 1))
  else
    echo "FAIL $base"
    failed=$((failed + 1))
  fi
done

echo
echo "Posters generated: $made, skipped: $skipped, failed: $failed, videos renamed: $renamed"
if [ "$renamed" -gt 0 ]; then
  echo "Renamed videos: update exercises.video_path in Supabase to match."
fi
[ "$failed" -eq 0 ]
