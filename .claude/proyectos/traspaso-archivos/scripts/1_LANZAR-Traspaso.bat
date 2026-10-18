@echo off
setlocal
title Traspaso de archivos (v3)
rem Abre el menu maestro. Usa PowerShell 7 (pwsh) si esta instalado; si no, Windows PowerShell 5.1.
where pwsh >nul 2>nul
if %errorlevel%==0 (set "PSX=pwsh") else (set "PSX=powershell")
%PSX% -NoProfile -ExecutionPolicy Bypass -File "%~dp0Menu-Traspaso.ps1"
echo.
pause
endlocal
