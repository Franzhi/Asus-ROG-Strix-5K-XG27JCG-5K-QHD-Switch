Set objShell = CreateObject("WScript.Shell")

args = ""
For i = 0 to WScript.Arguments.Count - 1
    args = args & """" & WScript.Arguments(i) & """ "
Next

' Використовуємо абсолютний шлях до PowerShell
psCommand = """C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"" -NoProfile -ExecutionPolicy Bypass -File ""C:\Program Files (x86)\Steam\Steam_Launcher.ps1"" " & args

' 0 гарантує запуск у режимі повного стелсу
objShell.Run psCommand, 0, False