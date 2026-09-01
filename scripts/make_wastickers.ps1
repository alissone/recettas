<#
.SYNOPSIS
    Convert a folder of GIFs (and video clips) into a WhatsApp .wastickers pack.

.DESCRIPTION
    Windows/PowerShell port of make_wastickers.sh.

    Any .m4s, .flv, .webm, .mp4, or .avi files found in the source folder are
    first auto-converted to GIF (trimmed to the first -MaxFrames frames at
    -VideoFps, scaled/padded to 512x512) so they can be treated the same as
    the folder's existing .gif files. These converted GIFs are intermediate
    only -- they live in a temp folder and are not written back to SrcDir.

    Output rules it enforces (WhatsApp sticker spec):
      - each sticker: animated WebP, 512x512, <= 500KB
      - tray icon: PNG, 96x96, <= 50KB
      - 3-30 stickers per pack

.PARAMETER SrcDir
    Folder containing the source .gif files and/or video clips.

.PARAMETER PackTitle
    Sticker pack title.

.PARAMETER PackAuthor
    Sticker pack author name.

.PARAMETER OutFile
    Output .wastickers path. Defaults to pack.wastickers in the current directory.

.PARAMETER FfmpegPath
    Path to ffmpeg.exe. Defaults to C:\dev\ffmpeg.exe.

.PARAMETER MaxFrames
    When converting a video clip to GIF, how many frames (at -VideoFps) to
    keep from the start of the clip. Defaults to 60 (4s at the default fps).

.PARAMETER VideoFps
    Frame rate used when sampling a video clip into an intermediate GIF.
    Defaults to 15.

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

    [int]$MaxFrames = 60,

    [int]$VideoFps = 15
)

$ErrorActionPreference = "Stop"

$MaxStickerBytes = 500 * 1024
$MaxTrayBytes = 50 * 1024
$Qualities = 75, 60, 45, 30, 20, 12
$VideoExtensions = ".m4s", ".flv", ".webm", ".mp4", ".avi"

if (-not (Test-Path -LiteralPath $FfmpegPath -PathType Leaf)) {
    throw "ffmpeg not found at $FfmpegPath"
}
if (-not (Test-Path -LiteralPath $SrcDir -PathType Container)) {
    throw "Source folder not found: $SrcDir"
}

# Resolve OutFile to an absolute path before we start writing into a temp dir.
if (-not [System.IO.Path]::IsPathRooted($OutFile)) {
    $OutFile = Join-Path (Get-Location).Path $OutFile
}

