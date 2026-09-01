<#
.SYNOPSIS
    Convert a folder of GIFs (and video clips) into one or more WhatsApp .wastickers packs.

.DESCRIPTION
    Windows/PowerShell port of make_wastickers.sh.

    Any .m4s, .flv, .webm, .mp4, .avi, or .mov files found in the source folder are
    treated as sticker sources too. Each video is probed with ffprobe and
    split EVENLY into segments no longer than -MaxFrames (at the sticker
    output's 12fps) -- e.g. an 11s clip with the default ~5s segment target
    becomes three ~3.7s segments, not two 5s segments plus a 1s leftover.
    A short preview GIF is rendered for every segment into a review folder
    (opened automatically in Explorer), and the script then PAUSES:

        Press Enter once you've deleted any splits you don't want to keep...

    Delete whichever preview .gif files you don't want turned into stickers,
    then press Enter in the terminal. Only the segments whose preview file
    still exists are converted to final stickers -- straight from the
    original video at that segment's exact start/duration (never from the
    preview file itself, so there's no double-compression loss). Pass
    -SkipReview to keep every generated segment without pausing.

    If ffprobe can't be found, video splitting/review is disabled and each
    video clip falls back to just its first -MaxFrames frames, no pause.

    .gif files already in the folder are left alone (no split, no review)
    and go straight into the pack, same as before.

    If, after review, there are more than 30 sticker sources in total, they
    are split evenly across multiple packs (WhatsApp's limit is 30 stickers
    per pack) instead of discarding the extras -- e.g. 43 sources become a
    22 + 21 split, not a 30 + 13 or a 30-and-drop-the-rest. Pack N is written
    to "<OutFile base>_N<OutFile ext>", and its title gets a "(N/total)"
    suffix; with only one pack, -OutFile and -PackTitle are used as-is.

    A non-square source (e.g. a widescreen video) is letterboxed to the
    required 512x512 canvas with a TRANSPARENT pad, not a solid color --
    WhatsApp doesn't support a non-512x512 canvas, but a transparent pad
    reads as a non-square sticker since the letterboxed area is invisible.

    Output rules it enforces (WhatsApp sticker spec):
      - each sticker: animated WebP, 512x512, <= 500KB
      - tray icon: PNG, 96x96, <= 50KB
      - 3-30 stickers per pack

.PARAMETER SrcDir
    Folder containing the source .gif files and/or video clips.

.PARAMETER PackTitle
    Sticker pack title. Gets a "(N/total)" suffix when split into multiple packs.

.PARAMETER PackAuthor
    Sticker pack author name.

.PARAMETER OutFile
    Output .wastickers path. Defaults to pack.wastickers in the current directory.
    When split into multiple packs, each is named "<base>_N<ext>".

.PARAMETER FfmpegPath
    Path to ffmpeg.exe. Defaults to C:\dev\ffmpeg.exe.

.PARAMETER FfprobePath
    Path to ffprobe.exe. Defaults to ffprobe.exe next to -FfmpegPath.

.PARAMETER MaxFrames
    Target segment length in frames (at 12fps) when splitting a video clip.
    This is a script-level heuristic for keeping each sticker short enough to
    fit the 500KB budget, not a documented WhatsApp limit -- tune it to taste.
    Defaults to 60 (~5s).

.PARAMETER MaxSplitsPerVideo
    Safety cap on how many segments a single video can be split into (so a
    long video dropped in the folder doesn't generate hundreds of previews).
    If a video would need more segments than this, it's still split evenly
    across its whole duration, just into -MaxSplitsPerVideo bigger segments.
    Defaults to 20.

.PARAMETER SkipReview
    Skip the interactive pause and keep every generated video segment.

.EXAMPLE
    .\make_wastickers.ps1 -SrcDir .\gifs -PackTitle "My Pack" -PackAuthor "Alisson"
     C:\Users\Alisson\Documents\Projetos\recettas\scripts\make_wastickers.ps1 -SrcDir . -PackTitle "01" -PackAuthor "whatsappstickermaker"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SrcDir,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$PackTitle,

    [Parameter(Mandatory = $true, Position = 2)]
    [string]$PackAuthor,

    [Parameter(Position = 3)]
    [string]$OutFile = "pack.wastickers",

    [string]$FfmpegPath = "C:\dev\ffmpeg.exe",

    [string]$FfprobePath,

    [int]$MaxFrames = 60,

    [int]$MaxSplitsPerVideo = 20,

    [switch]$SkipReview
)

$ErrorActionPreference = "Stop"

$MaxStickerBytes = 500 * 1024
$MaxTrayBytes = 50 * 1024
$Qualities = 75, 60, 45, 30, 20, 12
$VideoExtensions = ".m4s", ".flv", ".webm", ".mp4", ".avi", ".mov"
$StickerFilter = "fps=12,scale=512:512:force_original_aspect_ratio=decrease,format=rgba,pad=512:512:(ow-iw)/2:(oh-ih)/2:color=0x00000000"

if (-not $FfprobePath) {
    $FfprobePath = Join-Path (Split-Path -Parent $FfmpegPath) "ffprobe.exe"
}

if (-not (Test-Path -LiteralPath $FfmpegPath -PathType Leaf)) {
    throw "ffmpeg not found at $FfmpegPath"
}
if (-not (Test-Path -LiteralPath $SrcDir -PathType Container)) {
    throw "Source folder not found: $SrcDir"
}

$hasFfprobe = Test-Path -LiteralPath $FfprobePath -PathType Leaf
if (-not $hasFfprobe) {
    Write-Warning "ffprobe not found at $FfprobePath -- video splitting/review is disabled; each video clip will just use its first $MaxFrames frames."
}

# Resolve OutFile to an absolute path before we start writing into a temp dir.
if (-not [System.IO.Path]::IsPathRooted($OutFile)) {
    $OutFile = Join-Path (Get-Location).Path $OutFile
}

$WorkDir = Join-Path $env:TEMP ("wastickers_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $WorkDir | Out-Null

try {
    # --- Gather sticker sources: .gif files plus any convertible video clips ---
    $gifItems = @(Get-ChildItem -LiteralPath $SrcDir -Filter *.gif -File)
    $videoItems = @(
        Get-ChildItem -LiteralPath $SrcDir -File |
            Where-Object { $VideoExtensions -contains $_.Extension.ToLowerInvariant() }
    )

    $gifSources = @(
        $gifItems | ForEach-Object {
            [pscustomobject]@{ FullName = $_.FullName; Name = $_.Name; IsVideo = $false; StartSeconds = 0; DurationSeconds = $null }
        }
    )

    $videoSources = @()

    if ($videoItems.Count -gt 0 -and -not $hasFfprobe) {
        # No ffprobe: fall back to the old "first N frames" behavior, one candidate per video.
        $videoSources = @(
            $videoItems | ForEach-Object {
                [pscustomobject]@{ FullName = $_.FullName; Name = $_.Name; IsVideo = $true; StartSeconds = 0; DurationSeconds = $null }
            }
        )
    }
    elseif ($videoItems.Count -gt 0) {
        $ReviewDir = Join-Path $WorkDir "review"
        New-Item -ItemType Directory -Path $ReviewDir | Out-Null

        $targetSegSeconds = $MaxFrames / 12.0
        $manifest = @()

        foreach ($video in $videoItems) {
            $durationRaw = & $FfprobePath -v error -show_entries format=duration -of csv=p=0 $video.FullName
            if ($LASTEXITCODE -ne 0 -or -not $durationRaw) {
                Write-Warning "Skipping $($video.Name): ffprobe could not read its duration."
                continue
            }
            $duration = [double]::Parse($durationRaw.Trim(), [System.Globalization.CultureInfo]::InvariantCulture)

            $numSeg = [int][Math]::Ceiling($duration / $targetSegSeconds)
            if ($numSeg -lt 1) { $numSeg = 1 }
            if ($numSeg -gt $MaxSplitsPerVideo) {
                Write-Warning ("{0} ({1:N1}s) would need {2} splits at ~{3:N1}s each; capping to {4} evenly-sized splits (~{5:N1}s each)." -f `
                    $video.Name, $duration, $numSeg, $targetSegSeconds, $MaxSplitsPerVideo, ($duration / $MaxSplitsPerVideo))
                $numSeg = $MaxSplitsPerVideo
            }
            $segLength = $duration / $numSeg

            Write-Host ("Splitting {0} ({1:N1}s) into {2} segment(s) of ~{3:N1}s..." -f $video.Name, $duration, $numSeg, $segLength)

            for ($seg = 0; $seg -lt $numSeg; $seg++) {
                $start = $seg * $segLength
                $partLabel = "part {0}/{1}" -f (($seg + 1).ToString("D2")), ($numSeg.ToString("D2"))
                $previewName = "{0}_part{1:D2}of{2:D2}.gif" -f $video.BaseName, ($seg + 1), $numSeg
                $previewPath = Join-Path $ReviewDir $previewName

                & $FfmpegPath -y -loglevel error -i $video.FullName -ss $start -t $segLength -vf $StickerFilter -an $previewPath
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "  Skipping $($video.Name) $partLabel : ffmpeg could not render the preview."
                    continue
                }

                $manifest += [pscustomobject]@{
                    PreviewPath      = $previewPath
                    SourceFullName   = $video.FullName
                    SourceName       = $video.Name
                    StartSeconds     = $start
                    DurationSeconds  = $segLength
                    PartLabel        = $partLabel
                }
            }
        }

        if ($manifest.Count -gt 0) {
            if ($SkipReview) {
                Write-Host "SkipReview set -- keeping all $($manifest.Count) generated segment(s)."
            }
            else {
                Write-Host ""
                Write-Host "Generated $($manifest.Count) preview segment(s) in: $ReviewDir"
                Write-Host "Delete whichever preview .gif files you DON'T want turned into stickers."
                try { Start-Process explorer.exe $ReviewDir } catch { }
                Read-Host "Press Enter once you're done deleting"
            }

            $surviving = @($manifest | Where-Object { Test-Path -LiteralPath $_.PreviewPath })
            $removedCount = $manifest.Count - $surviving.Count
            if ($removedCount -gt 0) {
                Write-Host "$removedCount segment(s) removed by review; keeping $($surviving.Count)."
            }

            $videoSources = @(
                $surviving | ForEach-Object {
                    [pscustomobject]@{
                        FullName        = $_.SourceFullName
                        Name            = "$($_.SourceName) ($($_.PartLabel))"
                        IsVideo         = $true
                        StartSeconds    = $_.StartSeconds
                        DurationSeconds = $_.DurationSeconds
                    }
                }
            )
        }
        else {
            Write-Warning "No usable video segments were generated from $($videoItems.Count) video clip(s)."
        }
    }

    $sources = @(@($gifSources) + @($videoSources) | Sort-Object Name)
    $totalCount = $sources.Count

    if ($totalCount -eq 0) {
        throw "No .gif files or usable video clips ($($VideoExtensions -join ', ')) found in $SrcDir"
    }
    if ($totalCount -lt 3) {
        throw "WhatsApp requires at least 3 stickers; found $totalCount."
    }

    # --- Split into multiple packs of <= 30 if needed, sized evenly so no ---
    # --- leftover pack ends up under WhatsApp's 3-sticker minimum.        ---
    $numPacks = [int][Math]::Ceiling($totalCount / 30.0)
    $baseSize = [int][Math]::Floor($totalCount / $numPacks)
    $remainder = $totalCount % $numPacks

    $packSources = @()
    $idx = 0
    for ($p = 0; $p -lt $numPacks; $p++) {
        $size = $baseSize
        if ($p -lt $remainder) { $size++ }
        $packSources += , @($sources[$idx..($idx + $size - 1)])
        $idx += $size
    }

    if ($numPacks -gt 1) {
        Write-Host "$totalCount sticker sources found; splitting into $numPacks packs (WhatsApp's limit is 30 per pack)."
    }

    $outDir = Split-Path -Parent $OutFile
    $outBase = [System.IO.Path]::GetFileNameWithoutExtension($OutFile)
    $outExt = [System.IO.Path]::GetExtension($OutFile)

    $packResults = @()

    for ($p = 0; $p -lt $numPacks; $p++) {
        $packItems = $packSources[$p]
        $packNum = $p + 1

        if ($numPacks -gt 1) {
            $suffix = "$packNum"
            if ($numPacks -ge 10) { $suffix = "{0:D2}" -f $packNum }
            $packOutFile = Join-Path $outDir "${outBase}_${suffix}${outExt}"
            $packTitleText = "$PackTitle ($packNum/$numPacks)"
            Write-Host ""
            Write-Host "--- Pack $packNum/$numPacks ($($packItems.Count) sources) ---"
        }
        else {
            $packOutFile = $OutFile
            $packTitleText = $PackTitle
        }

        $PackWorkDir = Join-Path $WorkDir "pack_$packNum"
        New-Item -ItemType Directory -Path $PackWorkDir | Out-Null

        Write-Host "Converting $($packItems.Count) source(s) to animated WebP..."

        $producedCount = 0
        for ($i = 0; $i -lt $packItems.Count; $i++) {
            $src = $packItems[$i]
            $outName = "sticker_{0:D3}.webp" -f ($i + 1)
            $outPath = Join-Path $PackWorkDir $outName

            $size = 0
            $failed = $false
            foreach ($q in $Qualities) {
                $ffArgs = @('-y', '-loglevel', 'error', '-i', $src.FullName)
                if ($src.IsVideo -and $null -ne $src.DurationSeconds) {
                    $ffArgs += @('-ss', "$($src.StartSeconds)", '-t', "$($src.DurationSeconds)")
                }
                $ffArgs += @('-vf', $StickerFilter)
                if ($src.IsVideo -and $null -eq $src.DurationSeconds) {
                    $ffArgs += @('-frames:v', $MaxFrames)
                }
                $ffArgs += @('-c:v', 'libwebp_anim', '-lossless', '0', '-q:v', "$q", '-compression_level', '6', '-loop', '0', '-an', '-vsync', '0', $outPath)

                & $FfmpegPath @ffArgs
                if ($LASTEXITCODE -ne 0) {
                    if ($src.IsVideo) {
                        Write-Warning "Skipping $($src.Name): ffmpeg could not convert it."
                        $failed = $true
                        break
                    }
                    throw "ffmpeg failed converting $($src.Name) (quality $q)"
                }
                $size = (Get-Item -LiteralPath $outPath).Length
                if ($size -le $MaxStickerBytes) {
                    break
                }
            }
            if ($failed) {
                continue
            }

            if ($size -gt $MaxStickerBytes) {
                Write-Warning "$($src.Name) still $size bytes after lowest quality pass -- consider a shorter segment."
            }
            Write-Host ("  [{0}/{1}] {2} -> {3} ({4} bytes)" -f ($i + 1), $packItems.Count, $src.Name, $outName, $size)
            $producedCount++
        }

        if ($producedCount -lt 3) {
            throw "Pack $packNum only produced $producedCount sticker(s) (WhatsApp requires at least 3); see warnings above."
        }

        # --- Tray icon: use first frame of the pack's first source, downscaled to 96x96 PNG ---
        Write-Host "Building tray icon..."
        $Tray = Join-Path $PackWorkDir "tray.png"
        $trayArgs = @('-y', '-loglevel', 'error')
        if ($packItems[0].IsVideo -and $packItems[0].StartSeconds -gt 0) {
            $trayArgs += @('-ss', "$($packItems[0].StartSeconds)")
        }
        $trayArgs += @('-i', $packItems[0].FullName, '-vframes', '1', '-vf', `
            "scale=96:96:force_original_aspect_ratio=decrease,format=rgba,pad=96:96:(ow-iw)/2:(oh-ih)/2:color=0x00000000", $Tray)
        & $FfmpegPath @trayArgs
        if ($LASTEXITCODE -ne 0) {
            throw "ffmpeg failed building tray icon"
        }
        $traySize = (Get-Item -LiteralPath $Tray).Length
        if ($traySize -gt $MaxTrayBytes) {
            Write-Warning "tray.png is $traySize bytes (limit ~50KB). It may still be accepted, but consider a simpler image."
        }

        # --- Metadata (no trailing newline, matching `echo -n`) ---
        [System.IO.File]::WriteAllText((Join-Path $PackWorkDir "title.txt"), $packTitleText)
        [System.IO.File]::WriteAllText((Join-Path $PackWorkDir "author.txt"), $PackAuthor)

        # --- Zip it up (flat structure: no folder paths inside the archive) ---
        # Compress-Archive refuses non-.zip destinations, so build a .zip and
        # rename it to the requested .wastickers path.
        Write-Host "Packing $packOutFile..."
        $stickerFiles = Get-ChildItem -LiteralPath $PackWorkDir -File
        $items = $stickerFiles.FullName
        $zipTemp = Join-Path $PackWorkDir "__pack.zip"
        Compress-Archive -Path $items -DestinationPath $zipTemp -CompressionLevel Optimal

        if (Test-Path -LiteralPath $packOutFile) {
            Remove-Item -LiteralPath $packOutFile -Force
        }
        Move-Item -LiteralPath $zipTemp -Destination $packOutFile

        if (-not (Test-Path -LiteralPath $packOutFile)) {
            throw "Something went wrong producing $packOutFile"
        }

        $packResults += [pscustomobject]@{ OutFile = $packOutFile; Count = $producedCount }
    }

    Write-Host ""
    foreach ($result in $packResults) {
        Write-Host "Done: $($result.OutFile) ($($result.Count) stickers)"
    }
    Write-Host "Transfer these file(s) to your phone and open each with the 'Sticker Maker' app to import into WhatsApp."
}
finally {
    Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
}
