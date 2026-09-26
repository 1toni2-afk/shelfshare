# Muta shelfshare.ro si www.shelfshare.ro de pe Flutter (static-server.js, 5959)
# pe React (beta-server.js, 5960) - sau inapoi, cu -Rollback.
#
# TREBUIE rulat dintr-un PowerShell RIDICAT (Run as administrator): configul
# serviciului e sub C:\Windows\System32\, iar repornirea lui cere admin.
#
# Pasii de dinainte (backend de productie, build React contra productiei,
# variabilele din start-beta-server.bat) sunt in docs/mutare-react-pe-shelfshare.md.
# Scriptul REFUZA sa mute domeniul daca ii lipseste vreunul verificabil de aici.
#
# Ce face:
#   1. verifica serverul tinta si build-ul React (API de productie, canonical)
#   2. pleaca de la configul LIVE al serviciului, nu de la o copie din repo, si
#      schimba DOAR portul pentru shelfshare.ro si www.shelfshare.ro - restul
#      gazdelor (api, storage, beta, runapp) raman exact cum sunt
#   3. valideaza, face copie de siguranta, aplica, reporneste serviciul
#   4. verifica sa ramana UN singur proces cloudflared (procesele orfane dau
#      404 intermitent pe gazdele noi) si ca domeniul raspunde de pe serverul nou
#
# Usage (PowerShell ca administrator):
#   .\scripts\switch-web-to-react.ps1
#   .\scripts\switch-web-to-react.ps1 -Rollback

param(
    [switch]$Rollback
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$serviceConfig = "C:\Windows\System32\config\systemprofile\.cloudflared\config.yml"
$cloudflared = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
$fromPort = if ($Rollback) { 5960 } else { 5959 }
$toPort = if ($Rollback) { 5959 } else { 5960 }
$hosts = @("shelfshare.ro", "www.shelfshare.ro")

function Fail($message) { Write-Host "  $message" -ForegroundColor Red; exit 1 }
function Ok($message) { Write-Host "    OK  $message" -ForegroundColor Green }

# --- 0. drepturi ---
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Fail "Ruleaza din PowerShell ca administrator (click dreapta > Run as administrator)."
}
if (-not (Test-Path $serviceConfig)) { Fail "Nu gasesc $serviceConfig" }
if (-not (Test-Path $cloudflared)) { Fail "Nu gasesc $cloudflared" }

# --- 1. serverul tinta ---
Write-Host "==> Verific serverul tinta (port $toPort)..." -ForegroundColor Cyan
if (-not (Get-NetTCPConnection -State Listen -LocalPort $toPort -ErrorAction SilentlyContinue)) {
    Fail "Portul $toPort nu asculta. Porneste intai serverul (task-ul de Task Scheduler)."
}
Ok "portul $toPort asculta"

if (-not $Rollback) {
    # Build-ul React trebuie sa vorbeasca cu PRODUCTIA. Un build pentru beta
    # (api-beta = baza de test) pus pe domeniul principal ar trimite userii
    # reali in baza de test - conturi care „dispar", mesaje care nu ajung.
    $buildInfoPath = Join-Path $repoRoot "web\dist\build-info.json"
    if (-not (Test-Path $buildInfoPath)) {
        Fail "Lipseste web\dist\build-info.json. Ruleaza: .\scripts\deploy-beta.ps1 -ApiBaseUrl https://api.shelfshare.ro"
    }
    $buildInfo = Get-Content -Raw -LiteralPath $buildInfoPath | ConvertFrom-Json
    if ($buildInfo.apiBaseUrl -ne "https://api.shelfshare.ro") {
        Fail "Build-ul React loveste '$($buildInfo.apiBaseUrl)', nu productia. Ruleaza: .\scripts\deploy-beta.ps1 -ApiBaseUrl https://api.shelfshare.ro"
    }
    Ok "build-ul React loveste https://api.shelfshare.ro"

    # Canonical-ul spune lui Google care e adresa paginii. Fara BETA_SITE_URL,
    # ar ramane beta.shelfshare.ro si Google ar indexa beta in locul domeniului.
    $landing = (Invoke-WebRequest -Uri "http://127.0.0.1:$toPort/" -UseBasicParsing -TimeoutSec 10).Content
    if ($landing -notmatch 'rel="canonical" href="https://shelfshare\.ro/"') {
        Fail "Canonical-ul nu e https://shelfshare.ro/. Decomenteaza BETA_SITE_URL si REDIRECT_HOSTS in scripts\start-beta-server.bat si reporneste task-ul."
    }
    Ok "canonical = https://shelfshare.ro/"

    # Backendul de productie trebuie sa aiba endpointurile folosite de React.
    $api = "http://localhost:3000"
    try {
        Invoke-WebRequest -Uri "$api/profile/leaderboard/national" -UseBasicParsing -TimeoutSec 10 | Out-Null
    } catch { Fail "Backendul de productie nu raspunde pe $api." }
    $missing = $false
    try {
        # Ruta noua din redesignul de profil; fara token intoarce 401, iar pe un
        # backend vechi, fara ruta, 404.
        Invoke-WebRequest -Uri "$api/profile/00000000-0000-0000-0000-000000000000/compatibility" -UseBasicParsing -TimeoutSec 10 | Out-Null
    } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) { $missing = $true }
    }
    if ($missing) {
        Fail "Backendul de productie e vechi (lipseste /profile/:id/compatibility). Fa intai deploy-ul backendului - vezi docs."
    }
    Ok "backendul de productie are rutele noi"
}

