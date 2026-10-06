' Lanseaza start-web-dev.bat fara nicio fereastra de consola vizibila -
' folosit de task-ul din Task Scheduler ("ShelfShare Web Dev").
'
' Identic cu start-beta-server-hidden.vbs - vezi comentariile de acolo, mai ales
' de ce al treilea argument e True (asteapta): altfel trigger-ul de 5 minute
' ar porni bucla peste bucla.
Set WshShell = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
WshShell.CurrentDirectory = scriptDir
WshShell.Run """" & scriptDir & "\start-web-dev.bat""", 0, True
