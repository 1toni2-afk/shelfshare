@echo off
REM Porneste beta-server.js (port 5960) si il reporneste automat daca moare.
REM Oglindeste start-static-server.bat, cu aceleasi motive - vezi comentariile
REM de acolo pentru de ce /WAIT si de ce /ABOVENORMAL.
REM Lansat de start-beta-server-hidden.vbs. Loguri in scripts/beta-server.log.
REM Pentru a opri complet: opreste task-ul "ShelfShare Beta Server".

cd /d "%~dp0.."

set LOGFILE=%~dp0beta-server.log

REM API-ul din care beta-seo.js ia cartile pentru HTML-ul pre-randat.
REM
REM TREBUIE sa fie acelasi backend spre care pointeaza bundle-ul livrat (vezi
REM scripts/deploy-beta.ps1, care construieste contra productiei din 2026-09-22).
REM Fara variabila asta beta-seo.js cade pe implicitul lui, localhost:3999,
REM adica zona de TEST: HTML-ul servit listeaza carti care nu exista in
REM productie, deci fiecare link din primul cadru duce la o pagina inexistenta
REM imediat ce porneste aplicatia - si exact alea ajung in Google.
REM
REM Direct pe portul local al productiei, nu prin https://api.shelfshare.ro:
REM acolo cererea ar iesi prin tunelul Cloudflare si s-ar intoarce pe aceeasi
REM masina, adaugand o traversare de retea la fiecare pagina.
set BETA_API_URL=http://localhost:3000

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
