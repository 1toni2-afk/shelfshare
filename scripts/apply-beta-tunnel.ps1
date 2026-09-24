# Aplica regulile de ingress pentru beta.shelfshare.ro si api-beta.shelfshare.ro.
#
# TREBUIE rulat dintr-un PowerShell RIDICAT (Run as administrator): fisierul de
# config al serviciului e sub C:\Windows\System32\, iar repornirea serviciului
# cere la fel drepturi de administrator.
#
# Ce face, in ordine:
#   1. verifica sa fie pornit ce trebuie sa fie pornit (5960 si 3999)
#   2. valideaza configul NOU inainte sa atinga ceva
#   3. face o copie de siguranta a configului curent, cu data in nume
#   4. copiaza configul nou si reporneste serviciul
#   5. verifica ca tunelul chiar a revenit si ca productia raspunde
#
# Intreruperea e de ordinul secundelor si afecteaza SI shelfshare.ro, SI
# api.shelfshare.ro - tunelul e unul singur pentru toate gazdele.
#
# Daca ceva merge prost, scriptul spune exact ce comanda restaureaza copia.

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$newConfig = Join-Path $PSScriptRoot "cloudflared-config.beta.yml"
$serviceConfig = "C:\Windows\System32\config\systemprofile\.cloudflared\config.yml"
$cloudflared = "C:\Program Files (x86)\cloudflared\cloudflared.exe"

function Fail($message) { Write-Host "  $message" -ForegroundColor Red; exit 1 }

# --- 0. drepturi ---
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Fail "Ruleaza din PowerShell ca administrator (click dreapta > Run as administrator)."
}

if (-not (Test-Path $newConfig)) { Fail "Nu gasesc $newConfig" }
if (-not (Test-Path $cloudflared)) { Fail "Nu gasesc $cloudflared" }

# --- 1. serviciile locale ---
# Fara verificarea asta, tunelul ar porni cu reguli care trimit spre porturi
# moarte, iar beta ar raspunde 502 fara sa fie evident de ce.
Write-Host "==> Verific ce asculta local..." -ForegroundColor Cyan
foreach ($check in @(@{ Port = 5960; Name = "beta-server.js (frontendul nou)" },
                     @{ Port = 3999; Name = "backendul de test (docker compose)" })) {
    $listening = Get-NetTCPConnection -State Listen -LocalPort $check.Port -ErrorAction SilentlyContinue
    if ($listening) {
        Write-Host "    OK  portul $($check.Port) - $($check.Name)" -ForegroundColor Green
    } else {
        Fail "Portul $($check.Port) nu asculta ($($check.Name)). Porneste-l intai."
    }
}

# --- 2. validare inainte de orice modificare ---
Write-Host "==> Validez configul nou..." -ForegroundColor Cyan
& $cloudflared tunnel --config $newConfig ingress validate
if ($LASTEXITCODE -ne 0) { Fail "Configul nou nu e valid. Nu am schimbat nimic." }

# --- 3. copie de siguranta ---
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = "$serviceConfig.bak-$stamp"
Copy-Item -LiteralPath $serviceConfig -Destination $backup -Force
Write-Host "==> Copie de siguranta: $backup" -ForegroundColor Cyan

# --- 4. aplicare + repornire ---
Write-Host "==> Copiez configul si repornesc serviciul..." -ForegroundColor Cyan
Copy-Item -LiteralPath $newConfig -Destination $serviceConfig -Force
try {
    Restart-Service -Name "Cloudflared" -Force
} catch {
    Write-Host "  Repornirea a esuat. Restaurez configul vechi..." -ForegroundColor Red
    Copy-Item -LiteralPath $backup -Destination $serviceConfig -Force
    Restart-Service -Name "Cloudflared" -Force -ErrorAction SilentlyContinue
    Fail "Configul a fost restaurat din copie. Eroarea: $_"
}

# --- 5. verificare ---
# Tunelul are nevoie de cateva secunde ca sa restabileasca conexiunile spre
# marginea Cloudflare; verificam cu reincercari, nu o singura data.
#
# Verificarea NU foloseste rezolverul DNS al masinii, ci se leaga direct de o
# adresa de edge Cloudflare cu `--resolve`. Motivul e concret: dupa ce creezi o
# gazda noua, rezolverul din LAN (routerul) poate tine in cache raspunsul
# NXDOMAIN de la o interogare facuta INAINTE de creare, si atunci scriptul
# raporteaza "beta nu raspunde" desi beta e perfect functional pentru restul
# lumii. Exact asta s-a intamplat la prima rulare.
Write-Host "==> Astept revenirea tunelului..." -ForegroundColor Cyan

# curl.exe exista nativ pe Windows 10+; `Invoke-WebRequest` nu are echivalent
# pentru --resolve, iar un Host header manual ar strica SNI-ul din TLS.
$curl = "$env:SystemRoot\System32\curl.exe"
if (-not (Test-Path $curl)) { Write-Host "    (curl.exe lipseste; verific prin DNS-ul local)" -ForegroundColor Yellow }

# Adresele de edge se iau de la un rezolver public, nu de la cel local.
$edgeIps = @()
try {
    $edgeIps = (Resolve-DnsName -Name "shelfshare.ro" -Type A -Server "1.1.1.1" -ErrorAction Stop |
        Where-Object { $_.IPAddress }).IPAddress
} catch { }

function Test-Host-Live($url) {
    $uri = [Uri]$url
    if ((Test-Path $curl) -and $edgeIps.Count -gt 0) {
        foreach ($ip in $edgeIps) {
            $code = & $curl -s -o NUL -w "%{http_code}" --max-time 10 `
                --resolve "$($uri.Host):443:$ip" $url
            if ($code -eq "200") { return $true }
        }
        return $false
    }
    try {
        return (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10).StatusCode -eq 200
    } catch { return $false }
}

$targets = @(
    @{ Url = "https://shelfshare.ro/";          Label = "productie (web)" },
    @{ Url = "https://api.shelfshare.ro/";      Label = "productie (API)" },
    @{ Url = "https://beta.shelfshare.ro/";     Label = "beta (web nou)" },
    @{ Url = "https://api-beta.shelfshare.ro/"; Label = "beta (API de test)" }
)

$failed = @()
foreach ($target in $targets) {
    $ok = $false
    for ($i = 1; $i -le 12; $i++) {
        if (Test-Host-Live $target.Url) { $ok = $true; break }
        Start-Sleep -Seconds 5
    }
    if ($ok) {
        Write-Host "    OK  $($target.Label)  $($target.Url)" -ForegroundColor Green
    } else {
        Write-Host "    NU  $($target.Label)  $($target.Url)" -ForegroundColor Red
        $failed += $target.Label
    }
}

Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "==> Gata. beta.shelfshare.ro e live, productia neatinsa." -ForegroundColor Green
} else {
    Write-Host "==> ATENTIE: nu raspund inca: $($failed -join ', ')" -ForegroundColor Yellow
    Write-Host "    Daca PRODUCTIA e printre ele, restaureaza imediat:" -ForegroundColor Yellow
    Write-Host "      Copy-Item -LiteralPath '$backup' -Destination '$serviceConfig' -Force" -ForegroundColor Yellow
    Write-Host "      Restart-Service -Name Cloudflared -Force" -ForegroundColor Yellow
    Write-Host "    Daca doar BETA lipseste, e local: verifica 5960 si 3999." -ForegroundColor Yellow
}
