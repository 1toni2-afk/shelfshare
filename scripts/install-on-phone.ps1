# Instalează pe orice telefon Android atașat prin USB APK-ul de release construit
# în frontend/build/. Dacă aplicația e deja instalată cu altă cheie de semnare
# (INSTALL_FAILED_UPDATE_INCOMPATIBLE), dezinstalăm întâi și reinstalăm - se
# pierde doar sesiunea de login, restul datelor sunt pe server.
#
# Se lansează din cmd cu:
#   powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\install-on-phone.ps1"
# sau, dacă nu ești sigur de folderul curent, cu calea absolută.

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$apk = Join-Path $repoRoot 'frontend\build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) {
    Write-Host "APK-ul nu există la $apk. Construiește-l întâi cu:" -ForegroundColor Red
    Write-Host '  flutter build apk --release --dart-define=API_BASE_URL=https://api.shelfshare.ro'
    exit 1
}

# adb devices e sursa cea mai simplă și corectă pentru telefoane Android
# efectiv conectate - flutter devices include și emulatorul de Windows/web,
# iar filtrul pe targetPlatform s-a dovedit inconsistent între versiuni.
$devices = & adb devices |
    Select-String -Pattern '^(\S+)\s+device$' |
    ForEach-Object { $_.Matches[0].Groups[1].Value }

if (-not $devices) {
    Write-Host 'Niciun telefon Android detectat. Verifică cablul, depanarea USB și `adb devices`.' -ForegroundColor Red
    exit 1
}

foreach ($id in $devices) {
    $model = (& adb -s $id shell getprop ro.product.model).Trim()
    Write-Host ("--> {0} ({1})" -f $model, $id) -ForegroundColor Cyan
    $output = & adb -s $id install -r $apk 2>&1
    $output | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0 -or ($output -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE')) {
        Write-Host 'Semnătură diferită - dezinstalez varianta veche și reinstalez.' -ForegroundColor Yellow
        & adb -s $id uninstall ro.shelfshare.shelfshare | Out-Null
        & adb -s $id install -r $apk
    }
}
