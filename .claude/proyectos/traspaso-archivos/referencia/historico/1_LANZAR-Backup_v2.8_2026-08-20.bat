@echo off
setlocal
title Copia de seguridad del movil  (v2.8)
color 0A
echo ================================================================
echo    COPIA DE SEGURIDAD DE CARPETAS DEL MOVIL   (v2.8)
echo ================================================================
echo.
echo  ANTES DE EMPEZAR, asegurate de:
echo    1) El disco donde vas a guardar esta conectado (ej. D:).
echo    2) El movil esta conectado con el cable y DESBLOQUEADO.
echo    3) En el movil elige "Transferir archivos".
echo    4) Si sale "Permitir depuracion USB", pulsa Permitir siempre.
echo.
echo  Copia de la mas antigua a la mas nueva y la borra del movil
echo  DESPUES de comprobar que esta a salvo en el disco.
echo  Puedes CERRAR la ventana en cualquier momento; continua luego.
echo.

REM --- Mantener copia del programa en el disco externo D: si esta conectado ---
if exist "D:\GN\BK2\_tools\" if /I not "%~dp0"=="D:\GN\BK2\_tools\" (
  copy /Y "%~dp0BackupMovil-v2.ps1" "D:\GN\BK2\_tools\" >nul 2>&1
  copy /Y "%~dp0LEEME.txt"          "D:\GN\BK2\_tools\" >nul 2>&1
  copy /Y "%~dp0*.bat"              "D:\GN\BK2\_tools\" >nul 2>&1
  echo  (Copia del programa actualizada tambien en D:\GN\BK2\_tools)
  echo.
)

:src
set "SRC="
set "DEFDEST="
echo ----------------------------------------------------------------
echo  QUE CARPETA DEL MOVIL quieres copiar?
echo.
echo    [1] Capturas (Screenshots)      [6] Collage
echo    [2] Camara (DCIM/Camera)        [7] Snapseed
echo    [3] Twitter                     [8] Polish
echo    [4] Telegram (fotos)            [9] WhatsApp (fotos)
echo    [5] Instagram                   [0] Otra ruta (a mano)
echo.
set /p "SO=  Escribe el numero: "
if "%SO%"=="1" set "SRC=/sdcard/Pictures/Screenshots"
if "%SO%"=="1" set "DEFDEST=D:\GN\BK2\ScreenShots"
if "%SO%"=="2" set "SRC=/sdcard/DCIM/Camera"
if "%SO%"=="2" set "DEFDEST=D:\GN\BK2\Camera"
if "%SO%"=="3" set "SRC=/sdcard/Pictures/Twitter"
if "%SO%"=="3" set "DEFDEST=D:\GN\BK2\Twitter"
if "%SO%"=="4" set "SRC=/sdcard/Pictures/Telegram"
if "%SO%"=="4" set "DEFDEST=D:\GN\BK2\Telegram"
if "%SO%"=="5" set "SRC=/sdcard/Pictures/Instagram"
if "%SO%"=="5" set "DEFDEST=D:\GN\BK2\Instagram"
if "%SO%"=="6" set "SRC=/sdcard/DCIM/Collage"
if "%SO%"=="6" set "DEFDEST=D:\GN\BK2\Collage"
if "%SO%"=="7" set "SRC=/sdcard/Pictures/Snapseed"
if "%SO%"=="7" set "DEFDEST=D:\GN\BK2\Snapseed"
if "%SO%"=="8" set "SRC=/sdcard/Pictures/Polish"
if "%SO%"=="8" set "DEFDEST=D:\GN\BK2\Polish"
if "%SO%"=="9" set "SRC=/sdcard/Pictures/WhatsApp"
if "%SO%"=="9" set "DEFDEST=D:\GN\BK2\WhatsApp"
if "%SO%"=="0" goto srcman
if not defined SRC ( echo. & echo  Opcion no valida. Prueba otra vez. & echo. & goto src )
echo  --^> Carpeta del movil: %SRC%
echo.
goto dest

:srcman
set "SRC="
set /p "SRC=  Escribe la ruta del movil (ej. /sdcard/DCIM/Camera): "
if not defined SRC ( echo. & echo  No has escrito nada. Intentalo de nuevo. & echo. & goto srcman )
set "SRCW=%SRC:/=\%"
for %%A in ("%SRCW%") do set "LEAF=%%~nxA"
if not defined LEAF set "LEAF=Backup"
set "DEFDEST=D:\GN\BK2\%LEAF%"
echo  --^> Carpeta del movil: %SRC%
echo.
goto dest

