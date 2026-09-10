' Ruleaza o comanda COMPLET fara fereastra si asteapta terminarea ei.
'
' De ce exista: un task din Scheduler care porneste direct powershell.exe sau
' cmd.exe deschide o consola vizibila la fiecare rulare, chiar cu
' -WindowStyle Hidden si cu <Hidden>true</Hidden> in XML. Fereastra e creata de
' Windows INAINTE ca procesul sa apuce sa se ascunda singur, iar la fiecare 2
' minute sare in fata si fura focusul din ce scrii. Singurul mod sigur de a o
' suprima e sa nu fie creata deloc: WshShell.Run cu 0 porneste procesul fara
' consola.
'
' Al doilea argument True = asteapta, ca Task Scheduler sa vada durata reala si
' codul de iesire al comenzii, nu al wrapper-ului.
'
' Folosire (din XML-ul task-ului):
'   Command:   wscript.exe
'   Arguments: "...\run-hidden.vbs" "powershell.exe -NoProfile -File ""...\x.ps1"""
Set WshShell = CreateObject("WScript.Shell")
If WScript.Arguments.Count = 0 Then
  WScript.Echo "run-hidden.vbs: lipseste comanda de rulat"
  WScript.Quit 2
End If
cmd = WScript.Arguments(0)
For i = 1 To WScript.Arguments.Count - 1
  cmd = cmd & " " & WScript.Arguments(i)
Next
WScript.Quit WshShell.Run(cmd, 0, True)
