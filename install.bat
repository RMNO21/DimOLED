@echo off
setlocal
echo Installing DimOLED...

set "TARGET_DIR=%LOCALAPPDATA%\DimOLED"
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

copy /y "%~dp0DimOLED.ps1" "%TARGET_DIR%\" >nul
copy /y "%~dp0DimOLED_Silent.vbs" "%TARGET_DIR%\" >nul
if not exist "%TARGET_DIR%\config.ini" (
    copy /y "%~dp0config.example.ini" "%TARGET_DIR%\config.ini" >nul
)

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "DimOLED" /t REG_SZ /d "wscript.exe \"%TARGET_DIR%\DimOLED_Silent.vbs\"" /f >nul

echo Starting DimOLED silent background service...
wscript.exe "%TARGET_DIR%\DimOLED_Silent.vbs"

echo Installation complete! DimOLED is now running in the background.
pause
