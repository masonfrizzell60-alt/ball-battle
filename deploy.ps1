# Deploys the game to GitHub Pages with a fresh build stamp.
# The stamp is written into index.html AND version.json, which is what lets a
# running page notice a new deploy and reload past the 10-minute Pages cache.

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

# stamp index.html (replaces whatever the previous build id was)
$html = Get-Content index.html -Raw
$html = [regex]::Replace($html, "const BUILD = '[^']*';", "const BUILD = '$stamp';")
Set-Content index.html -Value $html -Encoding utf8 -NoNewline

# the file the running page polls
Set-Content version.json -Value "{`"build`":`"$stamp`"}" -Encoding utf8 -NoNewline

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
