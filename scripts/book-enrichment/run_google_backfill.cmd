@echo off
REM Backfill descrieri din Google Books pentru cartile atinse de useri (Faza 0).
REM
REM Pornit de sarcina programata "ShelfShareGoogleBackfill". Rulare unica: cota
REM anonima Google Books (fara GOOGLE_BOOKS_API_KEY) e zilnica, iar cea de pe
REM 2026-08-27 se epuizase. Scriptul salveaza incremental si reia din fisierul
REM de iesire, deci daca cota se termina din nou o poti relansa fara pierderi.

REM Cale absoluta la interpretor, nu "python": sub contul SYSTEM (varianta
REM "ruleaza si daca nu sunt logat") PATH-ul nu contine venv-ul, iar bs4 si
REM playwright sunt instalate doar in el.
set "PY=C:\Users\wwwto\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe"

cd /d "%~dp0"
set PYTHONUTF8=1

if not exist "%PY%" (
  echo EROARE: interpretorul "%PY%" nu exista > "nightly_runs\google_backfill.log"
  exit /b 1
)

"%PY%" enrich_google.py --input isbns_faza0.txt --output enriched_google.json > "nightly_runs\google_backfill.log" 2>&1
echo Exit code: %ERRORLEVEL% >> "nightly_runs\google_backfill.log"
