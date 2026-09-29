# Rebuild pentru beta.shelfshare.ro (noul frontend din web/).
#
# Echivalentul lui deploy-web.ps1, dar pentru React. Ruleaza pe aceeasi masina
# care gazduieste site-ul; beta-server.js citeste web/dist la fiecare cerere,
# deci NU e nevoie sa-l repornesti - cum se termina build-ul, e live.
#
# Backendul nu se atinge in niciun fel: acelasi cod, aceleasi endpointuri.
# Din 2026-09-26 build-ul acesta e servit si pe shelfshare.ro (vezi
# docs/mutare-react-pe-shelfshare.md), deci implicitul e PRODUCTIA. Un build
# contra api-beta (backendul de TEST, portul 3999) ar trimite userii reali ai
# domeniului principal in baza de test. Pentru teste locale contra bazei de
# test, foloseste zona de test (localhost:5961), nu acest script.
#
# Usage:
#   ./scripts/deploy-beta.ps1
#   ./scripts/deploy-beta.ps1 -Pull

param(
    [string]$ApiBaseUrl = "https://api.shelfshare.ro",
    [switch]$Pull
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$webDir = Join-Path $repoRoot "web"
$liveDir = Join-Path $webDir "dist"
$nextDir = Join-Path $webDir "dist-next"

if (-not (Test-Path $webDir)) { throw "Nu gasesc $webDir." }

if ($Pull) {
    Write-Host "==> git pull..." -ForegroundColor Cyan
    git -C $repoRoot pull
    if ($LASTEXITCODE -ne 0) { throw "git pull a esuat." }
}

Push-Location $webDir
try {
    # `npm ci`, nu `npm install`: instaleaza exact ce scrie in package-lock.json.
    # Un `install` poate ridica tacit o versiune minora si transforma deploy-ul
    # intr-un build diferit de cel testat.
    if (-not (Test-Path (Join-Path $webDir "node_modules"))) {
        Write-Host "==> npm ci..." -ForegroundColor Cyan
        npm ci
        if ($LASTEXITCODE -ne 0) { throw "npm ci a esuat." }
    }

    Write-Host "==> Build (VITE_API_BASE_URL=$ApiBaseUrl)..." -ForegroundColor Cyan
    # Variabila e citita de vite.config.ts si injectata in bundle la compilare
    # (vezi `define`), nu la runtime: bundle-ul ajunge si in APK-ul Capacitor,
    # unde nu exista niciun server care sa livreze variabile de mediu.
    $env:VITE_API_BASE_URL = $ApiBaseUrl
    # Build in dist-next, NU direct in dist: beta-server.js serveste dist live,
    # iar Vite goleste folderul de iesire la inceput. Cat dura build-ul, orice
    # vizitator primea 500 („index.html lipseste") - s-a vazut pe shelfshare.ro
    # pe 2026-09-26. Folderul live se actualizeaza abia la final (vezi mai jos).
    if (Test-Path $nextDir) { Remove-Item -Recurse -Force $nextDir }
    npm run build -- --outDir dist-next --emptyOutDir
    if ($LASTEXITCODE -ne 0) { throw "npm run build a esuat." }
    if (-not (Test-Path (Join-Path $nextDir "index.html"))) { throw "Build-ul n-a produs dist-next/index.html." }
} finally {
    Remove-Item Env:\VITE_API_BASE_URL -ErrorAction SilentlyContinue
    Pop-Location
}

# Verificare ca API-ul chiar a ajuns in bundle. Un build fara variabila cade pe
# productie prin default-ul din vite.config.ts, ceea ce pe un beta gandit sa
# loveasca zona de test ar trece complet neobservat - pana cand cineva ar
# modifica date reale crezand ca e pe test.
$assets = Join-Path $nextDir "assets"
$found = $false
if (Test-Path $assets) {
    $needle = $ApiBaseUrl.TrimEnd('/')
    foreach ($file in Get-ChildItem -Path $assets -Filter "*.js") {
        if ((Get-Content -Raw -LiteralPath $file.FullName) -like "*$needle*") { $found = $true; break }
    }
}
if ($found) {
    Write-Host "    OK: bundle-ul pointeaza spre $ApiBaseUrl" -ForegroundColor Green
} else {
    Write-Host "    ATENTIE: n-am gasit $ApiBaseUrl in bundle. Verifica manual." -ForegroundColor Yellow
}

# Punerea live: COPIERE in dist, niciodata redenumirea folderelor. Pe Windows
# o redenumire de folder pica („Access denied") cat timp orice proces tine un
# handle in el - un `vite dev` pornit in web/ urmareste dist-next. Pe
# 2026-09-27 prima redenumire (dist -> dist-prev) a mers, a doua nu, si site-ul
# a stat cateva secunde fara index.html.
#
# Ordinea conteaza: intai bucatile noi (nume cu hash, deci doar se adauga,
# nimic servit acum nu se schimba), apoi index.html & co. care le refera,
# abia la final stergerea celor vechi. Bucatile sterse raman in dist-archive
# (vezi vite.config.ts), de unde beta-server.js le serveste filelor deschise.
function Invoke-Robocopy([string[]]$RobocopyArgs) {
    robocopy @RobocopyArgs /NFL /NDL /NJH /NJS /NP | Out-Null
    # robocopy: 0-7 = succes (1 = fisiere copiate), >= 8 = esec.
    if ($LASTEXITCODE -ge 8) { throw "robocopy a esuat (cod $LASTEXITCODE): $($RobocopyArgs -join ' ')" }
}
Write-Host "==> Pun build-ul nou in web/dist..." -ForegroundColor Cyan
Invoke-Robocopy @((Join-Path $nextDir "assets"), (Join-Path $liveDir "assets"), "/E")
Invoke-Robocopy @($nextDir, $liveDir, "/E", "/XD", (Join-Path $nextDir "assets"))
Invoke-Robocopy @($nextDir, $liveDir, "/MIR")
$global:LASTEXITCODE = 0
Remove-Item -Recurse -Force $nextDir -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==> Gata. web/dist actualizat; beta-server.js il serveste live." -ForegroundColor Green
Write-Host "    Daca beta-server.js nu ruleaza inca:  node scripts/beta-server.js" -ForegroundColor Yellow
