@echo off
REM Reia colectarea pentru Onboarding_Books_DB dupa blocajul din 2026-09-04.
REM
REM Ruleaza la delay-ul de 60s cerut de robots.txt, nu la 2s cum a rulat prima
REM data - exact ritmul acela ne-a adus blocajul. Aici ne permitem: au ramas ~32
REM de titluri si ~134 de coperti, adica ~3h in total, nu peste o luna.
REM
REM Daca site-ul inca ne blocheaza, scrape se opreste singur dupa prima pagina
REM goala (vezi clasa Blocked) si nu mai insista.

cd /d "%~dp0"
set PYTHONIOENCODING=utf-8

echo [%DATE% %TIME%] pornesc scrape onboarding >> data\onboarding_run.log
python -u build_onboarding_db.py --delay 60 scrape >> data\onboarding_run.log 2>&1
if errorlevel 1 (
    echo [%DATE% %TIME%] scrape s-a oprit cu eroare - ma opresc aici >> data\onboarding_run.log
    exit /b 1
)

echo [%DATE% %TIME%] descarc copertile >> data\onboarding_run.log
python -u build_onboarding_db.py --delay 60 covers >> data\onboarding_run.log 2>&1

echo [%DATE% %TIME%] scriu Onboarding_Books_DB.json >> data\onboarding_run.log
python -u build_onboarding_db.py export >> data\onboarding_run.log 2>&1

echo [%DATE% %TIME%] gata >> data\onboarding_run.log
