@echo off
REM Porneste static-server.js si il repornește automat dacă moare (crash, exit).
REM Pune un shortcut la fisierul asta in Startup (Win+R -> shell:startup) ca sa
REM porneasca automat la login. Loguri in scripts/static-server.log.
REM Pentru a opri complet: inchide fereastra ASTA (sau taskkill dupa PID-ul cmd.exe).

cd /d "%~dp0.."

set LOGFILE=%~dp0static-server.log

:loop
echo [%date% %time%] Pornire static-server.js >> "%LOGFILE%"
node scripts/static-server.js >> "%LOGFILE%" 2>&1
echo [%date% %time%] static-server.js s-a oprit cu exit code %errorlevel% - repornesc in 3s >> "%LOGFILE%"
timeout /t 3 /nobreak > nul
goto loop
