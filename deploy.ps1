# Deploys the game to GitHub Pages with a fresh build stamp.
# The stamp is written into index.html AND version.json, which is what lets a
# running page notice a new deploy and reload past the 10-minute Pages cache.

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

# BOM-less UTF-8. Set-Content -Encoding utf8 adds a BOM on PS 5.1, which puts a
# stray marker before <!DOCTYPE html> and can break JSON.parse on version.json.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$dir = $PSScriptRoot

# stamp index.html (replaces whatever the previous build id was)
$html = [System.IO.File]::ReadAllText("$dir\index.html")
$html = $html -replace "^\xEF\xBB\xBF", ""
$html = [regex]::Replace($html, "const BUILD = '[^']*';", "const BUILD = '$stamp';")
[System.IO.File]::WriteAllText("$dir\index.html", $html, $utf8NoBom)

# the file the running page polls
[System.IO.File]::WriteAllText("$dir\version.json", "{`"build`":`"$stamp`"}", $utf8NoBom)

git add -A
git -c user.name="Mason" -c user.email="lilcamjam567@gmail.com" commit -m "deploy $stamp" | Out-Null
git push --quiet 2>&1 | Out-Null

Write-Output "pushed build $stamp"

# wait for Pages to finish building, then confirm the live copy really has it
for ($i = 0; $i -lt 20; $i++) {
  Start-Sleep -Seconds 10
  $b = gh api repos/masonfrizzell60-alt/ball-battle/pages/builds/latest 2>$null | ConvertFrom-Json
  if ($b.status -eq "built") { break }
}

$live = (Invoke-WebRequest -Uri "https://masonfrizzell60-alt.github.io/ball-battle/version.json?_=$([int](Get-Date -UFormat %s))" -UseBasicParsing -TimeoutSec 20).Content
if ($live -match [regex]::Escape($stamp)) {
  Write-Output "LIVE: build $stamp is serving"
} else {
  Write-Output "WARNING: server still reports $live"
}
