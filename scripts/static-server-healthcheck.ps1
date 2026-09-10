<#
  Repornește static-server.js când e ÎNȚEPENIT, nu doar când a murit.

  Bucla din start-static-server.bat acoperă cazul "procesul a murit": node iese,
  .bat-ul îl pornește la loc în 3 secunde. Nu acoperă însă cazul văzut pe
  10.09.2026: procesul era viu, ținea portul 5959 deschis și accepta conexiuni
  TCP instantaneu, dar nu răspundea NICIODATĂ - nici măcar la /robots.txt, care
  e un string din memorie, fără I/O. Event loop-ul era blocat. Pentru Windows
  procesul arăta perfect sănătos, deci nimic nu l-a repornit; Cloudflare a dat
  502 "Host: Error" iar site-ul a stat jos până l-am observat manual.

  De-aia sonda e o cerere HTTP reală, nu "există procesul?" sau "ascultă cineva
  pe port?" - amândouă răspundeau "da" în timp ce site-ul era jos.

  Remediul e să omorâm DOAR node-ul și să lăsăm .bat-ul să repornească. Așa
  scriptul ăsta nu trebuie să știe cum se pornește serverul (vbs, bat, task),
  iar dacă cineva schimbă vreodată modul de pornire, healthcheck-ul rămâne bun.
#>
[CmdletBinding()]
param(
  [int]$Port = 5959,
  [string]$Path = '/robots.txt',
  # Trei încercări, nu una: o singură ratare poate fi un hiccup de o secundă
  # (GC, contenție de disc la un deploy). Repornim doar dacă e constant mort -
  # un restart inutil taie cererile în curs ale userilor.
  [int]$Attempts = 3,
  # 8s, nu 5: masina sta la 100%% CPU pe 4 nuclee, iar node-ul e descheduled
  # secunde intregi chiar cand e perfect sanatos (p90 3.6s, max 9.3s masurat pe
  # /robots.txt). Cu 5s, o furtuna de CPU ar arata identic cu o intepenire si am
  # reporni un server care era doar incetinit - exact invers decat vrem.
  [int]$TimeoutSec = 8,
  [int]$DelaySec = 5,
  # Raportează ce ar face, fără să omoare nimic. Pentru testare.
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$logFile = Join-Path $PSScriptRoot 'static-server-healthcheck.log'

function Write-Log([string]$msg) {
  $line = ('[{0}] {1}' -f (Get-Date -Format 'dd/MM/yyyy HH:mm:ss'), $msg)
  Add-Content -Path $logFile -Value $line -Encoding UTF8
}

# Logul e scris de un task care rulează la fiecare 2 minute, adică ~260.000 de
# linii pe an dacă nu-l tăiem. Păstrăm ultimele 500.
if ((Test-Path $logFile) -and (Get-Item $logFile).Length -gt 1MB) {
  $keep = Get-Content $logFile -Tail 500
  Set-Content -Path $logFile -Value $keep -Encoding UTF8
}

$url = "http://127.0.0.1:$Port$Path"
$healthy = $false
$lastError = ''

for ($i = 1; $i -le $Attempts; $i++) {
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec $TimeoutSec
    if ($r.StatusCode -eq 200) { $healthy = $true; break }
    $lastError = "HTTP $($r.StatusCode)"
  } catch {
    $lastError = $_.Exception.Message
  }
  if ($i -lt $Attempts) { Start-Sleep -Seconds $DelaySec }
}

if ($healthy) { exit 0 }

Write-Log "NEsanatos dupa $Attempts incercari pe $url - ultima eroare: $lastError"

$nodes = @(Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
  Where-Object { $_.CommandLine -like '*static-server.js*' })

if ($nodes.Count -eq 0) {
  # Nimic de omorât. Ori bucla .bat e între două încercări (repornește în 3s),
  # ori a murit tot lanțul - caz în care trigger-ul de 5 minute al task-ului
  # "ShelfShare Static Server" îl ridică. În ambele cazuri, un restart forțat
  # de aici n-ar ajuta, doar ar încurca.
  Write-Log 'Niciun proces node cu static-server.js - las bucla .bat / task-ul sa il porneasca.'
  exit 1
}

foreach ($n in $nodes) {
  if ($DryRun) {
    Write-Log "[DryRun] as omori node PID $($n.ProcessId)"
    continue
  }
  try {
    Stop-Process -Id $n.ProcessId -Force
    Write-Log "Omorat node PID $($n.ProcessId) - bucla .bat il reporneste in ~3s."
  } catch {
    Write-Log "NU am putut omori PID $($n.ProcessId): $($_.Exception.Message)"
  }
}

if ($DryRun) { exit 1 }

# Confirmăm că a revenit, ca logul să spună dacă remediul a funcționat sau nu.
# Fără verificarea asta, un server care moare la pornire (port ocupat, build
# corupt) ar produce un log plin de "am repornit" și nicio urmă că n-a mers.
Start-Sleep -Seconds 10
try {
  $r2 = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec $TimeoutSec
  Write-Log "Revenit: HTTP $($r2.StatusCode)."
  exit 0
} catch {
  Write-Log "INCA jos dupa restart: $($_.Exception.Message)"
  exit 1
}
