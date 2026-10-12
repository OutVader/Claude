@echo off
title Progreso de la copia (todas las carpetas)
color 0B
echo Mostrando el progreso de TODAS las carpetas en copia (se actualiza solo).
echo Cierra la ventana para salir.
echo.
powershell -ExecutionPolicy Bypass -Command "while($true){ Clear-Host; Write-Host 'PROGRESO DE LA COPIA (se actualiza cada minuto):'; Write-Host ''; $f = Get-ChildItem 'D:\GN\BK2\*\_index\*.PROGRESO.txt' -ErrorAction SilentlyContinue; if(-not $f){ Write-Host '  (Aun no hay ninguna copia en marcha)' } else { foreach($x in $f){ Get-Content $x.FullName } }; Start-Sleep 60 }"
pause
