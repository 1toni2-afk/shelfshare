# Construieste build-urile de Android (APK pentru instalare directa pe telefon
# si AAB pentru Play Console) CU API_BASE_URL setat.
#
# Exista ca script separat tocmai fiindca un `flutter build apk/appbundle` rulat
# manual, fara --dart-define, produce un binar in care ApiConfig.baseUrl ramane
# "http://localhost:3000": aplicatia porneste normal, dar orice request loveste
# telefonul insusi, iar in UI se vede doar "A aparut o eroare. Incearca din nou."
# la login. (Din 31.08.2026 default-ul de release e productia, deci nu mai e o
# capcana tacuta - dar scriptul ramane calea recomandata.)
#
# Usage:
#   ./scripts/build-android.ps1                 # APK + AAB pe API-ul de productie
#   ./scripts/build-android.ps1 -Apk            # doar APK
#   ./scripts/build-android.ps1 -Bundle         # doar AAB
#   ./scripts/build-android.ps1 -ApiBaseUrl http://192.168.1.10:3000

#: acelasi motiv ca la deploy-web.ps1 - tree-shaking-ul de
# iconite se uita doar la referintele statice de IconData si arunca glifele
# folosite prin cautari dinamice (Map<String, IconData>), care ajung invizibile
# in aplicatie fara nicio eroare.
param(
    [string]$ApiBaseUrl = "https://api.shelfshare.ro",
    [switch]$Apk,
    [switch]$Bundle
)

$ErrorActionPreference = "Stop"

# Fara niciun switch construim ambele - cazul obisnuit inainte de o lansare.
if (-not $Apk -and -not $Bundle) {
    $Apk = $true
    $Bundle = $true
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$frontend = Join-Path $repoRoot "frontend"

# Aceeasi cautare de flutter ca in deploy-web.ps1.
$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutter) {
    $fallback = "C:\src\flutter\bin\flutter.bat"
    if (Test-Path $fallback) {
        $flutter = $fallback
    } else {
        throw "Nu am gasit 'flutter' in PATH si nici la $fallback. Seteaza calea manual."
    }
}

Push-Location $frontend
try {
    if ($Apk) {
        Write-Host "==> Build APK (API_BASE_URL=$ApiBaseUrl)..." -ForegroundColor Cyan
        & $flutter build apk --release --dart-define=API_BASE_URL=$ApiBaseUrl
        if ($LASTEXITCODE -ne 0) { throw "flutter build apk a esuat." }
    }
    if ($Bundle) {
        Write-Host "==> Build AAB (API_BASE_URL=$ApiBaseUrl)..." -ForegroundColor Cyan
        & $flutter build appbundle --release --dart-define=API_BASE_URL=$ApiBaseUrl
        if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle a esuat." }
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "==> Gata." -ForegroundColor Green
if ($Apk) {
    Write-Host "    APK: frontend\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
    Write-Host "    Instaleaza-l pe telefon cu ./scripts/install-on-phone.ps1" -ForegroundColor Yellow
}
if ($Bundle) {
    Write-Host "    AAB: frontend\build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Green
}