# --- 2. configul nou, derivat din cel live ---
Write-Host "==> Pregatesc configul (shelfshare.ro + www: $fromPort -> $toPort)..." -ForegroundColor Cyan
$lines = Get-Content -LiteralPath $serviceConfig
$pendingHost = $null
$changed = 0
$out = foreach ($line in $lines) {
    if ($line -match '^\s*-\s*hostname:\s*(\S+)\s*$') {
        $pendingHost = if ($hosts -contains $Matches[1]) { $Matches[1] } else { $null }
        $line
        continue
    }
    if ($pendingHost -and $line -match "^(\s*service:\s*http://localhost:)$fromPort\s*$") {
        $changed++
        $pendingHost = $null
        "$($Matches[1])$toPort"
        continue
    }
    $line
}
if ($changed -ne $hosts.Count) {
    Fail "Am gasit $changed din $($hosts.Count) reguli de schimbat (asteptam port $fromPort). Nimic modificat - verifica manual $serviceConfig."
}

$tmp = Join-Path $env:TEMP "cloudflared-switch-$(Get-Date -Format yyyyMMddHHmmss).yml"
Set-Content -LiteralPath $tmp -Value $out -Encoding ascii
& $cloudflared tunnel --config $tmp ingress validate
if ($LASTEXITCODE -ne 0) { Fail "Configul nou nu e valid. Nimic modificat." }
Ok "config valid ($changed reguli schimbate)"

# --- 3. aplicare ---
$backup = "$serviceConfig.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $serviceConfig -Destination $backup -Force
Write-Host "==> Copie de siguranta: $backup" -ForegroundColor Cyan
Copy-Item -LiteralPath $tmp -Destination $serviceConfig -Force
try {
    Restart-Service -Name "Cloudflared" -Force
} catch {
    Copy-Item -LiteralPath $backup -Destination $serviceConfig -Force
    Restart-Service -Name "Cloudflared" -Force -ErrorAction SilentlyContinue
    Fail "Repornirea a esuat; am restaurat configul vechi. Eroarea: $_"
}

# --- 4. verificare ---
Start-Sleep -Seconds 5
$procs = @(Get-Process cloudflared -ErrorAction SilentlyContinue)
if ($procs.Count -ne 1) {
    Write-Host "    ATENTIE: $($procs.Count) procese cloudflared. Cele vechi dau 404 intermitent;" -ForegroundColor Yellow
    Write-Host "    opreste-le pe cele care nu sunt ale serviciului (Stop-Process -Id ...)." -ForegroundColor Yellow
} else {
    Ok "un singur proces cloudflared"
}

$curl = "$env:SystemRoot\System32\curl.exe"
$edgeIps = @()
try {
    $edgeIps = (Resolve-DnsName -Name "shelfshare.ro" -Type A -Server "1.1.1.1" -ErrorAction Stop |
        Where-Object { $_.IPAddress }).IPAddress
} catch { }

# /build-info.json exista doar in build-ul React: 200 inseamna ca domeniul chiar
# e servit de beta-server.js, 404 ca e inca (sau iar) Flutter.
$expected = if ($Rollback) { "404" } else { "200" }
$ok = $false
for ($i = 1; $i -le 12 -and -not $ok; $i++) {
    foreach ($ip in $edgeIps) {
        $code = & $curl -s -o NUL -w "%{http_code}" --max-time 10 `
            --resolve "shelfshare.ro:443:$ip" "https://shelfshare.ro/build-info.json?check=$i"
        if ($code -eq $expected) { $ok = $true; break }
    }
    if (-not $ok) { Start-Sleep -Seconds 5 }
}

Write-Host ""
if ($ok) {
    $what = if ($Rollback) { "Flutter (static-server.js)" } else { "React (beta-server.js)" }
    Write-Host "==> Gata. shelfshare.ro e servit de $what." -ForegroundColor Green
    Write-Host "    Continua cu verificarile din docs/mutare-react-pe-shelfshare.md." -ForegroundColor Green
} else {
    Write-Host "==> ATENTIE: n-am putut confirma comutarea." -ForegroundColor Yellow
    Write-Host "    Pentru a reveni exact la starea dinainte:" -ForegroundColor Yellow
    Write-Host "      Copy-Item -LiteralPath '$backup' -Destination '$serviceConfig' -Force" -ForegroundColor Yellow
    Write-Host "      Restart-Service -Name Cloudflared -Force" -ForegroundColor Yellow
}
