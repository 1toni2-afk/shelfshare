# Rebuilds the Flutter web bundle for production.
#
# Ruleaza asta pe mașina care găzduiește shelfshare.ro (cea pe care rulează
# static-server.js - tunelul Cloudflare o rutează la portul lui). static-server
# servește direct din frontend/build/web și citește fișierele la fiecare cerere,
# deci NU e nevoie să-l repornești: cum se termină build-ul, bundle-ul nou e live.
#
# Pasul complementar (backend) e ./scripts/deploy.sh, care rulează pe NUC și
# reface containerul Docker. Cele două mașini sunt diferite, de aceea sunt scripturi
# separate.
#
# Usage:
#   ./scripts/deploy-web.ps1                 # build cu API-ul de producție
#   ./scripts/deploy-web.ps1 -Pull           # git pull inainte de build
#   ./scripts/deploy-web.ps1 -ApiBaseUrl https://api.shelfshare.ro

param(
    [string]$ApiBaseUrl = "https://api.shelfshare.ro",
    [switch]$Pull
)

$ErrorActionPreference = "Stop"

# Radacina repo-ului = parintele folderului scripts/, indiferent de unde e rulat.
$repoRoot = Split-Path -Parent $PSScriptRoot
$frontend = Join-Path $repoRoot "frontend"

# Gaseste flutter: intai din PATH, altfel calea cunoscuta de pe aceasta masina.
$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutter) {
    $fallback = "C:\src\flutter\bin\flutter.bat"
    if (Test-Path $fallback) {
        $flutter = $fallback
    } else {
        throw "Nu am gasit 'flutter' in PATH si nici la $fallback. Seteaza calea manual."
    }
}

if ($Pull) {
    Write-Host "==> git pull..." -ForegroundColor Cyan
    git -C $repoRoot pull
    if ($LASTEXITCODE -ne 0) { throw "git pull a esuat." }
}

Write-Host "==> Build web (API_BASE_URL=$ApiBaseUrl)..." -ForegroundColor Cyan
Push-Location $frontend
try {
    & $flutter build web --release --dart-define=API_BASE_URL=$ApiBaseUrl
    if ($LASTEXITCODE -ne 0) { throw "flutter build web a esuat." }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "==> Gata. build/web actualizat; static-server il serveste live." -ForegroundColor Green
Write-Host "    In browser: hard refresh (Ctrl+Shift+R) - main.dart.js are max-age 4h," -ForegroundColor Yellow
Write-Host "    deci copia veche din cache se foloseste pana la refresh fortat." -ForegroundColor Yellow
