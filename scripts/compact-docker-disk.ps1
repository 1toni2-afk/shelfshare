# Recupereaza spatiul pe care il tine degeaba discul virtual al Docker.
#
# docker_data.vhdx creste cand se scriu imagini/volume, dar NU se micsoreaza
# cand ele se sterg: pe 2026-09-27 fisierul avea ~67 GB pe C:, iar Docker
# folosea efectiv ~43 GB, cu discul C: aproape plin.
#
# Ruleaza din PowerShell deschis ca ADMINISTRATOR (Optimize-VHD cere asta):
#   powershell -ExecutionPolicy Bypass -File scripts\compact-docker-disk.ps1
#
# ATENTIE: opreste Docker, deci si productia (API, baza de date, pozele),
# cateva minute. Site-ul static ramane sus, dar fara API.

$ErrorActionPreference = "Stop"
$vhdx = Join-Path $env:LOCALAPPDATA "Docker\wsl\disk\docker_data.vhdx"
if (-not (Test-Path $vhdx)) { throw "Nu gasesc $vhdx" }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Deschide PowerShell ca Administrator si ruleaza din nou." }

$before = (Get-Item $vhdx).Length
Write-Host ("==> Inainte: {0:N1} GB, liber pe C: {1:N1} GB" -f ($before / 1GB), ((Get-PSDrive C).Free / 1GB)) -ForegroundColor Cyan

# Blocurile goale din interior trebuie marcate ca libere (TRIM) cat Docker
# inca ruleaza, altfel compactarea nu are ce recupera.
Write-Host "==> TRIM in discul Docker..." -ForegroundColor Cyan
wsl -d docker-desktop -e sh -c "fstrim -av" | Out-Host

Write-Host "==> Opresc Docker si WSL (productia e JOS de aici)..." -ForegroundColor Yellow
docker desktop stop | Out-Host
wsl --shutdown
Start-Sleep -Seconds 5

try {
    Write-Host "==> Compactez (poate dura cateva minute)..." -ForegroundColor Cyan
    Optimize-VHD -Path $vhdx -Mode Full
} finally {
    # Docker porneste inapoi chiar daca compactarea a esuat - altfel
    # productia ar ramane jos.
    Write-Host "==> Pornesc Docker la loc..." -ForegroundColor Cyan
    docker desktop start | Out-Host
}

$after = (Get-Item $vhdx).Length
Write-Host ("==> Dupa: {0:N1} GB (recuperat {1:N1} GB), liber pe C: {2:N1} GB" -f `
    ($after / 1GB), (($before - $after) / 1GB), ((Get-PSDrive C).Free / 1GB)) -ForegroundColor Green
Write-Host "    Verifica: https://api.shelfshare.ro/books/browse?limit=1 trebuie sa dea 200 in ~1 minut." -ForegroundColor Yellow
