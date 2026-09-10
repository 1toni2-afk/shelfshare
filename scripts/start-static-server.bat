@echo off
REM Porneste static-server.js si il repornește automat dacă moare (crash, exit).
REM Lansat de start-static-server-hidden.vbs, care il ruleaza fara fereastra si
REM asteapta - vezi comentariile de acolo. Loguri in scripts/static-server.log.
REM Pentru a opri complet: opreste task-ul "ShelfShare Static Server".

cd /d "%~dp0.."

set LOGFILE=%~dp0static-server.log

:loop
echo [%date% %time%] Pornire static-server.js >> "%LOGFILE%"
REM /ABOVENORMAL: masina are 4 nuclee si sta la 100%% CPU (Docker/WSL2, Defender,
REM searchindexer, qbittorrent). La prioritate normala node-ul e dat la o parte de
REM scheduler secunde intregi: masurat pe /robots.txt, un string din memorie fara
REM I/O, median 9ms dar p90 3.6s si max 9.3s. Cloudflare renunta inainte sa apuce
REM originea sa raspunda si iese 502 "Host: Error", cu procesul perfect sanatos.
REM Nu rezolva saturarea - doar scoate serverul web din coada in care astepta
REM langa procesele de fundal.
REM
REM /B = fara fereastra noua, /WAIT = .bat-ul asteapta iesirea node-ului, ca
REM bucla de restart de mai jos sa se declanseze cand moare. Fara /WAIT, start
REM revine imediat si bucla ar porni instante peste instante.
start "" /B /WAIT /ABOVENORMAL node scripts/static-server.js >> "%LOGFILE%" 2>&1
echo [%date% %time%] static-server.js s-a oprit cu exit code %errorlevel% - repornesc in 3s >> "%LOGFILE%"
timeout /t 3 /nobreak > nul
goto loop
