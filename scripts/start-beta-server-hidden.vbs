' Lanseaza start-beta-server.bat fara nicio fereastra de consola vizibila -
' folosit de task-ul din Task Scheduler ("ShelfShare Beta Server").
'
' Lansam .bat-ul, nu direct node.exe: .bat-ul are bucla care reporneste
' serverul daca moare (crash, exit).
'
' Al doilea argument 0 = fereastra ascunsa.
'
' Al treilea argument True = ASTEAPTA. Contraintuitiv, dar esential: cat timp
' vbs-ul asteapta, Task Scheduler considera task-ul "in executie", iar
' trigger-ul repetitiv de 5 minute e ignorat (IgnoreNew). Cu False, vbs-ul s-ar
' termina imediat, task-ul ar aparea "gata", iar la fiecare 5 minute s-ar porni
' inca o bucla peste cea vie - a doua n-ar putea lega portul 5960 si ar intra
' intr-un ciclu infinit de EADDRINUSE la 3 secunde.
Set WshShell = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
WshShell.CurrentDirectory = scriptDir
WshShell.Run """" & scriptDir & "\start-beta-server.bat""", 0, True