$WorkDir = Join-Path $env:TEMP ("wastickers_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $WorkDir | Out-Null

try {
    # --- Auto-convert any video clips in SrcDir to intermediate GIFs ---
    $videoFiles = @(
        Get-ChildItem -LiteralPath $SrcDir -File |
            Where-Object { $VideoExtensions -contains $_.Extension.ToLowerInvariant() } |
            Sort-Object Name
    )

    $convertedGifs = @()
    if ($videoFiles.Count -gt 0) {
        $VideoGifDir = Join-Path $WorkDir "from_video"
        New-Item -ItemType Directory -Path $VideoGifDir | Out-Null

        Write-Host "Converting $($videoFiles.Count) video clip(s) to GIF (first $MaxFrames frames @ ${VideoFps}fps)..."

        $vf = "fps=$VideoFps,scale=512:512:force_original_aspect_ratio=decrease,pad=512:512:(ow-iw)/2:(oh-ih)/2:color=0x00000000"

        foreach ($video in $videoFiles) {
            $palette = Join-Path $VideoGifDir "$($video.BaseName)_palette.png"
            $gifOut = Join-Path $VideoGifDir "$($video.BaseName).gif"

            try {
                & $FfmpegPath -y -loglevel error -i $video.FullName -frames:v $MaxFrames `
                    -vf "$vf,palettegen=stats_mode=diff" $palette
                if ($LASTEXITCODE -ne 0) { throw "palette generation failed" }

                & $FfmpegPath -y -loglevel error -i $video.FullName -i $palette -frames:v $MaxFrames `
                    -filter_complex "$vf[x];[x][1:v]paletteuse=dither=bayer" -an $gifOut
                if ($LASTEXITCODE -ne 0) { throw "gif encode failed" }

                $convertedGifs += Get-Item -LiteralPath $gifOut
                Write-Host "  $($video.Name) -> $($video.BaseName).gif"
            }
            catch {
                Write-Warning "  Skipping $($video.Name): $_"
            }
        }
    }

    $gifs = @(
        @(Get-ChildItem -LiteralPath $SrcDir -Filter *.gif -File) + @($convertedGifs) |
            Sort-Object Name
    )
    $count = $gifs.Count

    if ($count -eq 0) {
        throw "No .gif files (or convertible video clips) found in $SrcDir"
    }
    if ($count -gt 30) {
        Write-Warning "WhatsApp allows max 30 stickers per pack; found $count. Trimming to first 30."
        $gifs = $gifs[0..29]
        $count = 30
    }
    if ($count -lt 3) {
        throw "WhatsApp requires at least 3 stickers; found $count."
    }

    Write-Host "Converting $count GIF(s) to animated WebP..."

    for ($i = 0; $i -lt $count; $i++) {
        $gif = $gifs[$i]
        $outName = "sticker_{0:D3}.webp" -f ($i + 1)
        $outPath = Join-Path $WorkDir $outName

        $size = 0
        foreach ($q in $Qualities) {
            & $FfmpegPath -y -loglevel error -i $gif.FullName `
                -vf "fps=12,scale=512:512:force_original_aspect_ratio=decrease,pad=512:512:(ow-iw)/2:(oh-ih)/2:color=0x00000000" `
                -c:v libwebp_anim -lossless 0 -q:v $q -compression_level 6 -loop 0 -an -vsync 0 `
                $outPath
            if ($LASTEXITCODE -ne 0) {
                throw "ffmpeg failed converting $($gif.Name) (quality $q)"
            }
            $size = (Get-Item -LiteralPath $outPath).Length
            if ($size -le $MaxStickerBytes) {
                break
            }
        }

        if ($size -gt $MaxStickerBytes) {
            Write-Warning "$($gif.Name) still $size bytes after lowest quality pass -- consider trimming frames."
        }
        Write-Host ("  [{0}/{1}] {2} -> {3} ({4} bytes)" -f ($i + 1), $count, $gif.Name, $outName, $size)
    }

    # --- Tray icon: use first frame of the first GIF, downscaled to 96x96 PNG ---
    Write-Host "Building tray icon..."
    $Tray = Join-Path $WorkDir "tray.png"
    & $FfmpegPath -y -loglevel error -i $gifs[0].FullName -vframes 1 `
        -vf "scale=96:96:force_original_aspect_ratio=decrease,pad=96:96:(ow-iw)/2:(oh-ih)/2:color=0x00000000" `
        $Tray
    if ($LASTEXITCODE -ne 0) {
        throw "ffmpeg failed building tray icon"
    }
    $traySize = (Get-Item -LiteralPath $Tray).Length
    if ($traySize -gt $MaxTrayBytes) {
        Write-Warning "tray.png is $traySize bytes (limit ~50KB). It may still be accepted, but consider a simpler image."
    }

    # --- Metadata (no trailing newline, matching `echo -n`) ---
    [System.IO.File]::WriteAllText((Join-Path $WorkDir "title.txt"), $PackTitle)
    [System.IO.File]::WriteAllText((Join-Path $WorkDir "author.txt"), $PackAuthor)

    # --- Zip it up (flat structure: no folder paths inside the archive) ---
    # Compress-Archive refuses non-.zip destinations, so build a .zip and
    # rename it to the requested .wastickers path.
    Write-Host "Packing $OutFile..."
    $stickerFiles = Get-ChildItem -LiteralPath $WorkDir -File
    $items = $stickerFiles.FullName
    $zipTemp = Join-Path $WorkDir "__pack.zip"
    Compress-Archive -Path $items -DestinationPath $zipTemp -CompressionLevel Optimal

    if (Test-Path -LiteralPath $OutFile) {
        Remove-Item -LiteralPath $OutFile -Force
    }
    Move-Item -LiteralPath $zipTemp -Destination $OutFile

    if (-not (Test-Path -LiteralPath $OutFile)) {
        throw "Something went wrong producing $OutFile"
    }

    Write-Host "Done: $OutFile ($count stickers)"
    Write-Host "Transfer this file to your phone and open it with the 'Sticker Maker' app to import into WhatsApp."
}
finally {
    Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
}
