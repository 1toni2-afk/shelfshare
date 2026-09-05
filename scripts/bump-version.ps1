# Bump versionCode (build number) in frontend/pubspec.yaml.
#
# Usage:
#   pwsh scripts/bump-version.ps1              # bumps only the build number (+X)
#   pwsh scripts/bump-version.ps1 -Minor       # bumps the minor + resets patch, then +1 build
#   pwsh scripts/bump-version.ps1 -Major       # bumps the major + resets minor/patch, then +1 build
#
# Format Flutter: X.Y.Z+BUILD -> versionName=X.Y.Z, versionCode=BUILD.
# Play Console cere versionCode strict crescător per release.

param(
  [switch]$Major,
  [switch]$Minor,
  [switch]$Patch
)

$pubspec = Join-Path $PSScriptRoot '..\frontend\pubspec.yaml'
if (-not (Test-Path $pubspec)) { throw "pubspec.yaml nu a fost găsit la $pubspec" }

# Citit/scris EXPLICIT ca UTF-8 fara BOM, prin .NET, nu cu Get-Content/
# Set-Content. In Windows PowerShell 5.1, `Get-Content -Raw` decodeaza cu
# codepage-ul ANSI, iar `Set-Content -Encoding utf8` scrie UTF-8 CU BOM: la
# bump-ul spre 1.5.4+20, drumul asta a citit octetii UTF-8 ai comentariilor ca
# ANSI si i-a re-encodat, adica le-a mai adaugat un strat de mojibake, plus un
# BOM la inceputul fisierului. 19 linii schimbate pentru un bump de o linie.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$content = [System.IO.File]::ReadAllText($pubspec, $utf8NoBom)
if ($content -notmatch '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$') {
  throw 'Nu am putut parsa `version: X.Y.Z+BUILD` din pubspec.yaml'
}

# PowerShell nu diferențiază `$major`/`$Major` (variabilele sunt case-
# insensitive) - cu aceleași nume ca switch-urile de mai sus (-Major/-Minor/
# -Patch), atribuirea de mai jos SUPRASCRIA switch-ul, iar `if ($Major)`
# devenea adevărat oricând versiunea majoră curentă era diferită de zero
# (ex. "1" -> truthy), indiferent ce flag primise scriptul de fapt. Nume
# distincte ca să nu se mai ciocnească.
$verMajor = [int]$Matches[1]
$verMinor = [int]$Matches[2]
$verPatch = [int]$Matches[3]
$verBuild = [int]$Matches[4]

if ($Major)     { $verMajor++; $verMinor = 0; $verPatch = 0 }
elseif ($Minor) { $verMinor++; $verPatch = 0 }
elseif ($Patch) { $verPatch++ }
$verBuild++

$newVersion = "version: $verMajor.$verMinor.$verPatch+$verBuild"
$updated = [regex]::Replace($content, '(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$', $newVersion)
[System.IO.File]::WriteAllText($pubspec, $updated, $utf8NoBom)

Write-Host "Bumped -> $verMajor.$verMinor.$verPatch+$verBuild" -ForegroundColor Green
