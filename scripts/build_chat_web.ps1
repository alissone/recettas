# Builds the chat-only web app (lib/main_chat.dart) into build/web_chat and
# deletes the bundled assets the chat never requests. pubspec.yaml has a
# single asset list, so the exercise GIFs/posters etc. get copied into every
# build; pruning them afterwards keeps the deploy small.
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

flutter build web -t lib/main_chat.dart --release --output build/web_chat
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$out = 'build/web_chat'
$prune = @(
  'assets/assets/exercises',
  'assets/assets/exercise_posters',
  'assets/assets/harpa_crista.json',
  'assets/assets/NVI.xml',
  'assets/assets/chart.min.js',
  'sqlite3.wasm',        # only LocalDb uses it
  'sqflite_sw.js'
)
foreach ($p in $prune) {
  $path = Join-Path $out $p
  if (Test-Path $path) { Remove-Item $path -Recurse -Force }
}

$mb = (Get-ChildItem $out -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
'{0}: {1:N1} MB after pruning' -f $out, $mb
