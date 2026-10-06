@echo off
REM Porneste dev serverul web (Vite, port 5173) si il reporneste daca moare.
REM Oglindeste start-beta-server.bat - vezi comentariile de acolo pentru /WAIT.
REM Lansat de start-web-dev-hidden.vbs. Loguri in scripts/web-dev.log.
REM Pentru a opri complet: opreste task-ul "ShelfShare Web Dev".
REM
REM De ce ruleaza permanent: e zona de test vazuta de pe telefon prin Tailscale
REM (https://sv-toni.tail6e27d0.ts.net:8443, vezi web/.env.development.local).
REM Pornit dintr-un terminal, murea odata cu fereastra.
REM
REM Prioritate normala, nu /ABOVENORMAL ca serverele de productie: masina sta
REM la 100%% CPU, iar dev serverul nu are voie sa le ia timp shelfshare.ro.

cd /d "%~dp0..\web"

set LOGFILE=%~dp0web-dev.log

:loop
echo [%date% %time%] Pornire vite (npm run dev) >> "%LOGFILE%"
REM `call`, nu direct `npm`: npm e un .cmd, iar fara call .bat-ul s-ar opri
REM dupa prima rulare in loc sa se intoarca in bucla.
call npm run dev >> "%LOGFILE%" 2>&1
echo [%date% %time%] vite s-a oprit cu exit code %errorlevel% - repornesc in 10s >> "%LOGFILE%"
REM 10s, nu 3s: cel mai probabil motiv de iesire e portul 5173 ocupat (strictPort)
REM de un `npm run dev` pornit de mana - n-are rost sa umplem logul.
timeout /t 10 /nobreak > nul
goto loop
