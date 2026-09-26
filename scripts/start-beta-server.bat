@echo off
REM Porneste beta-server.js (port 5960) si il reporneste automat daca moare.
REM Oglindeste start-static-server.bat, cu aceleasi motive - vezi comentariile
REM de acolo pentru de ce /WAIT si de ce /ABOVENORMAL.
REM Lansat de start-beta-server-hidden.vbs. Loguri in scripts/beta-server.log.
REM Pentru a opri complet: opreste task-ul "ShelfShare Beta Server".

cd /d "%~dp0.."

set LOGFILE=%~dp0beta-server.log

REM API-ul din care beta-seo.js ia cartile pentru HTML-ul pre-randat NU se mai
REM seteaza aici. beta-seo.js il citeste din web/dist/build-info.json, scris de
REM build (vite.config.ts), deci e mereu ACELASI backend ca bundle-ul livrat.
REM Variabila separata BETA_API_URL a divergat de doua ori de bundle (ultima
REM data: HTML-ul lista carti din productie, aplicatia le cauta in baza de test).
REM BETA_API_URL mai conteaza doar pentru un build vechi, fara build-info.json.
REM
REM La mutarea pe shelfshare.ro (vezi docs/mutare-react-pe-shelfshare.md) se
REM au fost decomentate cele doua linii de mai jos (2026-09-26):
set BETA_SITE_URL=https://shelfshare.ro
set REDIRECT_HOSTS=beta.shelfshare.ro,www.shelfshare.ro

:loop
echo [%date% %time%] Pornire beta-server.js >> "%LOGFILE%"
REM /ABOVENORMAL: aceeasi masina la 100%% CPU pe 4 nuclee. La prioritate normala
REM node-ul e dat la o parte de scheduler secunde intregi, iar Cloudflare renunta
REM inainte sa apuce originea sa raspunda - iese 502 cu procesul perfect sanatos.
REM /B = fara fereastra noua, /WAIT = .bat-ul asteapta iesirea node-ului, ca
REM bucla de mai jos sa se declanseze cand moare. Fara /WAIT, start revine
REM imediat si bucla ar porni instante peste instante.
start "" /B /WAIT /ABOVENORMAL node scripts/beta-server.js >> "%LOGFILE%" 2>&1
echo [%date% %time%] beta-server.js s-a oprit cu exit code %errorlevel% - repornesc in 3s >> "%LOGFILE%"
timeout /t 3 /nobreak > nul
goto loop
