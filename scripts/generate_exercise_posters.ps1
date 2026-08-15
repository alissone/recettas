# Extracts a still "poster" frame from every assets/exercises/*.mp4 into
# assets/exercise_posters/<same name>.jpg. The gym gallery shows those
# posters on every card and only plays the video under your finger, so a
# video without a poster shows a blank placeholder icon instead.
#
# Run after dropping new videos into assets/exercises/. Existing posters
# are skipped unless -Force is passed.
#
#   powershell -ExecutionPolicy Bypass -File scripts\generate_exercise_posters.ps1
#   ... -Force                 regenerate posters that already exist
#   ... -FFmpeg "C:\dev\ffmpeg.exe"
#
# Videos whose filenames contain spaces break video_player on Android
# (ExoPlayer's AssetDataSource throws FileNotFoundException), so this
# also renames any new video to use underscores before extracting. If it
# renames anything, update the matching exercises.video_path rows in
# Supabase - see migrations/025_exercise_video_paths_no_spaces.sql.

param(
    [switch]$Force,
    [string]$FFmpeg = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$videoDir = Join-Path $repoRoot "assets\exercises"
$posterDir = Join-Path $repoRoot "assets\exercise_posters"

# Prefer an explicit -FFmpeg, then this machine's known install, then PATH.
if ($FFmpeg -eq "") {
    if (Test-Path "C:\dev\ffmpeg.exe") {
        $FFmpeg = "C:\dev\ffmpeg.exe"
    } else {
        $onPath = Get-Command ffmpeg -ErrorAction SilentlyContinue
        if ($null -eq $onPath) {
            Write-Error "ffmpeg not found. Pass -FFmpeg <path> or add it to PATH."
        }
        $FFmpeg = $onPath.Source
    }
}

if (-not (Test-Path $videoDir)) {
    Write-Error "Video directory not found: $videoDir"
}
if (-not (Test-Path $posterDir)) {
    New-Item -ItemType Directory -Path $posterDir | Out-Null
}

# Spaces in asset filenames break playback on Android - rename first.
$renamed = 0
foreach ($video in Get-ChildItem -Path $videoDir -Filter *.mp4) {
    if ($video.Name -match " ") {
        $clean = $video.Name -replace " ", "_"
        $target = Join-Path $videoDir $clean
        if (Test-Path $target) {
            Write-Host "SKIP rename (target exists): $($video.Name)"
        } else {
            Rename-Item -Path $video.FullName -NewName $clean
            Write-Host "RENAMED $($video.Name) -> $clean"
            $renamed++
        }
    }
}

$made = 0
$skipped = 0
$failed = 0

foreach ($video in Get-ChildItem -Path $videoDir -Filter *.mp4) {
    $poster = Join-Path $posterDir ($video.BaseName + ".jpg")

    if ((Test-Path $poster) -and (-not $Force)) {
        $skipped++
        continue
    }

    # "thumbnail" picks a representative frame rather than frame 0, which
    # in these clips is often a near-black fade-in.
    & $FFmpeg -nostdin -loglevel error -y -i $video.FullName `
        -vf "thumbnail,scale=480:-2" -frames:v 1 -q:v 4 $poster 2>$null

    if ($LASTEXITCODE -eq 0 -and (Test-Path $poster) -and (Get-Item $poster).Length -gt 0) {
        Write-Host "OK   $($video.BaseName)"
        $made++
    } else {
        Write-Host "FAIL $($video.BaseName)"
        $failed++
    }
}

Write-Host ""
Write-Host "Posters generated: $made, skipped: $skipped, failed: $failed, videos renamed: $renamed"
if ($renamed -gt 0) {
    Write-Host "Renamed videos: update exercises.video_path in Supabase to match."
}
if ($failed -gt 0) { exit 1 }
