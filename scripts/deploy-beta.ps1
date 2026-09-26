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
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "npm run build a esuat." }
} finally {
    Remove-Item Env:\VITE_API_BASE_URL -ErrorAction SilentlyContinue
    Pop-Location
}

# Verificare ca API-ul chiar a ajuns in bundle. Un build fara variabila cade pe
# productie prin default-ul din vite.config.ts, ceea ce pe un beta gandit sa
# loveasca zona de test ar trece complet neobservat - pana cand cineva ar
# modifica date reale crezand ca e pe test.
$assets = Join-Path $webDir "dist\assets"
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

Write-Host ""
Write-Host "==> Gata. web/dist actualizat; beta-server.js il serveste live." -ForegroundColor Green
Write-Host "    Daca beta-server.js nu ruleaza inca:  node scripts/beta-server.js" -ForegroundColor Yellow
