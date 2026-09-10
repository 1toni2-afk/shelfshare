# Verifica Tailscale si expune mediul de TEST (http://localhost:5961) in tailnet.
#
# De ce e nevoie de script: portul 5961 e legat DELIBERAT pe 127.0.0.1 in
# docker-compose.test.yml, deci nu e vizibil nici macar in LAN. In loc sa-l
# deschidem pe 0.0.0.0 (ar ajunge si la orice alt device din retea), folosim
# `tailscale serve`, care il publica DOAR catre device-urile din tailnet-ul
# tau, pe HTTPS, cu certificat valid.
#
# Usage:
#   ./scripts/tailscale-test.ps1              # verifica + porneste serve
#   ./scripts/tailscale-test.ps1 -CheckOnly   # doar diagnostic
#   ./scripts/tailscale-test.ps1 -Off         # opreste expunerea
#   ./scripts/tailscale-test.ps1 -Funnel      # + public pe internet (atentie!)

param(
    [switch]$CheckOnly,
    [switch]$Off,
    [switch]$Funnel,
    [int]$Port = 5961
)

$ErrorActionPreference = "Stop"

function Find-Tailscale {
    $cmd = (Get-Command tailscale -ErrorAction SilentlyContinue).Source
    if ($cmd) { return $cmd }
    $fallback = "C:\Program Files\Tailscale\tailscale.exe"
    if (Test-Path $fallback) { return $fallback }
    throw "Nu am gasit 'tailscale'. Instaleaza-l de la https://tailscale.com/download"
}

$ts = Find-Tailscale
Write-Host "==> tailscale: $ts" -ForegroundColor Cyan

# --- Diagnostic -------------------------------------------------------------
$statusJson = & $ts status --json 2>$null
if ($LASTEXITCODE -ne 0 -or -not $statusJson) {
    throw "'tailscale status' a esuat. Ruleaza 'tailscale up' si logheaza-te."
}
$status = $statusJson | ConvertFrom-Json

if ($status.BackendState -ne "Running") {
    throw "Tailscale nu e pornit (BackendState=$($status.BackendState)). Ruleaza: tailscale up"
}

$self = $status.Self
$ip4  = @($self.TailscaleIPs) | Where-Object { $_ -notmatch ':' } | Select-Object -First 1
$dns  = $self.DNSName.TrimEnd('.')

Write-Host "    device : $($self.HostName)" -ForegroundColor Green
Write-Host "    IP     : $ip4" -ForegroundColor Green
Write-Host "    MagicDNS: $dns" -ForegroundColor Green
Write-Host "    online : $($self.Online)" -ForegroundColor Green
if ($status.MagicDNSSuffix) {
    Write-Host "    tailnet: $($status.MagicDNSSuffix)" -ForegroundColor Green
} else {
    Write-Host "    ATENTIE: MagicDNS pare dezactivat - foloseste IP-ul 100.x direct." -ForegroundColor Yellow
}

$peers = @($status.Peer.PSObject.Properties.Value | Where-Object { $_.Online })
Write-Host "    peers online: $($peers.Count)" -ForegroundColor Green

# Ruleaza containerul de test?
$listening = Test-NetConnection -ComputerName 127.0.0.1 -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue
if (-not $listening) {
    Write-Host "    ATENTIE: nimic nu asculta pe 127.0.0.1:$Port. Porneste mediul de test:" -ForegroundColor Yellow
    Write-Host "      docker compose -f docker-compose.test.yml --env-file .env.test up -d" -ForegroundColor Yellow
} else {
    Write-Host "    127.0.0.1:$Port raspunde" -ForegroundColor Green
}

Write-Host "==> serve activ acum:" -ForegroundColor Cyan
& $ts serve status

if ($CheckOnly) { return }

# --- Expunere ---------------------------------------------------------------
if ($Off) {
    & $ts serve --https=443 off
    & $ts funnel --https=443 off 2>$null
    Write-Host "==> Expunerea a fost oprita." -ForegroundColor Cyan
    return
}

Write-Host "==> tailscale serve -> http://127.0.0.1:$Port" -ForegroundColor Cyan
& $ts serve --bg --https=443 "http://127.0.0.1:$Port"
if ($LASTEXITCODE -ne 0) { throw "'tailscale serve' a esuat." }

if ($Funnel) {
    Write-Host "==> Funnel PORNIT - mediul de test devine public pe internet." -ForegroundColor Yellow
    & $ts funnel --bg --https=443 "http://127.0.0.1:$Port"
}

Write-Host ""
Write-Host "Deschide de pe orice device din tailnet:  https://$dns/" -ForegroundColor Green
Write-Host "(sau http://${ip4}:443 daca MagicDNS e oprit)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Bundle-ul web trebuie construit cu API pe aceeasi origine:" -ForegroundColor DarkGray
Write-Host "  flutter build web -o build/web-test --dart-define=API_BASE_URL=/api" -ForegroundColor DarkGray
