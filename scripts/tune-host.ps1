<#
  Reduce zgomotul de CPU de pe NUC, ca static-server sa nu mai fie infometat.

  Context (10.09.2026): masina are 4 nuclee si sta la 100%% CPU. Procesul node e
  dat la o parte de scheduler secunde intregi - masurat pe /robots.txt, un
  string din memorie fara I/O: median 9ms, p90 3.6s, max 9.3s. Cloudflare
  renunta si intoarce 502 "Host: Error", desi serverul e perfect sanatos.
  Consumatori: vmmemwsl (Docker/WSL2) ~18%%, msmpeng (Defender realtime) ~12%%,
  searchindexer ~8%%, gwctlsrv ~6.5%%.

  Ruleaza ca ADMINISTRATOR. E idempotent: poate fi rulat de cate ori vrei.
#>
[CmdletBinding()]
param([switch]$WhatIfOnly)

$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\wwwto\Documents\GitHub\shelfshare'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
      ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error 'Trebuie rulat ca administrator.'
  exit 1
}

# --- 1. Defender: excluderi -------------------------------------------------
# Scanarea in timp real citeste fiecare fisier atins. Un build Flutter web
# rescrie mii de fisiere, iar VHDX-ul Docker e un fisier de zeci de GB atins
# continuu de toate containerele - ambele sunt cost pur, pe un cod pe care il
# producem noi.
$excludePaths = @(
  $repo,
  "$repo\frontend\build",
  "$env:LOCALAPPDATA\Docker\wsl",
  "$env:LOCALAPPDATA\Docker\wsl\disk"
) | Where-Object { Test-Path $_ }

# node.exe nu e exclus ca proces: ar insemna ca NIMIC din ce citeste el nu mai e
# scanat, adica si continutul servit public. Excludem doar caile noastre.
$excludeProcesses = @()

foreach ($p in $excludePaths) {
  if ($WhatIfOnly) { Write-Host "[WhatIf] Defender exclude cale: $p"; continue }
  Add-MpPreference -ExclusionPath $p
  Write-Host "Defender: exclusa calea $p"
}
foreach ($p in $excludeProcesses) {
  if ($WhatIfOnly) { Write-Host "[WhatIf] Defender exclude proces: $p"; continue }
  Add-MpPreference -ExclusionProcess $p
  Write-Host "Defender: exclus procesul $p"
}

# --- 2. Windows Search: scoate repo-ul din indexare -------------------------
# Repo-ul e sub Documents, care e indexat implicit. Indexeaza degeaba zeci de mii
# de fisiere de build care se rescriu la fiecare deploy.
if ($WhatIfOnly) {
  Write-Host "[WhatIf] Search: regula de excludere pentru $repo"
} else {
  try {
    $csm = New-Object -ComObject Microsoft.Search.Administration.CrawlScopeManager
  } catch {
    $csm = $null
  }
  if ($null -eq $csm) {
    # COM-ul nu e disponibil pe toate build-urile. Fallback pe registry: acelasi
    # efect, citit de serviciul de indexare la repornire.
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows Search\CrawlScopeManager\Windows\SystemIndex\DefaultRules'
    Write-Warning "COM CrawlScopeManager indisponibil - exclud prin oprirea indexarii pe folder (atributul FILE_ATTRIBUTE_NOT_CONTENT_INDEXED)."
    # Atributul 'not content indexed' pe folder, recursiv: e mecanismul pe care
    # il foloseste si caseta "Allow files to have contents indexed" din
    # Properties, si e respectat de indexer fara repornire de serviciu.
    & attrib.exe +I /S /D "$repo\*" 2>&1 | Out-Null
    & attrib.exe +I /D "$repo" 2>&1 | Out-Null
    Write-Host "Search: repo marcat ca neindexabil prin atribut."
  } else {
    $url = 'file:///' + $repo.Replace('\','/') + '/'
    $csm.AddUserScopeExclusionRule($url, $true, 0)
    $csm.SaveAll()
    Write-Host "Search: regula de excludere adaugata pentru $url"
  }
}

Write-Host ''
Write-Host '--- excluderi Defender active acum ---'
(Get-MpPreference).ExclusionPath
