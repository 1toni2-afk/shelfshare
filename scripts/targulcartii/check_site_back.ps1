<#
    Verifica zilnic daca targulcartii.ro si-a revenit si, cand revine, porneste
    colectarea si trimite un email.

    De ce e nevoie de asta: pe 2026-09-09 site-ul servea HTTP 200 cu corp gol la
    orice pagina HTML (PHP picat la ei), in timp ce robots.txt si imaginile veneau
    normal. Nu suntem blocati pe IP - acelasi tipar se vede si din alte retele -
    deci nu are rost sa reluam scraperul pana nu se repara ei.

    Pragul pe octeti, nu pe status code: 200 nu inseamna nimic aici, vezi log-ul
    vechi cu 36.000 de inregistrari goale salvate ca "succes".

    Pornirea automata a scraperului e sigura chiar daca ne inselam si site-ul e
    inca stricat: build_onboarding_db.py se opreste singur la prima pagina goala
    (clasa Blocked) fara sa scrie nimic.
#>
[CmdletBinding()]
param(
    # Trimite un email de proba si iese, fara sa atinga scraperul. Pentru a
    # verifica o singura data ca wiring-ul Resend chiar functioneaza.
    [switch]$TestEmail
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = (Resolve-Path (Join-Path $Root '..\..')).Path
$LogPath    = Join-Path $Root 'data\site_watch.log'
$ScrapeTask = 'ShelfShareOnboardingScrape'
$WatchTask  = 'ShelfShareTargulCartiiWatch'
$HomeUrl    = 'https://www.targulcartii.ro/'

# Homepage-ul plin are zeci de KB. Pragul e sus ca sa nu ne pacaleasca o pagina
# de mentenanta scurta; daca totusi trece una, scraperul se opreste singur.
$MinBytes = 5000

function Write-Log([string]$Message) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LogPath) | Out-Null
    Add-Content -Path $LogPath -Value $line -Encoding utf8
    Write-Output $line
}

function Get-DotEnvValue([string]$Key) {
    $envFile = Join-Path $RepoRoot '.env'
    if (-not (Test-Path $envFile)) { throw ".env lipseste la $envFile" }
    foreach ($line in Get-Content $envFile -Encoding utf8) {
        if ($line -match "^\s*$([regex]::Escape($Key))\s*=\s*(.*)$") {
            return $Matches[1].Trim().Trim('"').Trim("'")
        }
    }
    throw "$Key lipseste din .env"
}

function Send-Mail([string]$Subject, [string]$Body) {
    $key  = Get-DotEnvValue 'RESEND_API_KEY'
    $from = Get-DotEnvValue 'MAIL_FROM'
    # Destinatarul sta in .env, nu in script: repo-ul e public.
    $MailTo = Get-DotEnvValue 'WATCH_NOTIFY_EMAIL'
    $payload = @{
        from    = $from
        to      = @($MailTo)
        subject = $Subject
        text    = $Body
    } | ConvertTo-Json -Depth 5

    # UTF8 explicit: altfel diacriticele pleaca stricate.
    $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
    $resp = Invoke-RestMethod -Method Post -Uri 'https://api.resend.com/emails' `
        -Headers @{ Authorization = "Bearer $key" } `
        -ContentType 'application/json; charset=utf-8' -Body $bytes
    Write-Log "email trimis catre $MailTo (id: $($resp.id))"
}

if ($TestEmail) {
    Write-Log 'TEST: trimit email de proba'
    Send-Mail 'ShelfShare: monitorul targulcartii e activ' @"
Asta e doar un email de proba - site-ul NU a revenit inca.

Confirma ca notificarea chiar ajunge la tine. Checkul ruleaza zilnic la 09:00
si iti scrie din nou doar cand targulcartii.ro chiar serveste pagini.
"@
    exit 0
}

# --- verificarea propriu-zisa ---
$size = 0
try {
    $out  = & curl.exe -s --max-time 30 -o NUL -w '%{size_download}' $HomeUrl
    $size = [int]($out | Select-Object -First 1)
} catch {
    Write-Log "cererea a esuat: $($_.Exception.Message)"
    exit 0   # o retea picata nu e o eroare a taskului; reincercam maine
}

if ($size -lt $MinBytes) {
    Write-Log "inca picat ($size octeti)"
    exit 0
}

Write-Log "SITE REVENIT ($size octeti) - pornesc $ScrapeTask"

$started = $false
try {
    $state = (Get-ScheduledTask -TaskName $ScrapeTask).State
    if ($state -eq 'Running') {
        Write-Log "$ScrapeTask rula deja - nu-l pornesc a doua oara"
    } else {
        Start-ScheduledTask -TaskName $ScrapeTask
        $started = $true
    }
} catch {
    Write-Log "nu am putut porni $ScrapeTask : $($_.Exception.Message)"
}

$actiune = if ($started) {
    "Am pornit colectarea (ShelfShareOnboardingScrape). Dureaza ~1.1h la delay 60s."
} else {
    "NU am pornit colectarea - vezi log-ul. Porneste manual:
    Start-ScheduledTask -TaskName ShelfShareOnboardingScrape"
}

try {
    Send-Mail 'ShelfShare: targulcartii.ro a revenit' @"
targulcartii.ro serveste iar pagini ($size octeti pe homepage).

$actiune

Mai lipsesc ~32 de titluri de onboarding si copertile. Progresul:
    $Root\data\onboarding_run.log
Monitorul s-a oprit singur, nu-ti mai scrie de acum.
"@
} catch {
    Write-Log "emailul a esuat: $($_.Exception.Message)"
}

# Si-a facut treaba: nu mai are rost sa ruleze zilnic.
try {
    Disable-ScheduledTask -TaskName $WatchTask | Out-Null
    Write-Log "$WatchTask dezactivat"
} catch {
    Write-Log "nu am putut dezactiva $WatchTask : $($_.Exception.Message)"
}
