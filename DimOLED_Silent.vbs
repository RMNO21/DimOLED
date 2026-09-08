Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\Users\User\AppData\Local\DimOLED\DimOLED.ps1"" -Silent", 0, False
