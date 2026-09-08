@echo off
REM Cautarea de noapte pentru cartile cerute de useri („nu gasesc cartea").
REM
REM Programat in Task Scheduler ca "ShelfShareBookRequests", zilnic la 03:30 -
REM DUPA cron-ul din backend (02:30, vezi
REM BookRequestsService.resolvePendingRequests): acela epuizeaza intai sursele
REM ieftine (catalogul propriu, Google Books, Open Library), iar scriptul asta
REM ia doar ce a ramas, ca sa nu deschidem pagini de librarie pentru carti pe
REM care le-am fi gasit oricum gratis.
REM
REM Tokenul NU se tine aici si nici in mediul userului: se citeste din .env-ul
REM de productie, acelasi fisier din care il ia si backend-ul. Asa exista o
REM singura copie a secretului, iar o rotire a lui nu cere sa ne amintim de al
REM doilea loc.

setlocal
cd /d "%~dp0"

REM Calea completa catre python, nu doar "python": un task programat nu are
REM neaparat acelasi PATH ca o consola deschisa de user.
set "PYTHON=C:\Users\wwwto\AppData\Local\Programs\Python\Python314\python.exe"
if not exist "%PYTHON%" set "PYTHON=python"

set PYTHONIOENCODING=utf-8
if "%SHELFSHARE_API_URL%"=="" set "SHELFSHARE_API_URL=http://localhost:3000"

REM `findstr` intai, nu o bucla peste tot fisierul: .env are si linii cu `>`
REM si `&` (comentarii, JSON-ul de Firebase pe un rand), iar cmd le expandeaza
REM ca operatori inainte sa parseze comanda - adica incearca sa le execute.
if "%BOOK_REQUEST_WORKER_TOKEN%"=="" (
    for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b /c:"BOOK_REQUEST_WORKER_TOKEN=" "%~dp0..\..\.env"`) do set "BOOK_REQUEST_WORKER_TOKEN=%%B"
)

if "%BOOK_REQUEST_WORKER_TOKEN%"=="" (
    echo [%DATE% %TIME%] BOOK_REQUEST_WORKER_TOKEN lipseste din .env - ma opresc >> nightly.log
    exit /b 1
)

echo [%DATE% %TIME%] pornesc cautarea cererilor >> nightly.log
"%PYTHON%" -u nightly_book_requests.py --limit 30 --delay 2 >> nightly.log 2>&1
echo [%DATE% %TIME%] gata (cod %ERRORLEVEL%) >> nightly.log
endlocal
