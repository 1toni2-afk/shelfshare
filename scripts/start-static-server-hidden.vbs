' Lansează start-static-server.bat fără nicio fereastră de consolă vizibilă -
' folosit de task-ul din Task Scheduler ("ShelfShare Static Server").
'
' Lansăm .bat-ul, nu direct node.exe: .bat-ul are bucla care repornește
' serverul dacă moare (crash, exit). Pe 10.09.2026 procesul node a murit
' singur, nimic nu l-a ridicat la loc (vbs-ul de dinainte doar îl lansa), iar
' site-ul a stat jos cu 502 de la Cloudflare până am observat manual.
'
' Al doilea argument 0 = fereastră ascunsă (altfel bucla ar ține un terminal
' deschis pe ecran la fiecare logon).
'
' Al treilea argument True = AȘTEAPTĂ. Contraintuitiv, dar esențial: cât timp
' vbs-ul așteaptă, Task Scheduler consideră task-ul "în execuție", iar
' trigger-ul repetitiv de 5 minute e ignorat (setarea IgnoreNew). Cu False,
' vbs-ul s-ar termina imediat, task-ul ar apărea "gata", iar la fiecare 5
' minute s-ar porni încă o buclă peste cea vie - a doua n-ar putea lega
' portul 5959 și ar intra într-un ciclu infinit de EADDRINUSE la 3 secunde
' (exact ce s-a întâmplat în log pe 25.07.2026).
Set WshShell = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
WshShell.CurrentDirectory = scriptDir
WshShell.Run """" & scriptDir & "\start-static-server.bat""", 0, True