:dest
set "DEST="
set /p "DEST=  Carpeta donde GUARDAR [ENTER = %DEFDEST%]: "
if not defined DEST set "DEST=%DEFDEST%"
for %%D in ("%DEST%") do set "DRV=%%~dD"
if not exist "%DRV%\" (
  echo.
  echo  La unidad %DRV% NO esta disponible. Conecta el disco o escribe otra ruta.
  echo.
  goto dest
)
echo  --^> Se guardara en:  %DEST%
echo.

:menu
set "EXTRA="
set "OPC="
echo ----------------------------------------------------------------
echo  QUE QUIERES HACER ESTA VEZ?
echo.
echo    [1]  Mover un NUMERO de ficheros  (100 / 500 / 1000 / 5000...)
echo         (se hace en bloques de maximo 500 a la vez)
echo.
echo    [2]  Avanzar HASTA UN MES incluido (ej. 2024-12, 2025-01...)
echo.
set /p "OPC=  Escribe 1 o 2 y pulsa ENTER: "
if "%OPC%"=="1" goto num
if "%OPC%"=="2" goto mes
echo.
echo  Opcion no valida. Prueba otra vez.
echo.
goto menu

:num
echo.
set "NUM="
echo  CUANTOS ficheros mover en total esta vez?
echo     [1] 100     [2] 500     [3] 1000     [4] 5000     [5] Otra cantidad
set /p "NS=  Escribe el numero de opcion: "
if "%NS%"=="1" set "NUM=100"
if "%NS%"=="2" set "NUM=500"
if "%NS%"=="3" set "NUM=1000"
if "%NS%"=="4" set "NUM=5000"
if "%NS%"=="5" goto nummanual
if not defined NUM ( echo. & echo  Opcion no valida. Prueba otra vez. & goto num )
goto numok
:nummanual
set "NUM="
set /p "NUM=  Escribe la cantidad (ej. 250): "
if not defined NUM ( echo  No has escrito nada. & goto nummanual )
:numok
set "EXTRA=-MaxFiles %NUM%"
echo.
echo  --^> Se moveran hasta %NUM% ficheros (en bloques de 500).
goto run

:mes
echo.
set "MES="
set /p "MES=  Hasta que mes incluido (formato AAAA-MM, ej. 2024-12): "
if not defined MES ( echo  No has escrito nada. Intentalo de nuevo.& echo.& goto mes )
set "EXTRA=-UntilYM %MES%"
echo.
echo  --^> Se avanzara hasta el mes %MES% incluido.
goto modo

:modo
set "MODOFLAG="
set "MODOTXT="
set "MO="
echo.
echo ----------------------------------------------------------------
echo    [1]  MOVER (copia y BORRA del movil al terminar - libera espacio)
echo    [2]  SOLO COPIAR (copia pero NO borra nada del movil)
echo    [3]  LIBERAR del movil lo YA copiado (borra del movil lo que ya
echo         esta a salvo en disco; no copia nada nuevo)
echo.
set /p "MO=  Escribe 1, 2 o 3 y pulsa ENTER: "
if "%MO%"=="1" set "MODOFLAG=" & set "MODOTXT=MOVER (borrara del movil)"
if "%MO%"=="2" set "MODOFLAG=-CopyOnly" & set "MODOTXT=SOLO COPIAR (no borra nada)"
if "%MO%"=="3" set "MODOFLAG=-FreeCopied" & set "MODOTXT=LIBERAR ya copiado (borra del movil lo que esta en disco)"
if not defined MODOTXT ( echo. & echo  Opcion no valida. Prueba otra vez. & goto modo )
goto run

:run
echo.
echo  RESUMEN:
echo    Origen : %SRC%
echo    Destino: %DEST%
echo    Modo   : %MODOTXT%
echo.
echo  Pulsa una tecla para EMPEZAR (o cierra la ventana para cancelar)...
pause >nul
echo.
echo  Trabajando... (deja esta ventana abierta)
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0BackupMovil-v2.ps1" -NonInteractive -PerCycle 500 -SourceFolder "%SRC%" -DestFolder "%DEST%" %EXTRA% %MODOFLAG%
echo.
echo ================================================================
echo    TERMINADO. Ya puedes cerrar esta ventana.
echo ================================================================
pause
endlocal
