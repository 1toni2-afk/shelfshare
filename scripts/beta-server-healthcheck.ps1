<#
  Repornește beta-server.js când e ÎNȚEPENIT, nu doar când a murit.

  Oglindă a static-server-healthcheck.ps1, cu aceleași motive - vezi
  comentariile de acolo pentru istoricul complet. Pe scurt: bucla din
  start-beta-server.bat acoperă cazul „procesul a murit", dar NU cazul
  „procesul e viu, ține portul deschis, acceptă conexiuni TCP, și nu răspunde
  niciodată". Pentru Windows al doilea caz arată perfect sănătos, deci nimic
  nu l-ar reporni, iar Cloudflare ar da 502 până l-ar observa cineva manual.

  De-aia sonda e o cerere HTTP reală, nu „există procesul?" sau „ascultă cineva
  pe port?" - amândouă răspund „da" în timp ce serverul e mort funcțional.

  Diferența față de varianta de la static-server: sonda lovește `/__health`,
  care răspunde cu un string din memorie, fără nicio atingere de disc. Dacă ar
  citi un fișier, o furtună de I/O ar arăta identic cu o înțepenire și am
  reporni un server perfect sănătos.

  Remediul e să omorâm DOAR node-ul și să lăsăm .bat-ul să repornească. Așa
  scriptul nu trebuie să știe cum se pornește serverul.
#>
[CmdletBinding()]
param(
  [int]$Port = 5960,
  [string]$Path = '/__health',
  # Trei încercări, nu una: o singură ratare poate fi un hiccup de o secundă
  # (GC, contenție de disc la un deploy). Repornim doar dacă e constant mort.
  [int]$Attempts = 3,
  # 8s, ca la static-server: mașina stă la 100% CPU pe 4 nuclee, iar node-ul e
  # descheduled secunde întregi chiar când e sănătos. Cu 5s, o furtună de CPU ar
  # arăta identic cu o înțepenire.
  [int]$TimeoutSec = 8,
  [int]$DelaySec = 5,
  # Raportează ce ar face, fără să omoare nimic. Pentru testare.
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$logFile = Join-Path $PSScriptRoot 'beta-server-healthcheck.log'

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

# Filtrul pe linia de comanda trebuie sa fie EXACT 'beta-server.js'. Un filtru
# mai larg (ex. '*server.js*') ar prinde si static-server.js si ar omori
# productia ca sa repare beta.
$nodes = @(Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
  Where-Object { $_.CommandLine -like '*beta-server.js*' })

if ($nodes.Count -eq 0) {
  # Nimic de omorât. Ori bucla .bat e între două încercări (repornește în 3s),
  # ori a murit tot lanțul - caz în care trigger-ul de 5 minute al task-ului
  # "ShelfShare Beta Server" îl ridică. Un restart forțat de aici n-ar ajuta.
  Write-Log 'Niciun proces node cu beta-server.js - las bucla .bat / task-ul sa il porneasca.'
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
# lipsă) ar produce un log plin de „am repornit" și nicio urmă că n-a mers.
Start-Sleep -Seconds 10
try {
  $r2 = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec $TimeoutSec
  Write-Log "Revenit: HTTP $($r2.StatusCode)."
  exit 0
} catch {
  Write-Log "INCA jos dupa restart: $($_.Exception.Message)"
  exit 1
}
