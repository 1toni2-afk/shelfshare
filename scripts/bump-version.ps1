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

$content = Get-Content $pubspec -Raw
if ($content -notmatch '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$') {
  throw 'Nu am putut parsa `version: X.Y.Z+BUILD` din pubspec.yaml'
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]
$build = [int]$Matches[4]

if ($Major)     { $major++; $minor = 0; $patch = 0 }
elseif ($Minor) { $minor++; $patch = 0 }
elseif ($Patch) { $patch++ }
$build++

$newVersion = "version: $major.$minor.$patch+$build"
$updated = [regex]::Replace($content, '(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$', $newVersion)
Set-Content -Path $pubspec -Value $updated -Encoding utf8 -NoNewline

Write-Host "Bumped -> $major.$minor.$patch+$build" -ForegroundColor Green
