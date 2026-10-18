# Bitácora: Traspaso-Archivos

## 2026-10-12: Fase 1 (EXPLORAR)
- Qué se hizo:
  - Se leyó la memoria `project_screenshots_drain.md`, que pegó Iñaki.
  - Se listó `TRACASA\SCRIPTS`: no hay scripts ADB.
  - Se revisaron `BackupMovil-v2.ps1` (versión interna 3.0) y `1_LANZAR-Backup.bat` v2.8.
  - Se creó el andamiaje del proyecto y se archivaron las referencias en `referencia\historico\`:
    - `01-Vaciar-Screenshots-v1_2026-10-12.ps1`
    - `BackupMovil-v2_2026-08-20.ps1`
    - `1_LANZAR-Backup_v2.8_2026-08-20.bat`
  - Se instaló pwsh 7.4.6 en el contenedor de la nube para los tests.
- Resultado:
  - Destino real: `D:\GN\BK2\ScreenShots\<Año>\<Año-Mes>`.
  - Estado: 2023 y 2024 hasta 2024-06 terminados; 2024-07 → 2024-12 en curso al 20-08.
  - Se detectaron 3 fallos en BackupMovil-v2 (ver CONTEXT.md).
- Decisiones:
  - MTP fuera.
  - Nombre v3.
  - Compatibilidad con BK2 (`<Año>\<Año-Mes>` y `_index`).
  - Sincronización por Git (OutVader/Obsidian, rama `traspaso-archivos`) más una copia en OutVader/Claude.
- Pendiente: OK al diseño (fase 2) y subir el resto de `BK2\_tools` para archivarlo.

## 2026-10-12: Fase 2 (DISEÑO) y archivo de BK2\_tools
- Qué se hizo:
  - Se revisó el ZIP `bk2-tools.zip` (13 archivos) y se archivó **byte a byte** en `referencia\historico\`
    con la fecha real de cada archivo, más un README con el índice.
  - Se presentó el diseño: parámetros, flujo y estados del CSV.
  - Se creó `INDICE-MAESTRO.html` (índice interactivo de proyectos, rutas, repos y comandos).
- Resultado:
  - Move/Drain-Screenshots (05-08) confirman que BK2 clasificó **siempre por fecha de modificación**,
    con el destino inicial en `C:\...\BK2\ScreenShots`.
  - La v1 coincide con la de la rama `claude/gallant-lamport-xnchum` (proyecto `screenshots-oppo`).
- Decisiones:
  - `AnioMes` por defecto, con formato `AAAA\AAAA-MM`.
  - Fecha tomada del nombre, con la de modificación como respaldo; `-FechaPor Modificacion` disponible.
- Pendiente: OK para la fase 3.

## 2026-10-18: Fase 3 (IMPLEMENTACIÓN) y 4 (VERIFICACIÓN en la nube), con gauntlet loop
- Qué se hizo:
  - `scripts\Traspasar-Archivos.ps1` (motor v3), `scripts\Menu-Traspaso.ps1` (menú maestro) y `scripts\1_LANZAR-Traspaso.bat`.
  - `tests\adb-falso.ps1` (móvil simulado), `tests\Probar-Traspaso.ps1` (33 casos) y `tests\PSScriptAnalyzerSettings.psd1`.
  - `INSTRUCCIONES.md`.
- Revisión (gauntlet, Crítico ciego en un subagente nuevo por ronda; el hash del código se comprobó igual tras cada revisión):
  - Ronda 1 RECHAZADO:
    - B1: al Mover, las copias nuevas solo se verificaban por tamaño.
    - B2: un alias físico (unidad mapeada, subst, junction) podía tomar el original como "copia" y borrar la única que había.
    - B3: una unidad inexistente acababa con exit 0.
    - Corrección: SHA256 siempre al Mover, rutas reales e identidad física (Add-Type en Windows), try/catch → código 2.
  - Ronda 2 RECHAZADO:
    - B4: el candado se tomaba después del plan.
    - B5: las lecturas incompletas acababan con exit 0.
    - B6: un corte dejaba un archivo truncado con el nombre final.
    - B7: el test del menú podía tocar la configuración real.
    - Corrección: candado antes de leer el destino, avisos de lectura → exit 1, copia a `.traspaso_parcial` y paso al nombre final sin sobrescribir, `-RutaConfig`.
  - Cierre RECHAZADO:
    - B8: las tablas de hashes no distinguían mayúsculas (A.jpg/a.jpg).
    - Corrección: StringComparer.Ordinal y el test T32 (reproducía el fallo antes de corregirlo). **B8 corregido sin una nueva revisión del Crítico** (tras el cierre no hay más rondas).
  - Mejoras opcionales aplicadas:
    - cancelar entre bloques → código 3;
    - los tests sin poder crear enlaces cuentan como OMITIDO (exit 3), no como verdes;
    - destino con la raíz ilegible → código 2;
    - un adb `.ps1` solo se acepta si se pasa con `-Adb`;
    - aviso de los archivos de OneDrive "solo en la nube".
- Resultado (pwsh 7.4.6, Linux):
  - 33/33 tests en verde, 0 omitidos.
  - ScriptAnalyzer 0 avisos con la configuración del proyecto.
  - 0 variables o parámetros sin usar y 0 errores de sintaxis.
  - Mutaciones: cada protección quitada hace fallar su test (T19 tamaño, T24 guarda física, T26 SHA256 al Mover, T29 restos parciales, T30 lecturas, T31 cancelar).
- No verificable aquí (verificar en destino): Windows PowerShell 5.1, Add-Type (GetFinalPathNameByHandleW / GetFileInformationByHandle), robocopy, adb real y el OPPO.
- Opcionales no aplicados:
  - candado para destinos anidados (D:\BK2 y D:\BK2\ScreenShots a la vez): está documentado "no lanzar dos a la vez";
  - aviso si el origen contiene una carpeta `_traspaso`;
  - adb antiguo sin shell_v2: no devuelve el código de salida del shell.
- Pendiente (Iñaki, en Windows):
  ```powershell
  cd '<AGENTES_WD>\.claude\Proyectos\Traspaso-Archivos\tests'
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Probar-Traspaso.ps1   # PS 5.1
  pwsh -NoProfile -File .\Probar-Traspaso.ps1                                 # PS 7 (si lo tienes)
  cd ..\scripts
  .\Traspasar-Archivos.ps1 -Origen "$env:USERPROFILE\Pictures" -Destino "$env:TEMP\prueba-traspaso" -Recursivo -WhatIf
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -SoloInventario
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -Destino 'D:\GN\BK2\ScreenShots' -SoloComparar
  .\Traspasar-Archivos.ps1 -Origen adb:/sdcard/Pictures/Screenshots -Destino 'D:\GN\BK2\ScreenShots' -Desde 2024-07 -Hasta 2024-12 -WhatIf
  ```
