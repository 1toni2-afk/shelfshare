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
    # Atributul 'not content indexed', recursiv: acelasi mecanism ca bifa
    # "Allow files ... to have contents indexed" din Properties, respectat de
    # indexer fara repornire de serviciu.
    #
    # ATENTIE la sintaxa: pe directorul radacina se da FARA /D ('attrib +I dir'),
    # iar /D e acceptat DOAR impreuna cu /S. 'attrib +I /D dir' intoarce
    # "Parameter format not correct" - iar prima versiune a scriptului trimitea
    # eroarea in Out-Null si raporta succes fara sa fi setat nimic.
    # NU recursiv. Prima incercare a fost 'attrib +I /S /D repo\*' peste tot
    # repo-ul (node_modules, .git, build) si a tinut masina la 100%% CPU minute
    # in sir - adica exact infometarea pe care incercam sa o eliminam: un task
    # de healthcheck a avut nevoie de 3 minute doar ca sa porneasca PowerShell.
    #
    # Nici nu e nevoie: indexer-ul nu coboara intr-un folder marcat
    # NotContentIndexed, iar fisierele noi create intr-un astfel de folder
    # mostenesc atributul. Marcam radacina si folderele de build, care sunt si
    # cele care se rescriu la fiecare deploy.
    #
    # Sintaxa: pe un director se da FARA /D ('attrib +I dir'); /D e acceptat
    # DOAR impreuna cu /S. 'attrib +I /D dir' intoarce "Parameter format not
    # correct" - iar prima versiune trimitea eroarea in Out-Null si raporta
    # succes fara sa fi setat nimic.
    foreach ($d in @($repo, "$reporontenduild", "$repoackend\dist")) {
      if (Test-Path $d) { & attrib.exe +I $d }
    }

    # Verificam efectul, nu codul de iesire: attrib intoarce 0 si cand n-a facut
    # nimic. Fara asta, un esec arata identic cu o reusita.
    $rootAttr = (Get-Item $repo -Force).Attributes
    if ($rootAttr -band [System.IO.FileAttributes]::NotContentIndexed) {
      Write-Host "Search: repo marcat ca neindexabil (verificat: $rootAttr)."
    } else {
      Write-Error "Search: atributul NU s-a aplicat pe $repo (atribute: $rootAttr)."
    }
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
