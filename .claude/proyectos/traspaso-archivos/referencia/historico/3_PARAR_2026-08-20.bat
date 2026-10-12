@echo off
title PARAR la copia de forma segura
color 0E
echo ================================================================
echo    PARAR LA COPIA DE FORMA SEGURA
echo ================================================================
echo.
echo Enviando senal de PARADA...
if exist "C:\Users\D746288\Desktop\0.Escritorio\BK2\_tools\" echo stop> "C:\Users\D746288\Desktop\0.Escritorio\BK2\_tools\STOP.flag"
if exist "D:\GN\BK2\_tools\" echo stop> "D:\GN\BK2\_tools\STOP.flag"
echo.
echo  Senal enviada. La copia se detendra en cuanto termine el ARCHIVO
echo  actual (unos segundos), dejando movil y disco en estado coherente.
echo.
echo  ESPERA a ver el mensaje:  "YA PUEDES DESCONECTAR EL MOVIL"
echo  (en la ventana de la copia, o "PARADA_OK" en 2_VER-Progreso).
echo  NO desconectes el movil hasta ver ese mensaje.
echo.
pause
