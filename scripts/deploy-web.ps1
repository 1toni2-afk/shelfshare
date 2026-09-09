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
    # --no-tree-shake-icons e obligatoriu: tree-shaking-ul implicit se uita doar
    # la referintele statice de IconData si arunca glifele folosite prin cautari
    # dinamice (ex. Map<String, IconData> pentru iconitele din sidebar) - in
    # productie iconitele alea au ajuns invizibile, fara nicio eroare vizibila.
    & $flutter build web --release --no-tree-shake-icons --dart-define=API_BASE_URL=$ApiBaseUrl
    if ($LASTEXITCODE -ne 0) { throw "flutter build web a esuat." }
} finally {
    Pop-Location
}

# Curatenie DUPA build, nu inainte: static-server serveste direct din
# build/web, deci golirea folderului inainte de compilare ar lasa site-ul cazut
# tot timpul build-ului (~4-5 minute la fiecare deploy).
#
# Flutter scrie main.dart.js_N.part.js doar pentru partile de care are nevoie,
# dar nu sterge niciodata fisierele ramase de la o numerotare veche - se
# strang la nesfarsit (32 de fisiere din care doar 14 folosite, la momentul
# scrierii). Nu ne luam dupa data fisierului, ci dupa ce refera chiar
# main.dart.js: e criteriul exact, nu o aproximare.
#
# Efect secundar acceptat: o sesiune de browser deschisa in timpul deploy-ului
# si care cere o parte cu numerotarea VECHE primeste 404 si ecranul
# "Aceasta sectiune nu s-a putut incarca" din deferred_screen.dart. Oricum
# primea continut nepotrivit si inainte, fiindca un build nou rescrie
# part_N cu alt continut.
Write-Host ""
Write-Host "==> Curat fisierele .part.js ramase de la build-uri vechi..." -ForegroundColor Cyan
$webDir = Join-Path $frontend "build\web"
$mainJs = Join-Path $webDir "main.dart.js"
if (Test-Path $mainJs) {
    $referenced = @([regex]::Matches((Get-Content -Raw $mainJs), 'main\.dart\.js_\d+\.part\.js') |
        ForEach-Object { $_.Value } | Sort-Object -Unique)
    if ($referenced.Count -eq 0) {
        # Fara nicio referinta nu putem sti ce e viu - mai bine nu stergem nimic.
        Write-Host "    main.dart.js nu refera niciun .part.js; nu sterg nimic." -ForegroundColor Yellow
    } else {
        $orphans = @(Get-ChildItem -Path $webDir -Filter "main.dart.js_*.part.js" |
            Where-Object { $referenced -notcontains $_.Name })
        foreach ($o in $orphans) { Remove-Item -LiteralPath $o.FullName -Force }
        Write-Host "    $($orphans.Count) orfane sterse, $($referenced.Count) pastrate."
    }
} else {
    Write-Host "    build/web/main.dart.js lipseste; sar peste curatenie." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> Gata. build/web actualizat; static-server il serveste live." -ForegroundColor Green
# Mesajul de mai jos spunea candva ca e nevoie de hard refresh, fiindca
# main.dart.js avea max-age 4h. Nu mai e adevarat: static-server trimite
# "no-cache, must-revalidate" + ETag pentru TOATE fisierele (vezi comentariul
# despre /assets/ din static-server.js), iar Cloudflare respecta acum headerele
# originii ("Respect Existing Headers"), deci revalideaza in loc sa serveasca
# o copie veche. Un refresh normal e suficient.
Write-Host "    Un refresh normal ajunge - toate fisierele merg cu no-cache + ETag." -ForegroundColor Yellow
Write-Host "    Daca totusi vezi versiunea veche, verifica in DevTools > Network ca" -ForegroundColor Yellow
Write-Host "    main.dart.js chiar vine cu 200/304 de la origine, nu din disk cache." -ForegroundColor Yellow
