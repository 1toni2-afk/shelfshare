' Lansează static-server.js fără nicio fereastră de consolă vizibilă - folosit
' de task-ul din Task Scheduler ("ShelfShare Static Server") ca serverul să
' rămână pornit după logon, fără terminal deschis (0 = fereastră ascunsă,
' False = nu așteaptă procesul, ca task-ul să se termine imediat și serverul
' să rămână doar el în urmă).
Set WshShell = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
WshShell.CurrentDirectory = scriptDir
WshShell.Run """C:\Program Files\nodejs\node.exe"" """ & scriptDir & "\static-server.js""", 0, False
