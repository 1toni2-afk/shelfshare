@echo off
REM Cautarea de noapte pentru cartile cerute de useri („nu gasesc cartea").
REM
REM Se programeaza in Task Scheduler la ~03:30, DUPA cron-ul din backend
REM (02:30, vezi BookRequestsService.resolvePendingRequests): acela epuizeaza
REM intai sursele ieftine - catalogul propriu, Google Books, Open Library - iar
REM scriptul asta ia doar ce a ramas, ca sa nu deschidem pagini de librarie
REM pentru carti pe care le-am fi gasit oricum gratis.
REM
REM Cere BOOK_REQUEST_WORKER_TOKEN in mediu (aceeasi valoare ca in .env-ul
REM backend-ului). Task-ul din Scheduler trebuie sa ruleze cu un cont care are
REM variabila setata - o pui cu:  setx BOOK_REQUEST_WORKER_TOKEN <valoare>

cd /d "%~dp0"
set PYTHONIOENCODING=utf-8

if "%SHELFSHARE_API_URL%"=="" set SHELFSHARE_API_URL=http://localhost:3000

echo [%DATE% %TIME%] pornesc cautarea cererilor >> nightly.log
python -u nightly_book_requests.py --limit 30 --delay 2 >> nightly.log 2>&1
echo [%DATE% %TIME%] gata (cod %ERRORLEVEL%) >> nightly.log
